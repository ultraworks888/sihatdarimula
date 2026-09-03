// ─────────────────────────────────────────────────────────────────────────────
// Helper: resolve a segment config object to a list of PocketBase user IDs.
// Returns null  → use OneSignal built-in segments (all / subscribed).
// Returns []    → segment is valid but matched no users; skip the send.
// Returns [ids] → targeted send to these specific user IDs.
//
// NOTE: top-level helpers must use `var` (not `const`/`let`) so that Goja
// makes them accessible inside routerAdd / cronAdd callbacks.
// ─────────────────────────────────────────────────────────────────────────────
var resolveSegmentUserIds = function(segConfig) {
  if (!segConfig || !segConfig.type) return null;

  var seen = {};
  var add  = function(id) { if (id && !seen[id]) seen[id] = true; };

  try {
    var type = segConfig.type;

    if (type === "baby_age") {
      var minM = typeof segConfig.minMonths === "number" ? segConfig.minMonths : 0;
      var maxM = typeof segConfig.maxMonths === "number" ? segConfig.maxMonths : 6;
      var now  = new Date();
      var pad  = function(n) { return String(n).padStart(2, "0"); };
      var fmt  = function(d) {
        return d.getFullYear() + "-" + pad(d.getMonth()+1) + "-" + pad(d.getDate()) + " 00:00:00.000Z";
      };
      var maxDob = new Date(now); maxDob.setMonth(maxDob.getMonth() - minM);
      var minDob = new Date(now); minDob.setMonth(minDob.getMonth() - maxM);
      var babyRows = $app.findRecordsByFilter(
        "children",
        "is_born = true && date_of_birth >= {:a} && date_of_birth <= {:b}",
        "", 0, 0, { a: fmt(minDob), b: fmt(maxDob) }
      );
      for (var bi = 0; bi < babyRows.length; bi++) add(babyRows[bi].getString("user"));

    } else if (type === "expectant") {
      var expectRows = $app.findRecordsByFilter("children", "is_born = false", "", 0, 0, {});
      for (var ei = 0; ei < expectRows.length; ei++) add(expectRows[ei].getString("user"));

    } else if (type === "course_enrolled") {
      var cid = segConfig.courseId || "";
      if (!cid) return [];
      var enrRows = $app.findRecordsByFilter("enrollments", "course = {:cid}", "", 0, 0, { cid: cid });
      for (var eri = 0; eri < enrRows.length; eri++) add(enrRows[eri].getString("user"));

    } else if (type === "not_enrolled") {
      var enrolled = {};
      var allEnr = $app.findRecordsByFilter("enrollments", "id != ''", "", 0, 0, {});
      for (var nei = 0; nei < allEnr.length; nei++) enrolled[allEnr[nei].getString("user")] = true;
      var allUsr = $app.findRecordsByFilter("users", "id != ''", "", 0, 0, {});
      for (var ui = 0; ui < allUsr.length; ui++) {
        var role = allUsr[ui].getString("role");
        if (role === "admin" || role === "superadmin") continue;
        if (!enrolled[allUsr[ui].id]) add(allUsr[ui].id);
      }

    } else if (type === "language") {
      var lang = segConfig.lang || "en";
      var langRows = $app.findRecordsByFilter("users", "language = {:lang}", "", 0, 0, { lang: lang });
      for (var li = 0; li < langRows.length; li++) add(langRows[li].id);
    }

  } catch (err) {
    $app.logger().error("push_broadcast resolveSegment", "type", segConfig.type, "err", String(err));
  }

  return Object.keys(seen);
};

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build and send a OneSignal notification for one broadcast record.
// Updates the record (status, recipient_count, onesignal_id) and saves it.
// ─────────────────────────────────────────────────────────────────────────────
var dispatchBroadcast = function(appId, apiKey, record) {
  var title   = record.getString("title");
  var message = record.getString("message");
  var url     = record.getString("url");
  var target  = record.getString("target");

  // Parse segment config (stored as JSON string in Goja environment)
  var segConfig = null;
  var segStr = record.getString("segment_config");
  if (segStr) {
    try { segConfig = JSON.parse(segStr); } catch (_) {}
  }

  var payload;

  if (target === "segment" && segConfig) {
    // ── Custom segment: resolve PocketBase user IDs → OneSignal external IDs ──
    var userIds = resolveSegmentUserIds(segConfig);
    if (!userIds || userIds.length === 0) {
      record.set("status", "sent");
      record.set("recipient_count", 0);
      try { $app.save(record); } catch (_) {}
      $app.logger().info("push_dispatch: segment matched 0 users, skipped OneSignal", "id", record.id);
      return { ok: true, recipients: 0, skipped: true };
    }
    $app.logger().info("push_dispatch: targeting users", "count", userIds.length, "segment", segConfig.type);
    payload = {
      app_id:           appId,
      include_aliases:  { external_id: userIds },
      target_channel:   "push",
      headings:  { en: title,   ms: title,   zh: title },
      contents:  { en: message, ms: message, zh: message },
      url:       url,
    };

  } else {
    // ── Built-in OneSignal segment ──────────────────────────────────────────
    var segs = target === "subscribed" ? ["Subscribed Users"] : ["All"];
    payload = {
      app_id:            appId,
      included_segments: segs,
      headings:  { en: title,   ms: title,   zh: title },
      contents:  { en: message, ms: message, zh: message },
      url:       url,
    };
  }

  var res = $http.send({
    url:    "https://onesignal.com/api/v1/notifications",
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Basic " + apiKey },
    body:   JSON.stringify(payload),
    timeout: 30,
  });

  var ok         = res.statusCode < 400;
  var recipients = (res.json && typeof res.json["recipients"] === "number") ? res.json["recipients"] : 0;
  var osId       = (res.json && res.json["id"]) ? String(res.json["id"]) : "";

  record.set("status", ok ? "sent" : "failed");
  record.set("recipient_count", recipients);
  if (osId) record.set("onesignal_id", osId);
  try { $app.save(record); } catch (se) {
    $app.logger().error("push_dispatch: save failed", "id", record.id, "err", String(se));
  }

  $app.logger().info("push_dispatch: result", "ok", ok, "recipients", recipients, "osId", osId);
  return { ok: ok, statusCode: res.statusCode, recipients: recipients, onesignal_id: osId };
};


// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/push-broadcast
// Body: { title, message, url?, target?, segment_config?, scheduled_at? }
// ─────────────────────────────────────────────────────────────────────────────
routerAdd("POST", "/api/admin/push-broadcast", function(e) {

  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  var role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  var info         = e.requestInfo();
  var title        = String(info.body.title        || "").trim();
  var message      = String(info.body.message      || "").trim();
  var url          = String(info.body.url          || "").trim();
  var target       = String(info.body.target       || "all").trim();
  var scheduledAt  = String(info.body.scheduled_at || "").trim();
  var segConfigRaw = info.body.segment_config;

  if (!title || !message) return e.json(400, { error: "title and message are required" });

  // Load OneSignal credentials
  var appId, apiKey;
  try {
    appId  = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_app_id"  }).getString("value");
    apiKey = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_api_key" }).getString("value");
  } catch (_) { return e.json(500, { error: "OneSignal credentials not configured" }); }
  if (!appId || !apiKey) return e.json(500, { error: "OneSignal credentials are empty" });

  var appURL = "";
  try { appURL = $app.settings().meta.appURL || ""; } catch (_) {}
  var notifUrl = url || (appURL + "/content");

  // Create the log record
  var col    = $app.findCollectionByNameOrId("push_broadcasts");
  var record = new Record(col);
  record.set("title",   title);
  record.set("message", message);
  record.set("sent_by", e.auth.id);
  record.set("target",  target);
  record.set("url",     notifUrl);

  // Persist segment config as JSON string
  if (segConfigRaw && typeof segConfigRaw === "object") {
    try { record.set("segment_config", JSON.stringify(segConfigRaw)); } catch (_) {}
  }

  // If scheduled → save as pending and return
  if (scheduledAt) {
    record.set("status",       "pending");
    record.set("scheduled_at", scheduledAt);
    $app.save(record);
    $app.logger().info("push_broadcast: scheduled", "at", scheduledAt, "title", title);
    return e.json(200, { ok: true, scheduled: true, scheduled_at: scheduledAt });
  }

  // Send immediately
  var result = dispatchBroadcast(appId, apiKey, record);
  if (!result.ok && !result.skipped) {
    return e.json(500, { error: "OneSignal rejected the request", status: result.statusCode });
  }
  return e.json(200, { ok: true, recipients: result.recipients, onesignal_id: result.onesignal_id });
});


// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/push-broadcast/cancel
// Body: { id }
// ─────────────────────────────────────────────────────────────────────────────
routerAdd("POST", "/api/admin/push-broadcast/cancel", function(e) {

  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  var role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  var info = e.requestInfo();
  var id   = String(info.body.id || "").trim();
  if (!id) return e.json(400, { error: "id is required" });

  var broadcast;
  try { broadcast = $app.findRecordById("push_broadcasts", id); }
  catch (_) { return e.json(404, { error: "Broadcast not found" }); }

  if (broadcast.getString("status") !== "pending") {
    return e.json(400, { error: "Only pending broadcasts can be cancelled" });
  }

  broadcast.set("status", "cancelled");
  $app.save(broadcast);
  $app.logger().info("push_broadcast: cancelled", "id", id);
  return e.json(200, { ok: true });
});


// ─────────────────────────────────────────────────────────────────────────────
// Cron: dispatch pending scheduled broadcasts (runs every 5 minutes)
// ─────────────────────────────────────────────────────────────────────────────
cronAdd("push_broadcast_scheduler", "*/5 * * * *", function() {
  var now = new Date();
  var pad = function(n) { return String(n).padStart(2, "0"); };
  var nowStr = now.getFullYear() + "-" + pad(now.getMonth()+1) + "-" + pad(now.getDate())
             + " " + pad(now.getHours()) + ":" + pad(now.getMinutes()) + ":59.000Z";

  var pending;
  try {
    pending = $app.findRecordsByFilter(
      "push_broadcasts",
      "status = 'pending' && scheduled_at != '' && scheduled_at <= {:now}",
      "", 0, 0, { now: nowStr }
    );
  } catch (_) { return; }

  if (!pending || pending.length === 0) return;

  var appId, apiKey;
  try {
    appId  = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_app_id"  }).getString("value");
    apiKey = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_api_key" }).getString("value");
  } catch (_) {
    $app.logger().error("push_scheduler: OneSignal credentials missing");
    return;
  }

  for (var pi = 0; pi < pending.length; pi++) {
    var result = dispatchBroadcast(appId, apiKey, pending[pi]);
    $app.logger().info("push_scheduler: dispatched", "id", pending[pi].id, "recipients", result.recipients);
  }
});
