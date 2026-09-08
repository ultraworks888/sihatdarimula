// CommonJS module: each JSVM callback imports this explicitly. No process-local
// counters or cached maintenance state. Only exact "false" permits new work.
const message = "Service temporarily unavailable for maintenance.";
const inflightCollection = "maintenance_inflight";

function runtimeApp() {
  // v0.29.3 cron executors can retain a prior hook's transaction-scoped
  // $app. Bootstrap keeps only the root App handle here, never drain state.
  const app = $app.store().get("maintenance.runtimeApp");
  if (!app || app.txInfo()) throw new Error(message);
  return app;
}

function coordination(app) {
  const c = app.findCollectionByNameOrId(inflightCollection);
  if (c.type !== "base" || c.listRule !== null || c.viewRule !== null ||
      c.createRule !== null || c.updateRule !== null || c.deleteRule !== null ||
      !c.fields.getByName("kind") || !c.fields.getByName("admitted_at")) {
    throw new Error(message);
  }
  return c;
}

// Persistent, non-expiring operation records. Acquire SQLite's writer lock
// BEFORE reading the setting so admission and a native setting update cannot
// cross. Never perform application work in this short admission transaction.
function admit(kind) {
  let id = "";
  try {
    runtimeApp().runInTransaction(function(tx) {
      tx.db().newQuery("UPDATE lms_settings SET value = value WHERE key = 'maintenance_mode'").execute();
      assertOpen(tx);
      const record = new Record(tx.findCollectionByNameOrId(inflightCollection));
      record.set("id", $security.randomStringWithAlphabet(15, "abcdefghijklmnopqrstuvwxyz0123456789"));
      record.set("kind", kind);
      tx.save(record);
      id = record.id;
    });
  } catch (_) {
    throw new Error(message);
  }
  return id;
}

function release(id) {
  try {
    runtimeApp().runInTransaction(function(tx) {
      tx.delete(tx.findRecordById(inflightCollection, id));
    });
  } catch (_) {
    // A failed release leaves persistent evidence, never a false zero count.
    $app.logger().error("Maintenance operation release failed; operator review required");
  }
}

function tracked(kind, action) {
  const id = admit(kind);
  try { return action(); }
  finally { release(id); }
}

function status(app) {
  let result = { maintenance_active: null, admission_closed: true,
    in_flight_prohibited_operations: null, drained: false, state_valid: false };
  try {
    coordination(app);
    // A single reader statement gives one SQLite snapshot without queuing
    // behind a long-running writer on PB's nonconcurrent transaction pool.
    const row = new DynamicModel({ settings_count: 0, setting_value: "", inflight: 0, unsupported_otp: 0 });
    app.concurrentDB().newQuery("SELECT " +
      "(SELECT count(*) FROM lms_settings WHERE key='maintenance_mode') AS settings_count, " +
      "coalesce((SELECT value FROM lms_settings WHERE key='maintenance_mode' LIMIT 1),'') AS setting_value, " +
      "(SELECT count(*) FROM maintenance_inflight) AS inflight, " +
      "(SELECT count(*) FROM _collections WHERE type='auth' AND name!='_superusers' " +
      "AND coalesce(json_extract(options,'$.otp.enabled'),0)!=0) AS unsupported_otp").one(row);
    const value = row.settings_count === 1 ? row.setting_value : "";
    // Native email-OTP is not used/enabled by this app. PB can asynchronously
    // delete its _otps record AFTER a failed mail hook returns. Do not certify
    // drain if an operator enables that uncovered lifecycle in the future.
    const valid = (value === "true" || value === "false") && row.unsupported_otp === 0;
    result = { maintenance_active: valid ? value === "true" : null,
      admission_closed: value !== "false", in_flight_prohibited_operations: row.inflight,
      drained: valid && value === "true" && row.inflight === 0, state_valid: valid };
  } catch (_) { /* missing/unreadable coordination must never report drained */ }
  return result;
}

function isOpen(app) {
  try {
    coordination(app);
    const rows = app.findRecordsByFilter(
      "lms_settings", "key = {:key}", "", 2, 0, { key: "maintenance_mode" }
    );
    return rows.length === 1 && rows[0].getString("value") === "false";
  } catch (_) {
    return false;
  }
}

function assertOpen(app) {
  if (!isOpen(app)) throw new Error(message);
}

// Transaction errors cross the Go/JS boundary; custom JS error properties do
// not reliably survive it. The fixed, non-sensitive message is the sentinel.
function isBlocked(error) {
  return String(error).indexOf(message) !== -1;
}

function rethrow(error) {
  if (isBlocked(error)) throw error;
}

function reject(e) {
  e.response.header().set("Retry-After", "3600");
  e.response.header().set("Cache-Control", "no-store");
  return e.json(503, { message: message });
}

function http(e, action, kind) {
  try {
    return tracked(kind || "http", function() {
      assertOpen(e.app);
      return action();
    });
  } catch (error) {
    if (isBlocked(error)) return reject(e);
    throw error;
  }
}

function background(action) {
  try {
    // Normalize the cron VM for the existing job body as well as admission.
    $app = runtimeApp();
    return tracked("cron", function() {
      assertOpen($app);
      return action();
    });
  } catch (error) {
    if (!isBlocked(error)) throw error;
  }
}

function event(e, action) {
  try {
    return tracked("event", function() {
      assertOpen(e.app);
      return action();
    });
  } catch (error) {
    if (isBlocked(error)) return e.next();
    throw error;
  }
}

function builtin(e) {
  // Native PocketBase administration only; application roles never bypass.
  if (e.hasSuperuserAuth()) return e.next();
  // The outer router middleware owns the persistent registration through the
  // entire handler/transaction. Do not create nested leases inside a DB tx.
  try { assertOpen(e.app); return e.next(); }
  catch (error) {
    if (isBlocked(error)) return reject(e);
    throw error;
  }
}

function mail(e) {
  if (e.record.collection().name === "_superusers") return e.next();
  try { return tracked("mail", function() { return e.next(); }); }
  catch (error) {
    // Suppress new mail work after closure without logging message/token data.
    if (!isBlocked(error)) throw error;
  }
}

function auth(e) {
  // v0.29.3 Collection has no isSuperusers() method. This is the resolved
  // server-side collection, never a client-supplied application role.
  if (e.collection.name === "_superusers") return e.next();
  return builtin(e);
}

module.exports = {
  isOpen, assertOpen, isBlocked, rethrow, reject, http, background, event,
  builtin, auth, mail, status,
  save: function(app, record) { assertOpen(app); return app.save(record); },
  remove: function(app, record) { assertOpen(app); return app.delete(record); },
  send: function(options) { assertOpen($app); return $http.send(options); },
};
