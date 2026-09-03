// ============================================================
// release1b_otp_test_adapter.pb.js — Round 24
// LOCAL ISOLATED TEST ADAPTER — NEVER DEPLOY TO PRODUCTION
// ============================================================
//
// R24 corrections:
//   D24-8.  Error responses sanitized: no internal record IDs,
//           no raw exception text, no OTP codes, no phone identifiers.
//           All modes return generic client-safe messages.
//
// All R23 corrections retained:
//   D23-4.  requesting_user_id stored in TX-1; verified in TX-3.
//   D23-5.  Expiry: return-from-TX commits state; throw outside TX.
//   D23-6.  TX-2 cleanup: errors not swallowed; 500 on cleanup fail.
//   D23-10. Adapter receives correctly formed JSON from harness.
//
// MODES (set via POST /api/test/otp-control):
//   success | send_failed | pending_send |
//   db_fail_request | db_fail_request_cleanup_fail |
//   db_fail_verify | pending_create_fail
//
// TRANSACTION DESIGN:
//   TX-1: create pending_send + requesting_user_id
//   TX-2: activate → sent_active (or send_failed)
//   TX-3: return-from-TX commits outcome; throw outside
//
// SAFETY: Loopback-only. Synthetic phones (+601_R24TEST_*) only.
//         Never contacts Meta. No phone/code/identity logging.
// ============================================================

"use strict";

var _adapterState = { mode: "success", epochId: 0 };

var _MODES = [
  "success",
  "send_failed",
  "pending_send",
  "db_fail_request",
  "db_fail_request_cleanup_fail",
  "db_fail_verify",
  "pending_create_fail",
];

var _ST_PENDING  = "pending_send";
var _ST_ACTIVE   = "sent_active";
var _ST_FAILED   = "send_failed";
var _ST_EXPIRED  = "expired";
var _ST_CONSUMED = "consumed";

var _SYNTH_RE = /^\+601_R24TEST_\d{4,16}$/;
var _OTP_LEN  = 6;
var _TTL_MS   = 300000;

function _requireLoopback(e) {
  var raw = (e.request && e.request.remoteAddr ? e.request.remoteAddr : "").toString();
  var ok  = /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(raw) ||
             raw === "::1" || /^\[::1\]:\d+$/.test(raw);
  if (!ok) throw new ForbiddenError("Adapter: non-loopback request rejected.");
}

function _requireOrdinaryUser(e) {
  if (!e.auth) throw new UnauthorizedError("Authentication required.");
  try {
    if (e.auth.collection().name !== "users") {
      throw new ForbiddenError("Phone linking requires a users-collection session.");
    }
  } catch (inner) {
    if (inner instanceof ForbiddenError || inner instanceof UnauthorizedError) throw inner;
    throw new UnauthorizedError("Session verification failed.");
  }
  var role = e.auth.getString("role");
  if (role === "admin" || role === "superadmin") {
    throw new ForbiddenError("Admin accounts cannot use the phone-linking flow.");
  }
}

function _requireNSU(e) {
  if (!e.auth) throw new UnauthorizedError("Superuser token required.");
  try {
    if (e.auth.collection().name !== "_superusers") {
      throw new ForbiddenError("Superuser token required.");
    }
  } catch (inner) {
    if (inner instanceof ForbiddenError || inner instanceof UnauthorizedError) throw inner;
    throw new UnauthorizedError("Superuser session verification failed.");
  }
}

function _requireSynthPhone(phone) {
  if (!phone || !_SYNTH_RE.test(phone)) {
    throw new BadRequestError(
      "Only R24 synthetic test identifiers accepted."
    );
  }
}

function _generateCode(len) {
  var c = "";
  for (var i = 0; i < len; i++) c += String(Math.floor(Math.random() * 10));
  return c;
}

function _expiryISO(ms) { return new Date(Date.now() + ms).toISOString(); }

function _localProvider(mode) {
  if (mode === "pending_send")                 return { pending: true };
  if (mode === "send_failed")                  return { success: false };
  if (mode === "db_fail_request")              return { success: true, dbFail: true };
  if (mode === "db_fail_request_cleanup_fail") return { success: true, dbFail: true, cleanupFail: true };
  return { success: true };
}

function _invalidatePriorActive(txApp, candidatePhone, requestingUserId) {
  var prior = txApp.findRecordsByFilter(
    "phone_otps",
    "phone = {:p} && adapter_status = {:s} && requesting_user_id = {:u}",
    "", 100, 0, { p: candidatePhone, s: _ST_ACTIVE, u: requestingUserId }
  );
  for (var i = 0; i < prior.length; i++) {
    prior[i].set("adapter_status", _ST_FAILED);
    prior[i].set("is_used", true);
    txApp.save(prior[i]);
  }
}

// ════════════════════════════════════════════════════════════
// POST /api/test/otp-control  (_superusers only)
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/test/otp-control", function(e) {
  _requireLoopback(e); _requireNSU(e);
  var body = e.requestInfo().body;
  var newMode = String(body.mode || "").toLowerCase();
  var valid = false;
  for (var i = 0; i < _MODES.length; i++) {
    if (_MODES[i] === newMode) { valid = true; break; }
  }
  if (!valid) throw new BadRequestError("mode must be one of: " + _MODES.join(" | "));
  _adapterState.mode    = newMode;
  _adapterState.epochId = (_adapterState.epochId + 1) | 0;
  return e.json(200, { mode: _adapterState.mode, epochId: _adapterState.epochId });
});

// ════════════════════════════════════════════════════════════
// GET /api/test/otp-rate-count  (_superusers only)
// ════════════════════════════════════════════════════════════
routerAdd("GET", "/api/test/otp-rate-count", function(e) {
  _requireLoopback(e); _requireNSU(e);
  return e.json(200, {
    epochId: _adapterState.epochId,
    note: "Query phone_otps collection for authoritative count.",
  });
});

// ════════════════════════════════════════════════════════════
// POST /api/auth/request-whatsapp-otp
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/request-whatsapp-otp", function(e) {
  _requireLoopback(e); _requireOrdinaryUser(e);
  var body  = e.requestInfo().body;
  var phone = String(body.phone || "").trim();
  _requireSynthPhone(phone);

  var requestingUserId = e.auth.id;
  var currentMode      = _adapterState.mode;

  // pending_create_fail: TX-1 throws → rolls back → no record.
  if (currentMode === "pending_create_fail") {
    $app.runInTransaction(function(txApp) {
      var col = txApp.findCollectionByNameOrId("phone_otps");
      var rec = new Record(col);
      rec.set("phone", phone);
      rec.set("requesting_user_id", requestingUserId);
      rec.set("code", "");
      rec.set("is_used", false);
      rec.set("adapter_status", _ST_PENDING);
      rec.set("expires_at", _expiryISO(_TTL_MS));
      txApp.save(rec);
      throw new Error("pending_create_fail: simulated TX-1 failure.");
    });
    throw new BadRequestError("OTP request could not be initiated. Please try again.");
  }

  // TX-1: create pending record.
  var otpRecId;
  $app.runInTransaction(function(txApp) {
    var col = txApp.findCollectionByNameOrId("phone_otps");
    var rec = new Record(col);
    rec.set("phone", phone);
    rec.set("requesting_user_id", requestingUserId);
    rec.set("code", "");
    rec.set("is_used", false);
    rec.set("adapter_status", _ST_PENDING);
    rec.set("expires_at", _expiryISO(_TTL_MS));
    txApp.save(rec);
    otpRecId = rec.id;
  });

  // Outside TX: local provider fixture.
  var provResult = _localProvider(currentMode);

  if (provResult.pending) {
    return e.json(200, { status: "pending" });
  }

  // TX-2: transition pending → active or failed.
  if (provResult.dbFail) {
    try {
      $app.runInTransaction(function(txApp) {
        var rec = txApp.findRecordById("phone_otps", otpRecId);
        if (rec.getString("adapter_status") !== _ST_PENDING) {
          throw new Error("Concurrent modification: OTP no longer pending.");
        }
        throw new Error("db_fail_request: simulated TX-2 activation failure.");
      });
    } catch (_) {
      // Expected: TX-2 rolled back.
    }

    // D24-8: Cleanup errors not swallowed; error message does not expose record ID.
    var cleanupSucceeded = false;
    var cleanupOccurred  = false;
    try {
      $app.runInTransaction(function(txApp) {
        if (provResult.cleanupFail) {
          throw new Error("Simulated cleanup failure.");
        }
        var rec = txApp.findRecordById("phone_otps", otpRecId);
        if (rec.getString("adapter_status") === _ST_PENDING) {
          rec.set("adapter_status", _ST_FAILED);
          txApp.save(rec);
          cleanupOccurred = true;
        }
      });
      cleanupSucceeded = true;
    } catch (_) {
      cleanupSucceeded = false;
    }

    if (!cleanupSucceeded) {
      // D24-8: Generic error; no internal ID or exception text.
      throw new InternalServerError(
        "OTP send failed and internal cleanup could not complete. " +
        "Please try again later."
      );
    }

    throw new BadRequestError("OTP send failed. Please try again.");
  }

  if (!provResult.success) {
    $app.runInTransaction(function(txApp) {
      var rec = txApp.findRecordById("phone_otps", otpRecId);
      rec.set("adapter_status", _ST_FAILED);
      txApp.save(rec);
    });
    throw new BadRequestError("OTP delivery failed. Please try again.");
  }

  // Provider success: invalidate prior, activate.
  $app.runInTransaction(function(txApp) {
    var rec = txApp.findRecordById("phone_otps", otpRecId);
    if (rec.getString("adapter_status") !== _ST_PENDING) {
      throw new Error("Concurrent modification: OTP no longer pending.");
    }
    _invalidatePriorActive(txApp, phone, requestingUserId);
    var code = _generateCode(_OTP_LEN);
    rec.set("adapter_status", _ST_ACTIVE);
    rec.set("code", code);
    txApp.save(rec);
  });

  return e.json(200, { status: "sent" });
});

// ════════════════════════════════════════════════════════════
// POST /api/auth/verify-whatsapp-otp
// D23-4: Verification binds to requesting_user_id == e.auth.id.
// D23-5: Return-from-TX commits outcome; throw OUTSIDE TX.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/verify-whatsapp-otp", function(e) {
  _requireLoopback(e); _requireOrdinaryUser(e);
  var body  = e.requestInfo().body;
  var phone = String(body.phone || "").trim();
  var code  = String(body.code  || "").trim();
  _requireSynthPhone(phone);
  if (!code || !/^\d{6}$/.test(code)) {
    throw new BadRequestError("code must be exactly 6 decimal digits.");
  }

  var callerId    = e.auth.id;
  var currentMode = _adapterState.mode;
  var outcome     = { action: "unknown" };

  $app.runInTransaction(function(txApp) {
    var actives = txApp.findRecordsByFilter(
      "phone_otps",
      "phone = {:p} && adapter_status = {:s}",
      "", 20, 0, { p: phone, s: _ST_ACTIVE }
    );

    if (!actives || actives.length === 0) {
      outcome.action = "none"; return;
    }

    // D23-4: filter by requesting_user_id.
    var owned = null;
    for (var i = 0; i < actives.length; i++) {
      if (actives[i].getString("requesting_user_id") === callerId) {
        owned = actives[i]; break;
      }
    }
    if (!owned) {
      outcome.action = "forbidden"; return;
    }

    // D23-5: Expiry — return (commit expired state), throw outside.
    var exp = new Date(owned.getString("expires_at"));
    if (exp < new Date()) {
      owned.set("adapter_status", _ST_EXPIRED);
      owned.set("is_used", true);
      txApp.save(owned);
      outcome.action = "expired"; return;  // TX commits expired state
    }

    if (owned.getString("code") !== code) {
      outcome.action = "mismatch"; return;
    }

    // db_fail_verify: throw BEFORE writes → full rollback.
    if (currentMode === "db_fail_verify") {
      throw new BadRequestError("OTP verification temporarily unavailable. Please try again.");
    }

    owned.set("adapter_status", _ST_CONSUMED);
    owned.set("is_used", true);
    txApp.save(owned);

    var user = txApp.findRecordById("users", callerId);
    var targetRole = user.getString("role");
    if (targetRole === "admin" || targetRole === "superadmin") {
      throw new ForbiddenError("Admin accounts cannot be linked to a phone number.");
    }
    user.set("phone", phone);
    user.set("phone_verified", true);
    txApp.save(user);
    outcome.action = "verified";
  });

  if (outcome.action === "verified") return e.json(200, { verified: true });
  if (outcome.action === "expired")  throw new BadRequestError("OTP expired. Please request a new one.");
  if (outcome.action === "forbidden") throw new ForbiddenError("OTP does not belong to this session.");
  if (outcome.action === "none" || outcome.action === "mismatch") {
    throw new BadRequestError("OTP verification failed. Check the code and try again.");
  }
  throw new InternalServerError("Unexpected verification state.");
});
