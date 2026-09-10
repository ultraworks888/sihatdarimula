// CommonJS module: PocketBase executes each hook handler in an isolated JSVM,
// so handlers must import shared helpers explicitly instead of relying on
// declarations from the .pb.js registration file.

const pendingStatus = "pending";
const processingStatus = "processing";
const reviewStatus = "review_required";
const maxAttempts = 3;

function canonicalJson(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return "[" + value.map(canonicalJson).join(",") + "]";
  const keys = Object.keys(value).sort();
  return "{" + keys.map(function(key) {
    return JSON.stringify(key) + ":" + canonicalJson(value[key]);
  }).join(",") + "}";
}

function requestHash(input) {
  return $security.sha256(canonicalJson(input));
}

function validIdempotencyKey(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
}

function newIdempotencyKey() {
  const hex = $security.randomStringWithAlphabet(30, "0123456789abcdef");
  const variant = $security.randomStringWithAlphabet(1, "89ab");
  return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-4" + hex.slice(12, 15) +
    "-" + variant + hex.slice(15, 18) + "-" + hex.slice(18, 30);
}

function validateSegmentConfig(target, config) {
  if (target !== "all" && target !== "subscribed" && target !== "segment") {
    return "target must be all, subscribed, or segment";
  }
  if (target !== "segment") return "";
  if (!config || typeof config !== "object" || Array.isArray(config)) {
    return "segment_config is required for a segment target";
  }
  const type = String(config.type || "");
  if (["baby_age", "expectant", "course_enrolled", "not_enrolled", "language"].indexOf(type) === -1) {
    return "segment_config.type is invalid";
  }
  if (type === "baby_age") {
    if (typeof config.minMonths !== "number" || typeof config.maxMonths !== "number" ||
        config.minMonths < 0 || config.maxMonths <= config.minMonths || config.maxMonths > 120) {
      return "baby_age requires a valid minMonths and maxMonths range";
    }
  }
  if (type === "course_enrolled" && !String(config.courseId || "").trim()) {
    return "course_enrolled requires courseId";
  }
  if (type === "language" && ["en", "ms", "zh"].indexOf(String(config.lang || "")) === -1) {
    return "language requires en, ms, or zh";
  }
  return "";
}

function resolveSegmentUserIds(app, maintenance, segConfig) {
  const seen = {};
  const add = function(id) { if (id && !seen[id]) seen[id] = true; };

  try {
    const type = segConfig.type;
    if (type === "baby_age") {
      const now = new Date();
      const maxDob = new Date(now); maxDob.setUTCMonth(maxDob.getUTCMonth() - segConfig.minMonths);
      const minDob = new Date(now); minDob.setUTCMonth(minDob.getUTCMonth() - segConfig.maxMonths);
      const babyRows = app.findRecordsByFilter(
        "children",
        "is_born = true && date_of_birth >= {:a} && date_of_birth <= {:b}",
        "", 0, 0, { a: minDob.toISOString(), b: maxDob.toISOString() }
      );
      for (let bi = 0; bi < babyRows.length; bi++) add(babyRows[bi].getString("user"));
    } else if (type === "expectant") {
      const rows = app.findRecordsByFilter("children", "is_born = false", "", 0, 0, {});
      for (let i = 0; i < rows.length; i++) add(rows[i].getString("user"));
    } else if (type === "course_enrolled") {
      const rows = app.findRecordsByFilter(
        "enrollments", "course = {:cid}", "", 0, 0, { cid: String(segConfig.courseId) }
      );
      for (let i = 0; i < rows.length; i++) add(rows[i].getString("user"));
    } else if (type === "not_enrolled") {
      const enrolled = {};
      const enrollments = app.findRecordsByFilter("enrollments", "id != ''", "", 0, 0, {});
      for (let i = 0; i < enrollments.length; i++) enrolled[enrollments[i].getString("user")] = true;
      const users = app.findRecordsByFilter("users", "id != ''", "", 0, 0, {});
      for (let i = 0; i < users.length; i++) {
        const role = users[i].getString("role");
        if (role !== "admin" && role !== "superadmin" && !enrolled[users[i].id]) add(users[i].id);
      }
    } else if (type === "language") {
      const rows = app.findRecordsByFilter(
        "users", "language = {:lang}", "", 0, 0, { lang: String(segConfig.lang) }
      );
      for (let i = 0; i < rows.length; i++) add(rows[i].id);
    }
  } catch (err) {
    maintenance.rethrow(err);
    throw err;
  }
  return Object.keys(seen);
}

function claimBroadcast(app, maintenance, id, staleBefore) {
  let claimed = false;
  try {
    app.runInTransaction(function(txApp) {
      const record = txApp.findRecordById("push_broadcasts", id);
      const status = record.getString("status");
      const attempts = Number(record.get("dispatch_attempts") || 0);
      const started = record.getString("dispatch_started_at");
      const startedAt = started ? new Date(started.replace(" ", "T")).getTime() : 0;
      const next = record.getString("next_attempt_at");
      const nextAt = next ? new Date(next.replace(" ", "T")).getTime() : 0;
      const retryable = status === processingStatus &&
        (nextAt > 0 ? nextAt <= Date.now() :
          startedAt > 0 && startedAt <= new Date(staleBefore).getTime());
      if (status !== pendingStatus && !retryable) return;
      if (attempts >= maxAttempts) {
        record.set("status", reviewStatus);
        txApp.save(record);
        return;
      }
      if (!validIdempotencyKey(record.getString("idempotency_key"))) {
        record.set("idempotency_key", newIdempotencyKey());
      }
      record.set("status", processingStatus);
      record.set("dispatch_started_at", new Date().toISOString());
      record.set("next_attempt_at", "");
      record.set("dispatch_attempts", attempts + 1);
      txApp.save(record);
      claimed = true;
    });
  } catch (err) {
    maintenance.rethrow(err);
    throw err;
  }
  return claimed ? app.findRecordById("push_broadcasts", id) : null;
}

function deferBroadcast(app, maintenance, id, delaySeconds) {
  try {
    app.runInTransaction(function(txApp) {
      const record = txApp.findRecordById("push_broadcasts", id);
      if (record.getString("status") !== processingStatus) return;
      record.set("next_attempt_at", new Date(Date.now() + delaySeconds * 1000).toISOString());
      txApp.save(record);
    });
  } catch (err) {
    maintenance.rethrow(err);
    throw err;
  }
}

function retryDelaySeconds(response) {
  let retryAfter = "";
  const headers = response.headers || {};
  Object.keys(headers).some(function(key) {
    if (key.toLowerCase() !== "retry-after") return false;
    const value = headers[key];
    retryAfter = String(Array.isArray(value) ? value[0] : value || "");
    return true;
  });
  const seconds = Number(retryAfter);
  if (Number.isFinite(seconds) && seconds > 0) return Math.max(100, Math.ceil(seconds));
  const date = Date.parse(retryAfter);
  if (Number.isFinite(date) && date > Date.now()) {
    return Math.max(100, Math.ceil((date - Date.now()) / 1000));
  }
  return 100;
}

function finalizeBroadcast(app, maintenance, id, status, recipients, onesignalId) {
  try {
    app.runInTransaction(function(txApp) {
      const record = txApp.findRecordById("push_broadcasts", id);
      if (record.getString("status") !== processingStatus) {
        throw new Error("Broadcast is no longer claimed for dispatch");
      }
      record.set("status", status);
      record.set("recipient_count", recipients);
      if (onesignalId) record.set("onesignal_id", onesignalId);
      txApp.save(record);
    });
  } catch (err) {
    maintenance.rethrow(err);
    throw err;
  }
}

function dispatchBroadcast(app, maintenance, appId, apiKey, record) {
  const title = record.getString("title");
  const message = record.getString("message");
  const url = record.getString("url");
  const target = record.getString("target") || "all";
  const idempotencyKey = record.getString("idempotency_key");
  if (!validIdempotencyKey(idempotencyKey)) throw new Error("Broadcast idempotency key is invalid");

  let segConfig = null;
  const segStr = record.getString("segment_config");
  if (segStr) segConfig = JSON.parse(segStr);
  const segmentError = validateSegmentConfig(target, segConfig);
  if (segmentError) {
    finalizeBroadcast(app, maintenance, record.id, "failed", 0, "");
    return { ok: false, retryable: false, statusCode: 400, recipients: 0 };
  }

  let payload;
  if (target === "segment") {
    const userIds = resolveSegmentUserIds(app, maintenance, segConfig);
    if (userIds.length === 0) {
      finalizeBroadcast(app, maintenance, record.id, "sent", 0, "");
      app.logger().info("push_dispatch: segment matched 0 users, skipped OneSignal", "id", record.id);
      return { ok: true, recipients: 0, skipped: true, onesignal_id: "" };
    }
    payload = {
      app_id: appId,
      include_aliases: { external_id: userIds },
      target_channel: "push",
      headings: { en: title, ms: title, zh: title },
      contents: { en: message, ms: message, zh: message },
      url: url,
      idempotency_key: idempotencyKey,
    };
  } else {
    payload = {
      app_id: appId,
      included_segments: target === "subscribed" ? ["Subscribed Users"] : ["All"],
      headings: { en: title, ms: title, zh: title },
      contents: { en: message, ms: message, zh: message },
      url: url,
      idempotency_key: idempotencyKey,
    };
  }

  let res;
  try {
    res = maintenance.send({
      url: "https://onesignal.com/api/v1/notifications",
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Basic " + apiKey },
      body: JSON.stringify(payload),
      timeout: 30,
    });
  } catch (err) {
    maintenance.rethrow(err);
    app.logger().error("push_dispatch: provider result uncertain", "id", record.id);
    throw err;
  }

  const statusCode = Number(res.statusCode || 0);
  const recipients = (res.json && typeof res.json.recipients === "number") ? res.json.recipients : 0;
  const osId = (res.json && res.json.id) ? String(res.json.id) : "";
  if (statusCode === 429 || statusCode >= 500) {
    deferBroadcast(app, maintenance, record.id, retryDelaySeconds(res));
    app.logger().error("push_dispatch: retryable provider response", "id", record.id, "status", statusCode);
    return { ok: false, retryable: true, statusCode: statusCode, recipients: 0 };
  }

  const ok = statusCode >= 200 && statusCode < 400;
  finalizeBroadcast(app, maintenance, record.id, ok ? "sent" : "failed", recipients, osId);
  app.logger().info("push_dispatch: result", "ok", ok, "recipients", recipients, "osId", osId);
  return { ok: ok, retryable: false, statusCode: statusCode, recipients: recipients, onesignal_id: osId };
}

module.exports = {
  canonicalJson,
  claimBroadcast,
  deferBroadcast,
  dispatchBroadcast,
  newIdempotencyKey,
  requestHash,
  validIdempotencyKey,
  validateSegmentConfig,
};
