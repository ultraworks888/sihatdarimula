// ============================================================
// release1b_otp_test_adapter.pb.js — Round 23
// LOCAL ISOLATED TEST ADAPTER — NEVER DEPLOY TO PRODUCTION
// ============================================================
//
// R23 CORRECTIONS:
//   D23-4.  requesting_user_id stored in TX-1; verified in TX-3.
//           Cross-user spoofing rejected.
//   D23-5.  Expired OTP: TX returns (commits expired state), then
//           throws OUTSIDE the transaction. No throw-after-save.
//   D23-6.  TX-2 cleanup: errors not swallowed; 500 on cleanup fail.
//           Mode db_fail_request_cleanup_fail tests this path.
//   D23-10. OTP bodies use strict JSON encoder on harness side;
//           adapter itself receives correctly formed JSON.
//
// SCHEMA DEPENDENCIES (all added via 9999999999_r23_future_schema.js):
//   users.phone_verified         bool
//   phone_otps.adapter_status    select: pending_send, sent_active,
//                                send_failed, expired, consumed
//   phone_otps.requesting_user_id text
//
// PRODUCTION FIELDS USED:
//   phone_otps: phone, code, expires_at, is_used (bool)
//   users: phone, phone_verified (future)
//
// TRANSACTION DESIGN:
//   TX-1 (request):  atomically create pending_send + set requesting_user_id
//   (outside TX):    call local deterministic provider fixture
//   TX-2 (request):  transition pending → sent_active | send_failed
//   TX-3 (verify):   expire-check and expiry in separate returns;
//                    then atomically consume OTP + write phone + phone_verified
//
// AUTH CONTRACT:
//   /api/auth/request-whatsapp-otp  — ordinary user token required
//   /api/auth/verify-whatsapp-otp   — same; caller must own the OTP request
//   /api/test/otp-control           — _superusers only
//   /api/test/otp-rate-count        — _superusers only
//
// SAFETY:
//   Loopback-only (correct IPv6 parsing). Synthetic phones only.
//   Never contacts Meta. Never logs phone, code, or user identity.
// ============================================================

"use strict";

var _adapterState = { mode: "success", epochId: 0 };

var _MODES = [
  "success",
  "send_failed",
  "pending_send",
  "db_fail_request",              // TX-2 rolls back; cleanup succeeds (send_failed)
  "db_fail_request_cleanup_fail", // TX-2 rolls back; cleanup also fails (remains pending)
  "db_fail_verify",               // TX-3 rolls back; OTP stays active (retryable)
  "pending_create_fail",          // TX-1 rolls back; no record created
];

var _ST_PENDING  = "pending_send";
var _ST_ACTIVE   = "sent_active";
var _ST_FAILED   = "send_failed";
var _ST_EXPIRED  = "expired";
var _ST_CONSUMED = "consumed";

// Synthetic phone: +601_R23TEST_<4-16 decimal digits>
var _SYNTH_RE = /^\+601_R23TEST_\d{4,16}$/;

var _OTP_LEN = 6;
var _TTL_MS  = 300000; // 5 minutes

// ── Loopback enforcement ─────────────────────────────────────
function _requireLoopback(e) {
  var raw = (e.request && e.request.remoteAddr ? e.request.remoteAddr : "").toString();
  var ok = /^127\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(raw) ||
            raw === "::1" ||
            /^\[::1\]:\d+$/.test(raw);
  if (!ok) throw new ForbiddenError("OTP adapter: non-loopback rejected.");
}

// ── Ordinary-user auth enforcement ───────────────────────────
function _requireOrdinaryUser(e) {
  if (!e.auth) throw new UnauthorizedError("Authentication required (ordinary user token).");
  try {
    if (e.auth.collection().name !== "users") {
      throw new ForbiddenError("Phone linking requires a users-collection session.");
    }
  } catch (inner) {
    if (inner instanceof ForbiddenError || inner instanceof UnauthorizedError) throw inner;
    throw new UnauthorizedError("Cannot verify session collection.");
  }
  var role = e.auth.getString("role");
  if (role === "admin" || role === "superadmin") {
    throw new ForbiddenError(
      "Admin and superadmin accounts cannot use the phone-linking flow."
    );
  }
}

// ── _superusers enforcement ──────────────────────────────────
function _requireNSU(e) {
  if (!e.auth) throw new UnauthorizedError("_superusers token required.");
  try {
    if (e.auth.collection().name !== "_superusers") {
      throw new ForbiddenError("_superusers token required.");
    }
  } catch (inner) {
    if (inner instanceof ForbiddenError || inner instanceof UnauthorizedError) throw inner;
    throw new UnauthorizedError("NSU verification failed.");
  }
}

// ── Synthetic phone validation ────────────────────────────────
function _requireSynthPhone(phone) {
  if (!phone || !_SYNTH_RE.test(phone)) {
    throw new BadRequestError(
      "OTP adapter: only R23 synthetic identifiers accepted (+601_R23TEST_<4-16 digits>)."
    );
  }
}

function _generateCode(len) {
  var c = ""; for (var i = 0; i < len; i++) c += String(Math.floor(Math.random() * 10));
  return c;
}

function _expiryISO(ms) {
  return new Date(Date.now() + ms).toISOString();
}

// ── Local deterministic provider fixture ─────────────────────
function _localProvider(mode) {
  if (mode === "pending_send")                  return { pending: true };
  if (mode === "send_failed")                   return { success: false };
  if (mode === "db_fail_request")               return { success: true, dbFail: true };
  if (mode === "db_fail_request_cleanup_fail")  return { success: true, dbFail: true, cleanupFail: true };
  return { success: true };
}

// ── Invalidate prior sent_active OTPs within a transaction ───
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
  _requireLoopback(e);
  _requireNSU(e);
  var body    = e.requestInfo().body;
  var newMode = String(body.mode || "").toLowerCase();
  var valid   = false;
  for (var i = 0; i < _MODES.length; i++) { if (_MODES[i] === newMode) { valid = true; break; } }
  if (!valid) throw new BadRequestError("mode must be one of: " + _MODES.join(" | "));
  _adapterState.mode    = newMode;
  _adapterState.epochId = (_adapterState.epochId + 1) | 0;
  return e.json(200, { mode: _adapterState.mode, epochId: _adapterState.epochId });
});

// ════════════════════════════════════════════════════════════
// GET /api/test/otp-rate-count  (_superusers only)
// ════════════════════════════════════════════════════════════
routerAdd("GET", "/api/test/otp-rate-count", function(e) {
  _requireLoopback(e);
  _requireNSU(e);
  return e.json(200, {
    epochId: _adapterState.epochId,
    note: "Authoritative count: query phone_otps collection via _superusers.",
  });
});

// ════════════════════════════════════════════════════════════
// POST /api/auth/request-whatsapp-otp
// Auth: ordinary user token required.
// Body: { "phone": "+601_R23TEST_XXXX" }
//
// TX-1: create pending_send record, set requesting_user_id = e.auth.id.
// (outside TX): local provider fixture.
// TX-2: transition pending → sent_active | send_failed.
//   db_fail_request: TX-2 throws → rolls back → cleanup to send_failed.
//   db_fail_request_cleanup_fail: TX-2 rolls back + cleanup also fails → 500.
//   pending_create_fail: TX-1 throws → no record.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/request-whatsapp-otp", function(e) {
  _requireLoopback(e);
  _requireOrdinaryUser(e);

  var body  = e.requestInfo().body;
  var phone = String(body.phone || "").trim();
  _requireSynthPhone(phone);

  var requestingUserId = e.auth.id;
  var currentMode      = _adapterState.mode;

  // pending_create_fail: simulate TX-1 failure.
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
    // If throw propagated, execution stops above. Unreachable normally.
    throw new BadRequestError("Pending record creation failed. No OTP created.");
  }

  // TX-1: create pending_send record.
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

  // TX-2: transition the pending record.
  var activationStatus = "unknown";

  if (provResult.dbFail) {
    // Simulate TX-2 activation failure: throw inside TX → rolls back.
    try {
      $app.runInTransaction(function(txApp) {
        var rec = txApp.findRecordById("phone_otps", otpRecId);
        if (rec.getString("adapter_status") !== _ST_PENDING) {
          throw new Error("Concurrent modification: OTP no longer pending.");
        }
        throw new Error("db_fail_request: simulated TX-2 activation failure.");
      });
    } catch (_) {
      // Expected: TX-2 rolled back. Record is still pending_send.
    }

    // Cleanup: transition pending_send → send_failed in a separate TX.
    // D23-6: do NOT swallow cleanup errors.
    var cleanupSucceeded = false;
    var cleanupErrMsg    = "";
    try {
      $app.runInTransaction(function(txApp) {
        if (provResult.cleanupFail) {
          throw new Error("db_fail_request_cleanup_fail: simulated cleanup failure.");
        }
        var rec = txApp.findRecordById("phone_otps", otpRecId);
        if (rec.getString("adapter_status") === _ST_PENDING) {
          rec.set("adapter_status", _ST_FAILED);
          txApp.save(rec);
        }
      });
      cleanupSucceeded = true;
    } catch (cleanupEx) {
      cleanupErrMsg = String(cleanupEx);
    }

    if (!cleanupSucceeded) {
      // State unresolved: pending_send record may remain.
      throw new InternalServerError(
        "TX-2 rollback cleanup failed. Record " + otpRecId +
        " may remain in pending_send. Rate limiting may be compromised. " +
        "Cleanup error: " + cleanupErrMsg
      );
    }

    throw new BadRequestError(
      "db_fail_request: TX-2 rolled back. Record cleaned to send_failed."
    );
  }

  if (!provResult.success) {
    // Provider failure: set send_failed in TX-2 (no throw → TX commits).
    $app.runInTransaction(function(txApp) {
      var rec = txApp.findRecordById("phone_otps", otpRecId);
      rec.set("adapter_status", _ST_FAILED);
      txApp.save(rec);
    });
    throw new BadRequestError("OTP delivery failed (send_failed mode).");
  }

  // Provider success: invalidate prior active + activate this one.
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
// Auth: ordinary user token required.
// Body: { "phone": "+601_R23TEST_XXXX", "code": "XXXXXX" }
//
// D23-4: Verification binds to requesting_user_id == e.auth.id.
// D23-5: Expiry handled inside TX-3 via return-then-throw pattern.
//        The TX COMMITS the expired state; throw happens OUTSIDE TX.
//
// TX-3 design: returns an action object describing the outcome.
//   On return (no throw): TX commits. Throw AFTER exit.
//   On throw: TX rolls back. OTP stays active (retryable).
//   db_fail_verify: throws before any save → full rollback.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/verify-whatsapp-otp", function(e) {
  _requireLoopback(e);
  _requireOrdinaryUser(e);

  var body  = e.requestInfo().body;
  var phone = String(body.phone || "").trim();
  var code  = String(body.code  || "").trim();

  _requireSynthPhone(phone);
  if (!code || !/^\d{6}$/.test(code)) {
    throw new BadRequestError("code must be exactly 6 decimal digits.");
  }

  var callerId    = e.auth.id;
  var currentMode = _adapterState.mode;

  // TX-3: expiry and verification in one transaction.
  // Returns an outcome object; throws only for true error/rollback scenarios.
  var outcome = { action: "unknown", reason: "" };

  $app.runInTransaction(function(txApp) {
    // Find active OTPs for this phone.
    var actives = txApp.findRecordsByFilter(
      "phone_otps",
      "phone = {:p} && adapter_status = {:s}",
      "", 20, 0, { p: phone, s: _ST_ACTIVE }
    );

    if (!actives || actives.length === 0) {
      // No active OTP: throw to roll back (nothing to roll back here, but consistent pattern).
      outcome.action = "none"; outcome.reason = "No active OTP found for this phone.";
      return; // exit callback; TX commits (nothing changed)
    }

    // D23-4: filter by requesting_user_id == callerId.
    var owned = null;
    for (var i = 0; i < actives.length; i++) {
      if (actives[i].getString("requesting_user_id") === callerId) {
        owned = actives[i]; break;
      }
    }
    if (!owned) {
      outcome.action = "forbidden";
      outcome.reason = "Active OTP exists but does not belong to the authenticated user.";
      return;
    }

    // D23-5: Check expiry. If expired: commit expired state, then throw OUTSIDE.
    var exp = new Date(owned.getString("expires_at"));
    var now = new Date();
    if (exp < now) {
      owned.set("adapter_status", _ST_EXPIRED);
      owned.set("is_used", true);
      txApp.save(owned);
      outcome.action = "expired"; outcome.reason = "OTP expired. Request a new one.";
      return; // exit callback; TX COMMITS the expired state.
    }

    // Match code.
    if (owned.getString("code") !== code) {
      outcome.action = "mismatch"; outcome.reason = "OTP code does not match.";
      return;
    }

    // db_fail_verify: throw BEFORE any writes → full TX rollback.
    if (currentMode === "db_fail_verify") {
      throw new BadRequestError(
        "db_fail_verify: simulated TX-3 failure. " +
        "TX rolled back. OTP stays active (retryable). phone+phone_verified unchanged."
      );
    }

    // Consume OTP.
    owned.set("adapter_status", _ST_CONSUMED);
    owned.set("is_used", true);
    txApp.save(owned);

    // Verify caller is an ordinary user (safety check).
    var user = txApp.findRecordById("users", callerId);
    var targetRole = user.getString("role");
    if (targetRole === "admin" || targetRole === "superadmin") {
      throw new ForbiddenError(
        "Admin/superadmin accounts cannot be made eligible for phone authentication."
      );
    }

    // Atomically write phone and phone_verified.
    user.set("phone", phone);
    user.set("phone_verified", true);
    txApp.save(user);

    outcome.action = "verified";
  });

  // Process outcome AFTER TX exits.
  if (outcome.action === "verified") {
    return e.json(200, { verified: true });
  }
  if (outcome.action === "expired") {
    throw new BadRequestError(outcome.reason);
  }
  if (outcome.action === "forbidden") {
    throw new ForbiddenError(outcome.reason);
  }
  if (outcome.action === "none" || outcome.action === "mismatch") {
    throw new BadRequestError(outcome.reason || "OTP verification failed.");
  }
  // Fallthrough: should not reach here.
  throw new InternalServerError("Unexpected outcome from TX-3: " + outcome.action);
});
