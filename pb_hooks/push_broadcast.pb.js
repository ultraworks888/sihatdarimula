// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/push-broadcast
// Body: { title, message, url?, target?, segment_config?, scheduled_at? }
// ─────────────────────────────────────────────────────────────────────────────
routerAdd("POST", "/api/admin/push-broadcast", function(e) {
  return require(__hooks + "/maintenance.js").http(e, function() {

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
  } catch (_) { require(__hooks + "/maintenance.js").rethrow(_); return e.json(500, { error: "OneSignal credentials not configured" }); }
  if (!appId || !apiKey) return e.json(500, { error: "OneSignal credentials are empty" });

  var appURL = "";
  try { appURL = $app.settings().meta.appURL || ""; } catch (_) { require(__hooks + "/maintenance.js").rethrow(_);}
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
    try { record.set("segment_config", JSON.stringify(segConfigRaw)); } catch (_) { require(__hooks + "/maintenance.js").rethrow(_);}
  }

  // If scheduled → save as pending and return
  if (scheduledAt) {
    record.set("status",       "pending");
    record.set("scheduled_at", scheduledAt);
    require(__hooks + "/maintenance.js").save($app, record);
    $app.logger().info("push_broadcast: scheduled", "at", scheduledAt, "title", title);
    return e.json(200, { ok: true, scheduled: true, scheduled_at: scheduledAt });
  }

  // Send immediately
  var maintenance = require(__hooks + "/maintenance.js");
  var pushBroadcast = require(__hooks + "/push_broadcast.js");
  var result = pushBroadcast.dispatchBroadcast(e.app, maintenance, appId, apiKey, record);
  if (!result.ok && !result.skipped) {
    return e.json(500, { error: "OneSignal rejected the request", status: result.statusCode });
  }
  return e.json(200, { ok: true, recipients: result.recipients, onesignal_id: result.onesignal_id });
  });
});


// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/push-broadcast/cancel
// Body: { id }
// ─────────────────────────────────────────────────────────────────────────────
routerAdd("POST", "/api/admin/push-broadcast/cancel", function(e) {
  return require(__hooks + "/maintenance.js").http(e, function() {

  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  var role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  var info = e.requestInfo();
  var id   = String(info.body.id || "").trim();
  if (!id) return e.json(400, { error: "id is required" });

  var broadcast;
  try { broadcast = $app.findRecordById("push_broadcasts", id); }
  catch (_) { require(__hooks + "/maintenance.js").rethrow(_); return e.json(404, { error: "Broadcast not found" }); }

  if (broadcast.getString("status") !== "pending") {
    return e.json(400, { error: "Only pending broadcasts can be cancelled" });
  }

  broadcast.set("status", "cancelled");
  require(__hooks + "/maintenance.js").save($app, broadcast);
  $app.logger().info("push_broadcast: cancelled", "id", id);
  return e.json(200, { ok: true });
  });
});


// ─────────────────────────────────────────────────────────────────────────────
// Cron: dispatch pending scheduled broadcasts (runs every 5 minutes)
// ─────────────────────────────────────────────────────────────────────────────
cronAdd("push_broadcast_scheduler", "*/5 * * * *", function() {
  return require(__hooks + "/maintenance.js").background(function() {
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
  } catch (_) { require(__hooks + "/maintenance.js").rethrow(_); return; }

  if (!pending || pending.length === 0) return;

  var appId, apiKey;
  try {
    appId  = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_app_id"  }).getString("value");
    apiKey = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_api_key" }).getString("value");
  } catch (_) { require(__hooks + "/maintenance.js").rethrow(_);
    $app.logger().error("push_scheduler: OneSignal credentials missing");
    return;
  }

  var maintenance = require(__hooks + "/maintenance.js");
  var pushBroadcast = require(__hooks + "/push_broadcast.js");
  for (var pi = 0; pi < pending.length; pi++) {
    var result = pushBroadcast.dispatchBroadcast($app, maintenance, appId, apiKey, pending[pi]);
    $app.logger().info("push_scheduler: dispatched", "id", pending[pi].id, "recipients", result.recipients);
  }
  });
});
