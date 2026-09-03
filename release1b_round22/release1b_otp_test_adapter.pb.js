// ============================================================
// release1b_otp_test_adapter.pb.js — Round 22
// LOCAL ISOLATED TEST ADAPTER — NEVER DEPLOY TO PRODUCTION
// ============================================================
//
// SCHEMA DEPENDENCIES (all added via 9999999999_r22_future_schema.js):
//   users.phone_verified   bool
//   phone_otps.adapter_status  select: pending_send, sent_active,
//                              send_failed, consumed
//
// PRODUCTION FIELDS USED:
//   phone_otps: phone (candidate), code, expires_at, is_used (bool)
//   users: phone (text), phone_verified (bool, future)
//
// TRANSACTION DESIGN:
//   TX-1 (request):  create pending_send record atomically
//   (outside TX):    call local deterministic provider fixture
//   TX-2 (request):  transition pending → sent_active | send_failed
//   TX-3 (verify):   consume OTP + set users.phone + set phone_verified
//   All three use $app.runInTransaction(); failures roll back completely.
//
// AUTH CONTRACT:
//   /api/auth/request-whatsapp-otp  — ordinary user token required
//   /api/auth/verify-whatsapp-otp   — same token; caller = linked user
//   /api/test/otp-control           — NSU only
//   /api/test/otp-rate-count        — NSU only
//
// SAFETY:
//   - Loopback-only (correct IPv6 bracket parsing).
//   - Synthetic phone pattern +601_R22TEST_<4-16 digits> only.
//   - Never contacts Meta or any external service.
//   - Never logs phone numbers, OTP codes, or user identifiers.
// ============================================================

"use strict";

// ── In-process supplementary state ───────────────────────────
var _adapterState = {
  mode:    "success",
  epochId: 0,
};

var _MODES = [
  "success", "send_failed", "pending_send",
  "db_fail_request",      // TX-2 rolls back; pending cleaned to send_failed
  "db_fail_verify",       // TX-3 rolls back; OTP stays active (retryable)
  "pending_create_fail",  // TX-1 rolls back; no OTP record created
];

var _ST_PENDING  = "pending_send";
var _ST_ACTIVE   = "sent_active";
var _ST_FAILED   = "send_failed";
var _ST_CONSUMED = "consumed";

// Synthetic phone: +601_R22TEST_<4-16 decimal digits>
var _SYNTH_RE = /^\+601_R22TEST_\d{4,16}$/;

var _OTP_LEN = 6;
var _TTL_MS  = 300000; // 5 minutes

// ── Loopback enforcement (correct IPv6 bracket parsing) ──────
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
      "Admin and superadmin accounts cannot use the phone-linking flow. " +
      "Administrators may not make themselves eligible for phone authentication via this path."
    );
  }
}

// ── NSU enforcement ──────────────────────────────────────────
function _requireNSU(e) {
  if (!e.auth) throw new UnauthorizedError("NSU token required.");
  try {
    if (e.auth.collection().name !== "_superusers") {
      throw new ForbiddenError("NSU (_superusers) token required.");
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
      "OTP adapter: only R22 synthetic identifiers accepted (+601_R22TEST_<4-16 digits>). " +
      "Real phone numbers are always rejected."
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
  if (mode === "pending_send")         return { pending: true };
  if (mode === "send_failed")          return { success: false };
  if (mode === "db_fail_request")      return { success: true, dbFail: true };
  return { success: true };           // success / db_fail_verify / pending_create_fail: provider succeeds
}

// ── Invalidate prior sent_active OTPs within a transaction ───
function _invalidatePriorActive(txApp, candidatePhone) {
  var prior = txApp.findRecordsByFilter(
    "phone_otps",
    "phone = {:p} && adapter_status = {:s}",
    "", 100, 0, { p: candidatePhone, s: _ST_ACTIVE }
  );
  for (var i = 0; i < prior.length; i++) {
    prior[i].set("adapter_status", _ST_FAILED);
    prior[i].set("is_used", true);
    txApp.save(prior[i]);
  }
}

// ════════════════════════════════════════════════════════════
// POST /api/test/otp-control  (NSU only)
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
// GET /api/test/otp-rate-count  (NSU only)
// Returns supplementary state. Authoritative count from phone_otps DB.
// ════════════════════════════════════════════════════════════
routerAdd("GET", "/api/test/otp-rate-count", function(e) {
  _requireLoopback(e);
  _requireNSU(e);
  return e.json(200, {
    epochId: _adapterState.epochId,
    note: "Authoritative attempt count: query phone_otps collection via NSU.",
  });
});

// ════════════════════════════════════════════════════════════
// POST /api/auth/request-whatsapp-otp
// Auth: ordinary user token required.
// Body: { "phone": "+601_R22TEST_XXXX" }
//
// TX-1: atomically create pending_send record.
// (outside TX): call local provider fixture.
// TX-2: transition pending → sent_active | send_failed.
//   db_fail_request: TX-2 throws → rolls back → pending_send record
//     remains → cleaned to send_failed in separate operation.
//   pending_create_fail: TX-1 throws → no record created.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/request-whatsapp-otp", function(e) {
  _requireLoopback(e);
  _requireOrdinaryUser(e);

  var body  = e.requestInfo().body;
  var phone = String(body.phone || "").trim();
  _requireSynthPhone(phone);

  var currentMode = _adapterState.mode;

  // TX-1: create pending_send record.
  var otpRecId;
  if (currentMode === "pending_create_fail") {
    // Simulate first-transaction failure.
    $app.runInTransaction(function(txApp) {
      // Create record to prove TX started, then throw.
      var col = txApp.findCollectionByNameOrId("phone_otps");
      var rec = new Record(col);
      rec.set("phone", phone);
      rec.set("code", "");
      rec.set("is_used", false);
      rec.set("adapter_status", _ST_PENDING);
      rec.set("expires_at", _expiryISO(_TTL_MS));
      txApp.save(rec);
      // Throw → entire TX rolls back → no record persisted.
      throw new Error("pending_create_fail: simulated TX-1 failure.");
    });
    // unreachable if throw propagates; but for clarity:
    throw new BadRequestError("Pending record creation failed (pending_create_fail mode). No OTP created.");
  }

  $app.runInTransaction(function(txApp) {
    var col = txApp.findCollectionByNameOrId("phone_otps");
    var rec = new Record(col);
    rec.set("phone", phone);
    rec.set("code", "");
    rec.set("is_used", false);
    rec.set("adapter_status", _ST_PENDING);
    rec.set("expires_at", _expiryISO(_TTL_MS));
    txApp.save(rec);
    otpRecId = rec.id;
  });

  // Outside TX: call local deterministic provider.
  var provResult = _localProvider(currentMode);

  if (provResult.pending) {
    // Leave as pending_send.
    return e.json(200, { status: "pending" });
  }

  // TX-2: transition the pending record.
  var activationStatus = "unknown";

  if (provResult.dbFail) {
    // Simulate TX-2 failure: throw inside transaction → rolls back.
    try {
      $app.runInTransaction(function(txApp) {
        var rec = txApp.findRecordById("phone_otps", otpRecId);
        if (rec.getString("adapter_status") !== _ST_PENDING) {
          throw new Error("OTP not in pending_send state");
        }
        throw new Error("db_fail_request: simulated TX-2 activation failure.");
      });
    } catch (_) {}
    // TX-2 rolled back; record is still pending_send. Clean up in separate save.
    try {
      var pendingRec = $app.findRecordById("phone_otps", otpRecId);
      if (pendingRec.getString("adapter_status") === _ST_PENDING) {
        pendingRec.set("adapter_status", _ST_FAILED);
        $app.save(pendingRec);
      }
    } catch (_) {}
    activationStatus = "db_fail";
  } else if (!provResult.success) {
    // Provider failure: set send_failed within TX-2 (no throw, so TX commits).
    $app.runInTransaction(function(txApp) {
      var rec = txApp.findRecordById("phone_otps", otpRecId);
      rec.set("adapter_status", _ST_FAILED);
      txApp.save(rec);
    });
    activationStatus = "send_failed";
  } else {
    // Provider success: invalidate prior active OTPs and activate this one.
    $app.runInTransaction(function(txApp) {
      var rec = txApp.findRecordById("phone_otps", otpRecId);
      if (rec.getString("adapter_status") !== _ST_PENDING) {
        throw new Error("Concurrent modification: OTP no longer pending.");
      }
      _invalidatePriorActive(txApp, phone);
      var code = _generateCode(_OTP_LEN);
      rec.set("adapter_status", _ST_ACTIVE);
      rec.set("code", code);
      txApp.save(rec);
    });
    activationStatus = "sent_active";
  }

  if (activationStatus === "db_fail") {
    throw new BadRequestError(
      "OTP activation failed (db_fail_request mode): TX-2 rolled back. " +
      "Record cleaned to send_failed. No active OTP created."
    );
  }
  if (activationStatus === "send_failed") {
    throw new BadRequestError("OTP delivery failed (send_failed mode). No active OTP created.");
  }
  return e.json(200, { status: "sent" });
});

// ════════════════════════════════════════════════════════════
// POST /api/auth/verify-whatsapp-otp
// Auth: ordinary user token required (same user as the request).
// Body: { "phone": "+601_R22TEST_XXXX", "code": "XXXXXX" }
//
// TX-3: atomically:
//   1. Re-read and validate active OTP for the candidate phone.
//   2. Confirm code matches and is not expired.
//   3. Mark OTP consumed (adapter_status=consumed, is_used=true).
//   4. Confirm caller is an ordinary user (not admin/superadmin).
//   5. Write users.phone = candidatePhone AND phone_verified=true.
//   All within $app.runInTransaction(). Any throw → full rollback.
//   On rollback: OTP remains active (retryable). Phone unchanged.
//
// db_fail_verify mode: TX-3 throws before committing → full rollback.
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

  $app.runInTransaction(function(txApp) {
    // Step 1: find active OTPs for this candidate phone.
    var actives = txApp.findRecordsByFilter(
      "phone_otps",
      "phone = {:p} && adapter_status = {:s}",
      "", 20, 0, { p: phone, s: _ST_ACTIVE }
    );
    if (!actives || actives.length === 0) {
      throw new BadRequestError("No active OTP found for this phone.");
    }

    // Step 2: match code in application layer.
    var matched = null;
    for (var i = 0; i < actives.length; i++) {
      if (actives[i].getString("code") === code) { matched = actives[i]; break; }
    }
    if (!matched) throw new BadRequestError("OTP code does not match.");

    // Step 3: check expiry.
    var exp = new Date(matched.getString("expires_at"));
    if (exp < new Date()) {
      matched.set("adapter_status", _ST_FAILED);
      matched.set("is_used", true);
      txApp.save(matched);
      throw new BadRequestError("OTP expired. Commit sets it failed; request a new one.");
    }

    // Simulate db_fail_verify: throw before any writes commit.
    if (currentMode === "db_fail_verify") {
      throw new BadRequestError(
        "db_fail_verify: simulated TX-3 failure. " +
        "Transaction rolled back. OTP remains active and retryable. " +
        "users.phone and phone_verified unchanged."
      );
    }

    // Step 4: consume OTP.
    matched.set("adapter_status", _ST_CONSUMED);
    matched.set("is_used", true);
    txApp.save(matched);

    // Step 5: write phone and phone_verified for the caller.
    var user = txApp.findRecordById("users", callerId);
    var targetRole = user.getString("role");
    if (targetRole === "admin" || targetRole === "superadmin") {
      throw new ForbiddenError(
        "Admin/superadmin accounts cannot be made eligible for phone authentication."
      );
    }
    user.set("phone", phone);
    user.set("phone_verified", true);
    txApp.save(user);
    // All three saves committed atomically on TX return.
  });

  return e.json(200, { verified: true });
});
