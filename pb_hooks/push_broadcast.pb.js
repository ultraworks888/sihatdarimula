// POST /api/admin/push-broadcast
// Body: { title, message, idempotency_key, url?, target?, segment_config?, scheduled_at? }
routerAdd("POST", "/api/admin/push-broadcast", function(e) {
  return require(__hooks + "/maintenance.js").http(e, function() {
    if (!e.auth) return e.json(401, { error: "Unauthorized" });
    var role = e.auth.getString("role");
    if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

    var info = e.requestInfo();
    var title = String(info.body.title || "").trim();
    var message = String(info.body.message || "").trim();
    var url = String(info.body.url || "").trim();
    var target = String(info.body.target || "all").trim();
    var scheduledAt = String(info.body.scheduled_at || "").trim();
    var idempotencyKey = String(info.body.idempotency_key || "").trim().toLowerCase();
    var segConfigRaw = info.body.segment_config;
    var maintenance = require(__hooks + "/maintenance.js");
    var pushBroadcast = require(__hooks + "/push_broadcast.js");

    if (!title || !message) return e.json(400, { error: "title and message are required" });
    if (!pushBroadcast.validIdempotencyKey(idempotencyKey)) {
      return e.json(400, { error: "idempotency_key must be an RFC UUID" });
    }
    var segmentError = pushBroadcast.validateSegmentConfig(target, segConfigRaw);
    if (segmentError) return e.json(400, { error: segmentError });

    var appURL = "";
    try { appURL = $app.settings().meta.appURL || ""; }
    catch (err) { maintenance.rethrow(err); throw err; }
    var notifUrl = url || (appURL + "/content");
    var segmentJson = segConfigRaw && typeof segConfigRaw === "object"
      ? pushBroadcast.canonicalJson(segConfigRaw) : "";
    var fingerprint = pushBroadcast.requestHash({
      title: title,
      message: message,
      url: notifUrl,
      target: target,
      segment_config: segmentJson,
      scheduled_at: scheduledAt,
    });

    var recordId = "";
    var duplicate = false;
    try {
      $app.runInTransaction(function(txApp) {
        var matches = txApp.findRecordsByFilter(
          "push_broadcasts", "idempotency_key = {:key}", "", 2, 0, { key: idempotencyKey }
        );
        if (matches.length > 0) {
          if (matches.length !== 1 || matches[0].getString("request_hash") !== fingerprint) {
            throw new Error("Idempotency key already belongs to a different request");
          }
          recordId = matches[0].id;
          duplicate = true;
          return;
        }
        var record = new Record(txApp.findCollectionByNameOrId("push_broadcasts"));
        record.set("title", title);
        record.set("message", message);
        record.set("sent_by", e.auth.id);
        record.set("target", target);
        record.set("url", notifUrl);
        record.set("status", "pending");
        record.set("idempotency_key", idempotencyKey);
        record.set("request_hash", fingerprint);
        if (segmentJson) record.set("segment_config", segmentJson);
        if (scheduledAt) record.set("scheduled_at", scheduledAt);
        txApp.save(record);
        recordId = record.id;
      });
    } catch (err) {
      maintenance.rethrow(err);
      if (String(err).indexOf("Idempotency key already belongs") !== -1) {
        return e.json(409, { error: "idempotency_key was already used for different broadcast content" });
      }
      throw err;
    }

    if (scheduledAt) {
      var scheduled = $app.findRecordById("push_broadcasts", recordId);
      return e.json(200, {
        ok: true,
        scheduled: true,
        id: recordId,
        status: scheduled.getString("status"),
        scheduled_at: scheduled.getString("scheduled_at"),
      });
    }

    var staleBefore = new Date(Date.now() - 100000).toISOString();
    var beforeClaim = $app.findRecordById("push_broadcasts", recordId);
    var beforeStatus = beforeClaim.getString("status");
    if (beforeStatus === "sent") {
      return e.json(200, { ok: true, id: recordId,
        recipients: Number(beforeClaim.get("recipient_count") || 0),
        onesignal_id: beforeClaim.getString("onesignal_id") });
    }
    if (beforeStatus === "failed" || beforeStatus === "review_required") {
      return e.json(409, { error: "Broadcast dispatch did not complete", id: recordId, status: beforeStatus });
    }
    var beforeStarted = beforeClaim.getString("dispatch_started_at");
    var beforeNext = beforeClaim.getString("next_attempt_at");
    if (beforeStatus === "processing" &&
        ((beforeNext && new Date(beforeNext.replace(" ", "T")).getTime() > Date.now()) ||
         (!beforeNext && beforeStarted &&
          new Date(beforeStarted.replace(" ", "T")).getTime() > new Date(staleBefore).getTime()))) {
      return e.json(202, { ok: true, id: recordId, status: beforeStatus });
    }

    var appId, apiKey;
    try {
      appId = $app.findFirstRecordByFilter(
        "lms_settings", "key = {:k}", { k: "onesignal_app_id" }
      ).getString("value");
      apiKey = $app.findFirstRecordByFilter(
        "lms_settings", "key = {:k}", { k: "onesignal_api_key" }
      ).getString("value");
    } catch (err) { maintenance.rethrow(err); throw err; }
    if (!appId || !apiKey) throw new Error("OneSignal credentials are not configured");

    var claimed = pushBroadcast.claimBroadcast($app, maintenance, recordId, staleBefore);
    if (!claimed) {
      var existing = $app.findRecordById("push_broadcasts", recordId);
      var existingStatus = existing.getString("status");
      if (existingStatus === "sent") {
        return e.json(200, { ok: true, id: recordId,
          recipients: Number(existing.get("recipient_count") || 0),
          onesignal_id: existing.getString("onesignal_id") });
      }
      if (existingStatus === "failed" || existingStatus === "review_required") {
        return e.json(409, { error: "Broadcast dispatch did not complete", id: recordId, status: existingStatus });
      }
      return e.json(202, { ok: true, id: recordId, status: existingStatus });
    }

    var result = pushBroadcast.dispatchBroadcast(e.app, maintenance, appId, apiKey, claimed);
    if (result.retryable) return e.json(202, { ok: true, id: recordId, status: "processing" });
    if (!result.ok && !result.skipped) {
      return e.json(502, { error: "OneSignal rejected the request", id: recordId, status: result.statusCode });
    }
    return e.json(200, { ok: true, id: recordId,
      recipients: result.recipients, onesignal_id: result.onesignal_id });
  });
});

// POST /api/admin/push-broadcast/cancel
// Body: { id }
routerAdd("POST", "/api/admin/push-broadcast/cancel", function(e) {
  return require(__hooks + "/maintenance.js").http(e, function() {
    if (!e.auth) return e.json(401, { error: "Unauthorized" });
    var role = e.auth.getString("role");
    if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

    var id = String(e.requestInfo().body.id || "").trim();
    if (!id) return e.json(400, { error: "id is required" });
    var maintenance = require(__hooks + "/maintenance.js");
    var cancelled = false;
    var found = false;
    try {
      $app.runInTransaction(function(txApp) {
        var matches = txApp.findRecordsByFilter(
          "push_broadcasts", "id = {:id}", "", 1, 0, { id: id }
        );
        if (matches.length !== 1) return;
        var record = matches[0];
        found = true;
        if (record.getString("status") !== "pending") return;
        record.set("status", "cancelled");
        txApp.save(record);
        cancelled = true;
      });
    } catch (err) { maintenance.rethrow(err); throw err; }
    if (!found) return e.json(404, { error: "Broadcast not found" });
    if (!cancelled) return e.json(409, { error: "Only pending broadcasts can be cancelled" });
    $app.logger().info("push_broadcast: cancelled", "id", id);
    return e.json(200, { ok: true });
  });
});

// Dispatch due pending work and retry uncertain attempts with the same
// provider idempotency key. A retry is not attempted until OneSignal's
// recommended 100-second uncertainty window has elapsed.
cronAdd("push_broadcast_scheduler", "*/5 * * * *", function() {
  return require(__hooks + "/maintenance.js").background(function() {
    var maintenance = require(__hooks + "/maintenance.js");
    var pushBroadcast = require(__hooks + "/push_broadcast.js");
    var now = new Date();
    var nowString = now.toISOString();
    var staleBefore = new Date(now.getTime() - 100000).toISOString();
    var candidates = $app.findRecordsByFilter(
      "push_broadcasts",
      "(status = 'pending' && scheduled_at != '' && scheduled_at <= {:now}) || " +
        "(status = 'processing' && " +
          "((next_attempt_at != '' && next_attempt_at <= {:now}) || " +
           "(next_attempt_at = '' && dispatch_started_at != '' && dispatch_started_at <= {:stale})))",
      "created", 100, 0, { now: nowString, stale: staleBefore }
    );
    if (!candidates.length) return;

    var appId = $app.findFirstRecordByFilter(
      "lms_settings", "key = {:k}", { k: "onesignal_app_id" }
    ).getString("value");
    var apiKey = $app.findFirstRecordByFilter(
      "lms_settings", "key = {:k}", { k: "onesignal_api_key" }
    ).getString("value");
    if (!appId || !apiKey) throw new Error("OneSignal credentials are not configured");

    for (var i = 0; i < candidates.length; i++) {
      var claimed = pushBroadcast.claimBroadcast($app, maintenance, candidates[i].id, staleBefore);
      if (!claimed) continue;
      var result = pushBroadcast.dispatchBroadcast($app, maintenance, appId, apiKey, claimed);
      $app.logger().info("push_scheduler: dispatch attempt", "id", claimed.id,
        "ok", result.ok, "retryable", Boolean(result.retryable));
    }
  });
});
