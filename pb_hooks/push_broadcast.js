// CommonJS module: PocketBase executes each hook handler in an isolated JSVM,
// so handlers must import shared helpers explicitly instead of relying on
// declarations from the .pb.js registration file.

function resolveSegmentUserIds(app, maintenance, segConfig) {
  if (!segConfig || !segConfig.type) return null;

  const seen = {};
  const add = function(id) { if (id && !seen[id]) seen[id] = true; };

  try {
    const type = segConfig.type;

    if (type === "baby_age") {
      const minM = typeof segConfig.minMonths === "number" ? segConfig.minMonths : 0;
      const maxM = typeof segConfig.maxMonths === "number" ? segConfig.maxMonths : 6;
      const now = new Date();
      const pad = function(n) { return String(n).padStart(2, "0"); };
      const fmt = function(d) {
        return d.getFullYear() + "-" + pad(d.getMonth()+1) + "-" + pad(d.getDate()) + " 00:00:00.000Z";
      };
      const maxDob = new Date(now); maxDob.setMonth(maxDob.getMonth() - minM);
      const minDob = new Date(now); minDob.setMonth(minDob.getMonth() - maxM);
      const babyRows = app.findRecordsByFilter(
        "children",
        "is_born = true && date_of_birth >= {:a} && date_of_birth <= {:b}",
        "", 0, 0, { a: fmt(minDob), b: fmt(maxDob) }
      );
      for (let bi = 0; bi < babyRows.length; bi++) add(babyRows[bi].getString("user"));

    } else if (type === "expectant") {
      const expectRows = app.findRecordsByFilter("children", "is_born = false", "", 0, 0, {});
      for (let ei = 0; ei < expectRows.length; ei++) add(expectRows[ei].getString("user"));

    } else if (type === "course_enrolled") {
      const cid = segConfig.courseId || "";
      if (!cid) return [];
      const enrRows = app.findRecordsByFilter("enrollments", "course = {:cid}", "", 0, 0, { cid: cid });
      for (let eri = 0; eri < enrRows.length; eri++) add(enrRows[eri].getString("user"));

    } else if (type === "not_enrolled") {
      const enrolled = {};
      const allEnr = app.findRecordsByFilter("enrollments", "id != ''", "", 0, 0, {});
      for (let nei = 0; nei < allEnr.length; nei++) enrolled[allEnr[nei].getString("user")] = true;
      const allUsr = app.findRecordsByFilter("users", "id != ''", "", 0, 0, {});
      for (let ui = 0; ui < allUsr.length; ui++) {
        const role = allUsr[ui].getString("role");
        if (role === "admin" || role === "superadmin") continue;
        if (!enrolled[allUsr[ui].id]) add(allUsr[ui].id);
      }

    } else if (type === "language") {
      const lang = segConfig.lang || "en";
      const langRows = app.findRecordsByFilter("users", "language = {:lang}", "", 0, 0, { lang: lang });
      for (let li = 0; li < langRows.length; li++) add(langRows[li].id);
    }

  } catch (err) {
    maintenance.rethrow(err);
    app.logger().error("push_broadcast resolveSegment", "type", segConfig.type, "err", String(err));
  }

  return Object.keys(seen);
}

function dispatchBroadcast(app, maintenance, appId, apiKey, record) {
  const title = record.getString("title");
  const message = record.getString("message");
  const url = record.getString("url");
  const target = record.getString("target");

  let segConfig = null;
  const segStr = record.getString("segment_config");
  if (segStr) {
    try { segConfig = JSON.parse(segStr); } catch (_) { maintenance.rethrow(_); }
  }

  let payload;

  if (target === "segment" && segConfig) {
    const userIds = resolveSegmentUserIds(app, maintenance, segConfig);
    if (!userIds || userIds.length === 0) {
      record.set("status", "sent");
      record.set("recipient_count", 0);
      try { maintenance.save(app, record); } catch (_) { maintenance.rethrow(_); }
      app.logger().info("push_dispatch: segment matched 0 users, skipped OneSignal", "id", record.id);
      return { ok: true, recipients: 0, skipped: true };
    }
    app.logger().info("push_dispatch: targeting users", "count", userIds.length, "segment", segConfig.type);
    payload = {
      app_id: appId,
      include_aliases: { external_id: userIds },
      target_channel: "push",
      headings: { en: title, ms: title, zh: title },
      contents: { en: message, ms: message, zh: message },
      url: url,
    };

  } else {
    const segs = target === "subscribed" ? ["Subscribed Users"] : ["All"];
    payload = {
      app_id: appId,
      included_segments: segs,
      headings: { en: title, ms: title, zh: title },
      contents: { en: message, ms: message, zh: message },
      url: url,
    };
  }

  const res = maintenance.send({
    url: "https://onesignal.com/api/v1/notifications",
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Basic " + apiKey },
    body: JSON.stringify(payload),
    timeout: 30,
  });

  const ok = res.statusCode < 400;
  const recipients = (res.json && typeof res.json["recipients"] === "number") ? res.json["recipients"] : 0;
  const osId = (res.json && res.json["id"]) ? String(res.json["id"]) : "";

  record.set("status", ok ? "sent" : "failed");
  record.set("recipient_count", recipients);
  if (osId) record.set("onesignal_id", osId);
  try { maintenance.save(app, record); } catch (saveError) {
    maintenance.rethrow(saveError);
    app.logger().error("push_dispatch: save failed", "id", record.id, "err", String(saveError));
  }

  app.logger().info("push_dispatch: result", "ok", ok, "recipients", recipients, "osId", osId);
  return { ok: ok, statusCode: res.statusCode, recipients: recipients, onesignal_id: osId };
}

module.exports = { dispatchBroadcast };
