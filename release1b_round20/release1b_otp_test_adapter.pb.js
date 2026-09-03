// ============================================================
// release1b_otp_test_adapter.pb.js
// LOCAL ISOLATED TEST ADAPTER — NEVER DEPLOY TO PRODUCTION
// ============================================================
//
// Purpose:
//   Provides deterministic WhatsApp OTP behaviour for the isolated
//   Checkpoint 0 harness environment. Replaces auth_whatsapp_otp.pb.js
//   in the isolated hooks directory ONLY. The source project hook is
//   NEVER modified. This file must NOT be copied to pb_hooks/ in any
//   deployed environment.
//
// Safety constraints:
//   - Rejects all non-loopback connections (127.0.0.1, ::1 only).
//   - Never calls Meta, any WhatsApp API, or any external service.
//   - Accepts only synthetic phone identifiers matching a strict pattern.
//   - Never logs phone numbers or OTP codes.
//   - Rate-limit counter records attempts only (no phone or OTP stored
//     in the counter).
//   - Deterministic: mode is set via a control endpoint; state is
//     in-process (ephemeral, resets on PocketBase restart).
//
// Routes provided:
//   POST /api/test/otp-control      NSU only — set delivery mode
//   GET  /api/test/otp-rate-count   NSU only — read attempt counter
//   POST /api/auth/request-whatsapp-otp
//   POST /api/auth/verify-whatsapp-otp
//
// Delivery modes:
//   "success"      Write sent/active record. Verifiable via NSU read.
//   "send_failed"  Write send_failed record. Not verifiable.
//   "pending_send" Write pending_send record. Not verifiable.
//
// Synthetic phone format: +601_R20TEST_<4-16 decimal digits>
//   Example: +601_R20TEST_00012345
//   These cannot be real Malaysian phone numbers (test prefix).
//
// Concurrency note:
//   PocketBase JSVM (Goja) executes hook JS single-threaded per
//   request. Race conditions between concurrent OTP requests are
//   naturally serialized at the JS level. Database operations are
//   committed between requests, so the rate counter and status
//   transitions are deterministic for sequential test cases.
//
// ============================================================

"use strict";

// ── In-memory test state (ephemeral; resets on PocketBase restart) ──
const _adapterState = {
  mode:         "success",   // "success" | "send_failed" | "pending_send"
  attemptCount: 0,           // incremented on each request-whatsapp-otp call
  epochId:      0,           // incremented on each mode change
};

// Synthetic phone pattern — matches only clearly non-routable test identifiers.
// +601_R20TEST_ followed by 4–16 decimal digits.
const _SYNTH_PHONE_RE = /^\+601_R20TEST_\d{4,16}$/;

// OTP status values as stored in phone_otps.status select field.
const _STATUS_ACTIVE   = "sent/active";
const _STATUS_FAILED   = "send_failed";
const _STATUS_PENDING  = "pending_send";

// OTP code length.
const _OTP_DIGITS = 6;

// OTP validity window (milliseconds).
const _OTP_TTL_MS = 300000;  // 5 minutes

// ── Helper: reject non-loopback connections ──────────────────────────
function _requireLoopback(e) {
  const raw  = (e.request ? e.request.remoteAddr : "") || "";
  const host = raw.split(":")[0].replace(/^\[/, "").replace(/\]$/, "");
  if (host !== "127.0.0.1" && host !== "::1" && host !== "0:0:0:0:0:0:0:1") {
    throw new ForbiddenError(
      "OTP test adapter: connection from non-loopback address rejected. " +
      "This adapter is for isolated test use only."
    );
  }
}

// ── Helper: require native superuser auth ───────────────────────────
// For routerAdd handlers in PocketBase v0.28.x–v0.29.x, e.auth is
// populated when a valid token is supplied. Native superusers have
// collection().name === "_superusers".
function _requireNSU(e) {
  const auth = e.auth;
  if (!auth) {
    throw new UnauthorizedError("NSU token required for OTP adapter control routes.");
  }
  try {
    if (auth.collection().name !== "_superusers") {
      throw new ForbiddenError("NSU (_superusers) token required.");
    }
  } catch (innerErr) {
    if (innerErr instanceof ForbiddenError || innerErr instanceof UnauthorizedError) {
      throw innerErr;
    }
    throw new UnauthorizedError("Unable to verify NSU token.");
  }
}

// ── Helper: generate a random numeric OTP code ──────────────────────
// Uses Math.random() which is adequate for ephemeral test codes.
// The code is NEVER logged and is only stored in the isolated database.
function _generateCode(length) {
  let code = "";
  for (let i = 0; i < length; i++) {
    code += String(Math.floor(Math.random() * 10));
  }
  return code;
}

// ── Helper: validate synthetic phone identifier ──────────────────────
function _requireSynthPhone(phone) {
  if (!phone || !_SYNTH_PHONE_RE.test(phone)) {
    throw new BadRequestError(
      "OTP test adapter: only synthetic phone identifiers are accepted. " +
      "Required format: +601_R20TEST_<4-16 digits>. " +
      "Real phone numbers, empty values, and non-matching formats are rejected. " +
      "This prevents accidental OTP delivery to real subscribers."
    );
  }
}

// ── Helper: compute ISO expiry timestamp ────────────────────────────
function _expiryISO(offsetMs) {
  return new Date(Date.now() + offsetMs).toISOString();
}

// ── Helper: write a phone_otps record ───────────────────────────────
// Never logs phone or code. Status is caller-supplied.
function _writeOtpRecord(phone, code, status, expiryISO) {
  const col = $app.findCollectionByNameOrId("phone_otps");
  const rec = new Record(col);
  rec.set("phone",      phone);
  rec.set("code",       code);
  rec.set("status",     status);
  rec.set("expires_at", expiryISO);
  $app.save(rec);
  return rec;
}

// ── Helper: invalidate previous active OTPs for synthetic phone ──────
function _invalidatePriorActive(phone) {
  const existing = $app.findRecordsByFilter(
    "phone_otps",
    "phone = {:p} && status = {:s}",
    "", 100, 0,
    { p: phone, s: _STATUS_ACTIVE }
  );
  for (let i = 0; i < existing.length; i++) {
    existing[i].set("status", _STATUS_FAILED);
    $app.save(existing[i]);
  }
}

// ════════════════════════════════════════════════════════════
// Control route: POST /api/test/otp-control  (NSU only)
// Body: { "mode": "success" | "send_failed" | "pending_send" }
// Response: { "mode": string, "epochId": number }
// Resets attemptCount on mode change.
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/test/otp-control", (e) => {
  _requireLoopback(e);
  _requireNSU(e);

  const body = e.requestInfo().body;
  const newMode = ((body.mode || "")).toLowerCase();

  if (newMode !== "success" && newMode !== "send_failed" && newMode !== "pending_send") {
    throw new BadRequestError(
      "mode must be exactly one of: success | send_failed | pending_send"
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
// Rate-count route: GET /api/test/otp-rate-count  (NSU only)
// Response: { "attemptCount": number, "epochId": number }
// Returns counter only; no phone numbers, no OTP values.
// ════════════════════════════════════════════════════════════
routerAdd("GET", "/api/test/otp-rate-count", (e) => {
  _requireLoopback(e);
  _requireNSU(e);

  return e.json(200, {
    attemptCount: _adapterState.attemptCount,
    epochId:      _adapterState.epochId,
  });
});

// ════════════════════════════════════════════════════════════
// Request OTP: POST /api/auth/request-whatsapp-otp
// Body: { "phone": "+601_R20TEST_XXXX" }
// Behaviour depends on _adapterState.mode:
//   success      → write sent/active record; return 200 {status:"sent"}
//   send_failed  → write send_failed record; return 400 (simulated Meta fail)
//   pending_send → write pending_send record; return 200 {status:"pending"}
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/request-whatsapp-otp", (e) => {
  _requireLoopback(e);

  const body  = e.requestInfo().body;
  const phone = ((body.phone || "")).toString().trim();

  _requireSynthPhone(phone);

  _adapterState.attemptCount = (_adapterState.attemptCount + 1) | 0;
  const currentMode = _adapterState.mode;

  if (currentMode === "pending_send") {
    _writeOtpRecord(phone, "", _STATUS_PENDING, _expiryISO(_OTP_TTL_MS));
    return e.json(200, { status: "pending" });
  }

  if (currentMode === "send_failed") {
    _writeOtpRecord(phone, "", _STATUS_FAILED, _expiryISO(60000));
    throw new BadRequestError(
      "OTP delivery simulated failure (adapter mode: send_failed). " +
      "No code was generated. No external service was contacted."
    );
  }

  // mode === "success"
  // Invalidate any previous active OTPs for this synthetic phone.
  _invalidatePriorActive(phone);

  const code = _generateCode(_OTP_DIGITS);
  _writeOtpRecord(phone, code, _STATUS_ACTIVE, _expiryISO(_OTP_TTL_MS));

  // Never return the code in the response. Harness reads it via NSU.
  return e.json(200, { status: "sent" });
});

// ════════════════════════════════════════════════════════════
// Verify OTP: POST /api/auth/verify-whatsapp-otp
// Body: { "phone": "+601_R20TEST_XXXX", "code": "XXXXXX" }
// Behaviour:
//   Look up phone_otps with status=sent/active and matching code.
//   If found and not expired: consume (→ send_failed), return 200.
//   If not found or expired: return 400.
// In test mode, no auth token is issued. The harness verifies
// only that verification succeeds (HTTP 200).
// ════════════════════════════════════════════════════════════
routerAdd("POST", "/api/auth/verify-whatsapp-otp", (e) => {
  _requireLoopback(e);

  const body  = e.requestInfo().body;
  const phone = ((body.phone || "")).toString().trim();
  const code  = ((body.code  || "")).toString().trim();

  _requireSynthPhone(phone);

  if (!code || !/^\d{6}$/.test(code)) {
    throw new BadRequestError("code must be exactly 6 decimal digits.");
  }

  // Find active OTP for this phone. Filter by phone and status only;
  // compare code in application layer to avoid leaking code in filter error messages.
  let records;
  try {
    records = $app.findRecordsByFilter(
      "phone_otps",
      "phone = {:p} && status = {:s}",
      "", 10, 0,
      { p: phone, s: _STATUS_ACTIVE }
    );
  } catch (_) {
    records = [];
  }

  // Find matching code among active records.
  let matched = null;
  for (let i = 0; i < records.length; i++) {
    if (records[i].getString("code") === code) {
      matched = records[i];
      break;
    }
  }

  if (!matched) {
    throw new BadRequestError("OTP not found, already used, or expired.");
  }

  // Check expiry.
  const expiresAt = new Date(matched.getString("expires_at"));
  if (expiresAt < new Date()) {
    matched.set("status", _STATUS_FAILED);
    $app.save(matched);
    throw new BadRequestError("OTP has expired.");
  }

  // Consume: transition to send_failed (used).
  matched.set("status", _STATUS_FAILED);
  $app.save(matched);

  // Return success. No auth token in test mode.
  return e.json(200, { verified: true });
});
