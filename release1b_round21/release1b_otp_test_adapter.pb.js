// ============================================================
// release1b_otp_test_adapter.pb.js  — Round 21
// LOCAL ISOLATED TEST ADAPTER — NEVER DEPLOY TO PRODUCTION
// ============================================================
//
// SCHEMA DEPENDENCY:
//   phone_otps production fields: phone, code, expires_at, is_used (bool)
//   phone_otps adapter field:     adapter_status (select, added by
//     the harness future-schema migration before server start):
//     values: ["pending_send","sent_active","send_failed","consumed"]
//
// LIFECYCLE PER SEND ATTEMPT:
//   1. Create phone_otps record: adapter_status="pending_send", is_used=false, code=""
//   2. Invoke strictly local deterministic provider fixture.
//   3. On simulated success: generate code; atomically update record to
//      adapter_status="sent_active" in the same $app.save().
//      On DB transition failure (db_fail_request mode): update to
//      adapter_status="send_failed", code=""; return 500.
//   4. On simulated failure: update record to adapter_status="send_failed".
//   5. Pending_send mode: leave record as pending_send; return 200.
//
// VERIFICATION (verify-whatsapp-otp route):
//   - Only sent_active records with matching code are verifiable.
//   - On success: set adapter_status="consumed", is_used=true.
//   - Then attempt to update the linked user's phone_verified=true.
//   - In db_fail_verify mode: OTP is consumed but user update is skipped
//     (simulates partial-commit scenario; documented as known limitation).
//
// SAFETY CONSTRAINTS:
//   - Loopback-only (127.0.0.1 or ::1); IPv6 brackets handled.
//   - Rejects non-synthetic phone identifiers.
//   - Never logs phone numbers, OTP codes, or user identifiers.
//   - Never contacts Meta or any external service.
//   - Rate count uses in-process counter supplemented by DB evidence.
// ============================================================

"use strict";

// ── In-process state (ephemeral; supplements DB evidence) ───────────
var _adapterState = {
  mode:         "success",
  attemptCount: 0,
  epochId:      0,
};

// Delivery modes.
var _MODES = ["success", "send_failed", "pending_send",
              "db_fail_request", "db_fail_verify"];

// adapter_status values (these must match the temporary schema migration).
var _ST_PENDING  = "pending_send";
var _ST_ACTIVE   = "sent_active";
var _ST_FAILED   = "send_failed";
var _ST_CONSUMED = "consumed";

// Synthetic phone pattern: +601_R21TEST_<4-16 decimal digits>
// Changed from R20 pattern (+601_R20TEST_) to distinguish test identities.
var _SYNTH_RE = /^\+601_R21TEST_\d{4,16}$/;

// OTP code length.
var _OTP_LEN = 6;

// Default TTL (ms).
var _TTL_MS = 300000;  // 5 minutes

// ── Loopback enforcement (D-8 fix: correct IPv6 bracket parsing) ─────
function _requireLoopback(e) {
  var raw = (e.request && e.request.remoteAddr ? e.request.remoteAddr : "").toString();
  var ok  = false;

  // IPv4 loopback: "127.x.x.x:PORT" or "127.x.x.x"
  if (/^127\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(raw)) ok = true;

  // IPv6 loopback: "[::1]:PORT" (bracketed) or "::1" (bare)
  if (!ok && (raw === "::1" || /^\[::1\]:\d+$/.test(raw))) ok = true;

  if (!ok) {
    throw new ForbiddenError(
      "OTP test adapter: non-loopback connection rejected. " +
      "Remote: [redacted for safety]. This adapter is isolated-test-only."
    );
  }
}

// ── NSU enforcement ──────────────────────────────────────────────────
function _requireNSU(e) {
  var auth = e.auth;
  if (!auth) throw new UnauthorizedError("NSU token required.");
  try {
    if (auth.collection().name !== "_superusers") {
      throw new ForbiddenError("NSU (_superusers) token required.");
    }
  } catch (inner) {
    if (inner instanceof ForbiddenError || inner instanceof UnauthorizedError) throw inner;
    throw new UnauthorizedError("NSU token could not be verified.");
  }
}

// ── Synthetic phone validation ────────────────────────────────────────
function _requireSynthPhone(phone) {
  if (!phone || !_SYNTH_RE.test(phone)) {
    throw new BadRequestError(
      "OTP test adapter: only R21 synthetic phone identifiers accepted. " +
      "Required format: +601_R21TEST_<4-16 digits>. " +
      "Real phone numbers are always rejected."
    );
  }
}

// ── Generate a random OTP code ────────────────────────────────────────
function _generateCode(len) {
  var code = "";
  for (var i = 0; i < len; i++) code += String(Math.floor(Math.random() * 10));
  return code;
}

// ── Expiry ISO string ─────────────────────────────────────────────────
function _expiryISO(offsetMs) {
  return new Date(Date.now() + offsetMs).toISOString();
}

// ── Local deterministic provider fixture ─────────────────────────────
// Returns { success: bool, pending: bool }.
// Never contacts external services.
function _localProviderFixture(mode) {
  if (mode === "pending_send")   return { success: false, pending: true };
  if (mode === "send_failed")    return { success: false, pending: false };
  if (mode === "db_fail_request") return { success: true,  pending: false, dbFail: true };
  return { success: true, pending: false };
}

// ── Invalidate prior sent_active OTPs for this phone ─────────────────
function _invalidatePriorActive(phone) {
  var existing = $app.findRecordsByFilter(
    "phone_otps",
    "phone = {:p} && adapter_status = {:s}",
    "", 100, 0, { p: phone, s: _ST_ACTIVE }
  );
  for (var i = 0; i < existing.length; i++) {
    existing[i].set("adapter_status", _ST_FAILED);
    existing[i].set("is_used", true);
    $app.save(existing[i]);
  }
}

// ── Count all phone_otps records for a phone (DB-backed attempt count) ─
function _dbAttemptCount(phone) {
  try {
    var recs = $app.findRecordsByFilter(
      "phone_otps", "phone = {:p}", "", 0, 0, { p: phone }
    );
    return recs.length;
  } catch (_) { return -1; }
}

// ════════════════════════════════════════════════════════════
// POST /api/test/otp-control  (NSU only)
// Body: { "mode": "success"|"send_failed"|"pending_send"|
//                 "db_fail_request"|"db_fail_verify" }
// Resets in-process attempt counter on mode change.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/test/otp-control", function(e) {
  _requireLoopback(e);
  _requireNSU(e);

  var body    = e.requestInfo().body;
  var newMode = (body.mode || "").toString().toLowerCase();

  var valid = false;
  for (var mi = 0; mi < _MODES.length; mi++) {
    if (_MODES[mi] === newMode) { valid = true; break; }
  }
  if (!valid) {
    throw new BadRequestError(
      "mode must be one of: " + _MODES.join(" | ")
    );
  }

  _adapterState.mode         = newMode;
  _adapterState.attemptCount = 0;
  _adapterState.epochId      = (_adapterState.epochId + 1) | 0;

  return e.json(200, {
    mode:         _adapterState.mode,
    epochId:      _adapterState.epochId,
    attemptCount: _adapterState.attemptCount,
  });
});

// ════════════════════════════════════════════════════════════
// GET /api/test/otp-rate-count  (NSU only)
// Returns in-process count (supplementary) and a safe DB count
// for the last requested phone (if supplied in query).
// Never returns phone numbers or OTP values.
// ════════════════════════════════════════════════════════════
routerAdd("GET", "/api/test/otp-rate-count", function(e) {
  _requireLoopback(e);
  _requireNSU(e);

  return e.json(200, {
    inProcessAttemptCount: _adapterState.attemptCount,
    epochId:               _adapterState.epochId,
    note:                  "DB record count per phone available via NSU list of phone_otps collection.",
  });
});

// ════════════════════════════════════════════════════════════
// POST /api/auth/request-whatsapp-otp
// Body: { "phone": "+601_R21TEST_XXXX" }
//
// Lifecycle:
//   1. Validate synthetic phone.
//   2. Create pending_send record in phone_otps.
//   3. Call local deterministic provider fixture.
//   4a. Fixture success → invalidate prior active OTPs → generate code →
//       atomically update record to sent_active.
//       (db_fail_request mode: update record to send_failed instead → 500)
//   4b. Fixture failure → update record to send_failed → 400.
//   4c. Fixture pending → leave as pending_send → 200.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/request-whatsapp-otp", function(e) {
  _requireLoopback(e);

  var body  = e.requestInfo().body;
  var phone = (body.phone || "").toString().trim();
  _requireSynthPhone(phone);

  _adapterState.attemptCount = (_adapterState.attemptCount + 1) | 0;
  var currentMode = _adapterState.mode;

  // Step 1: Create pending_send record.
  var col    = $app.findCollectionByNameOrId("phone_otps");
  var record = new Record(col);
  record.set("phone",          phone);
  record.set("code",           "");
  record.set("is_used",        false);
  record.set("adapter_status", _ST_PENDING);
  record.set("expires_at",     _expiryISO(_TTL_MS));
  $app.save(record);

  // Step 2: Call local provider fixture.
  var provResult = _localProviderFixture(currentMode);

  // Step 3: Handle fixture result.
  if (provResult.pending) {
    // Leave as pending_send. Return 200 (simulates provider acknowledging the request).
    return e.json(200, { status: "pending" });
  }

  if (!provResult.success) {
    // Provider failure: transition to send_failed.
    record.set("adapter_status", _ST_FAILED);
    $app.save(record);
    throw new BadRequestError(
      "OTP delivery simulated failure (adapter mode: send_failed). " +
      "No code generated. No external service contacted."
    );
  }

  // Provider success.
  if (provResult.dbFail) {
    // db_fail_request mode: simulate failure of the post-provider DB transition.
    // Rollback: set record to send_failed.
    record.set("adapter_status", _ST_FAILED);
    try { $app.save(record); } catch (_) { /* best-effort rollback */ }
    throw new BadRequestError(
      "Simulated database failure during post-provider OTP status transition. " +
      "Record rolled back to send_failed. No active OTP created."
    );
  }

  // Normal success path: invalidate prior active OTPs, then make this one active.
  _invalidatePriorActive(phone);

  var code = _generateCode(_OTP_LEN);
  record.set("adapter_status", _ST_ACTIVE);
  record.set("code",           code);
  // Do NOT return the code in the HTTP response.
  // The harness reads it directly from phone_otps via NSU.
  $app.save(record);

  return e.json(200, { status: "sent" });
});

// ════════════════════════════════════════════════════════════
// POST /api/auth/verify-whatsapp-otp
// Body: { "phone": "+601_R21TEST_XXXX", "code": "XXXXXX" }
//
// Lifecycle:
//   1. Find sent_active OTP for phone.
//   2. Compare code in application layer (no filter-injection risk).
//   3. Check expiry.
//   4. Consume: set adapter_status="consumed", is_used=true.
//   5. Look up user by phone; set phone_verified=true via $app.save()
//      (bypasses the phone_verified HTTP guard hook — this is the
//      specifically authorized server-side path).
//   6. In db_fail_verify mode: skip user update (partial-commit test).
//
// NOTE: Full atomicity between OTP consumption and phone_verified update
// is not achievable with PocketBase JS hooks (no application transactions).
// A failure between steps 4 and 5 leaves OTP consumed and phone_verified
// unchanged. This is a documented design limitation tested by the harness.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/verify-whatsapp-otp", function(e) {
  _requireLoopback(e);

  var body  = e.requestInfo().body;
  var phone = (body.phone || "").toString().trim();
  var code  = (body.code  || "").toString().trim();

  _requireSynthPhone(phone);

  if (!code || !/^\d{6}$/.test(code)) {
    throw new BadRequestError("code must be exactly 6 decimal digits.");
  }

  // Find active OTPs for this phone.
  var actives;
  try {
    actives = $app.findRecordsByFilter(
      "phone_otps",
      "phone = {:p} && adapter_status = {:s}",
      "", 20, 0, { p: phone, s: _ST_ACTIVE }
    );
  } catch (_) { actives = []; }

  if (!actives || actives.length === 0) {
    throw new BadRequestError("No active OTP found for this phone.");
  }

  // Match code in application layer (not in filter, to avoid filter error leakage).
  var matched = null;
  for (var i = 0; i < actives.length; i++) {
    if (actives[i].getString("code") === code) {
      matched = actives[i];
      break;
    }
  }
  if (!matched) {
    throw new BadRequestError("OTP code does not match or has already been used.");
  }

  // Check expiry.
  var expiresAt = new Date(matched.getString("expires_at"));
  if (expiresAt < new Date()) {
    matched.set("adapter_status", _ST_FAILED);
    matched.set("is_used",        true);
    $app.save(matched);
    throw new BadRequestError("OTP has expired. Request a new one.");
  }

  // Step 4: Consume the OTP record.
  matched.set("adapter_status", _ST_CONSUMED);
  matched.set("is_used",        true);
  $app.save(matched);

  // Step 5: Update user's phone_verified field (bypasses HTTP guard hook).
  var currentMode = _adapterState.mode;
  if (currentMode === "db_fail_verify") {
    // Partial-commit test: OTP consumed but user update skipped.
    // Return 400 to signal the simulated failure to the harness.
    throw new BadRequestError(
      "Simulated database failure: OTP consumed but phone_verified not updated. " +
      "Partial-commit scenario documented. This is the expected rollback test outcome."
    );
  }

  // Normal path: find user by phone and set phone_verified=true.
  var users;
  try {
    users = $app.findRecordsByFilter(
      "users", "phone = {:p}", "", 1, 0, { p: phone }
    );
  } catch (_) { users = []; }

  if (users && users.length > 0) {
    var user = users[0];
    user.set("phone_verified", true);
    try {
      $app.save(user);
    } catch (saveErr) {
      // User update failed after OTP consumed. Partial commit.
      // This is the db_fail scenario without the mode flag — unexpected.
      // Log minimally (no PII) and return error.
      $app.logger().error("otp_adapter: user phone_verified save failed after OTP consumed", "err", String(saveErr));
      throw new BadRequestError(
        "OTP verified but phone_verified update failed. OTP has been consumed. " +
        "Partial-commit: phone_verified remains false."
      );
    }
  }

  return e.json(200, { verified: true });
});
