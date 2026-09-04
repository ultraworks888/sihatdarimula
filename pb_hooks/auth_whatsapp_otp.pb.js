/**
 * Authenticated WhatsApp OTP phone verification — Sihat Dari Mula
 *
 * Both routes require a users-collection PocketBase session. The caller is
 * always derived from e.auth; no client-supplied user identifier is accepted.
 *
 * POST /api/auth/request-whatsapp-otp
 *   Body: { phone: "+601XXXXXXXXX" }
 *
 * POST /api/auth/verify-whatsapp-otp
 *   Body: { phone: "+601XXXXXXXXX", code: "123456" }
 *
 * OTPs are generated with PocketBase's crypto/rand-backed $security helper and
 * persisted only as a salted SHA-256 digest. The Meta request is deliberately
 * outside database transactions.
 */

"use strict";

var _WA_OTP_LENGTH = 6;
var _WA_OTP_TTL_MS = 10 * 60 * 1000;
var _WA_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
var _WA_OTP_SENDS_PER_HOUR = 5;
var _WA_OTP_SENDS_PER_DAY = 10;
var _WA_OTP_MAX_FAILURES_PER_CODE = 5;
var _WA_OTP_MAX_FAILURES_PER_HOUR = 10;

var _WA_OTP_STATUS_PENDING = "pending";
var _WA_OTP_STATUS_ACTIVE = "active";
var _WA_OTP_STATUS_FAILED = "failed";
var _WA_OTP_STATUS_INVALIDATED = "invalidated";
var _WA_OTP_STATUS_EXPIRED = "expired";
var _WA_OTP_STATUS_LOCKED = "locked";
var _WA_OTP_STATUS_USED = "used";

function _waOtpDate(value) {
  return new Date(value).toISOString().replace("T", " ");
}

function _waOtpNormalizeMalaysianPhone(value) {
  var phone = String(value || "").trim().replace(/[\s().-]/g, "");

  if (/^01\d{8,9}$/.test(phone)) {
    phone = "+6" + phone;
  } else if (/^601\d{8,9}$/.test(phone)) {
    phone = "+" + phone;
  }

  if (!/^\+601\d{8,9}$/.test(phone)) return "";
  return phone;
}

function _waOtpAuthenticatedUser(e) {
  if (!e.auth) return null;

  try {
    if (e.auth.collection().name !== "users") return null;
    return $app.findRecordById("users", e.auth.id);
  } catch (_) {
    return null;
  }
}

function _waOtpSetting(key) {
  try {
    return $app.findFirstRecordByFilter(
      "lms_settings",
      "key = {:key}",
      { key: key }
    ).getString("value");
  } catch (_) {
    return "";
  }
}

function _waOtpHash(code, salt) {
  return $security.sha256(salt + ":" + code);
}

function _waOtpRecords(app, filter, sort, limit, params) {
  return app.findRecordsByFilter(
    "phone_verification_otps",
    filter,
    sort || "",
    limit || 0,
    0,
    params || {}
  );
}

function _waOtpAtLimit(app, filter, params, limit) {
  return _waOtpRecords(app, filter, "-created", limit, params).length >= limit;
}

function _waOtpInvalidateOpenRecords(app, userId, phone) {
  var records = _waOtpRecords(
    app,
    "(user = {:user} || phone = {:phone}) && is_used = false",
    "",
    100,
    { user: userId, phone: phone }
  );

  for (var i = 0; i < records.length; i++) {
    records[i].set("is_used", true);
    records[i].set("status", _WA_OTP_STATUS_INVALIDATED);
    app.save(records[i]);
  }
}

function _waOtpMarkDeliveryFailed(recordId) {
  try {
    $app.runInTransaction(function(txApp) {
      var record = txApp.findRecordById("phone_verification_otps", recordId);
      if (record.getString("status") === _WA_OTP_STATUS_PENDING) {
        record.set("status", _WA_OTP_STATUS_FAILED);
        record.set("is_used", true);
        txApp.save(record);
      }
    });
  } catch (_) {
    $app.logger().error("WhatsApp OTP delivery cleanup failed");
  }
}

function _waOtpFailureCount(app, userId, phone, cutoff) {
  var records = _waOtpRecords(
    app,
    "user = {:user} && phone = {:phone} && created >= {:cutoff}",
    "-created",
    100,
    { user: userId, phone: phone, cutoff: cutoff }
  );
  var count = 0;

  for (var i = 0; i < records.length; i++) {
    count += records[i].getInt("failed_attempts");
  }
  return count;
}

routerAdd("POST", "/api/auth/request-whatsapp-otp", function(e) {
  var user = _waOtpAuthenticatedUser(e);
  if (!user) {
    return e.json(401, {
      error: "authentication_required",
      message: "Authentication is required. Please sign in again."
    });
  }

  var body = e.requestInfo().body;
  var phone = _waOtpNormalizeMalaysianPhone(body.phone);
  if (!phone) {
    return e.json(400, {
      error: "invalid_phone",
      message: "Enter a valid Malaysian mobile number."
    });
  }

  var phoneId = _waOtpSetting("whatsapp_phone_number_id");
  var token = _waOtpSetting("whatsapp_access_token");
  var version = _waOtpSetting("whatsapp_api_version") || "v20.0";
  if (!phoneId || !token) {
    return e.json(503, {
      error: "service_unavailable",
      message: "WhatsApp verification is temporarily unavailable. Please try again later."
    });
  }

  var userId = user.id;
  var now = Date.now();
  var minuteCutoff = _waOtpDate(now - _WA_OTP_RESEND_COOLDOWN_MS);
  var hourCutoff = _waOtpDate(now - 60 * 60 * 1000);
  var dayCutoff = _waOtpDate(now - 24 * 60 * 60 * 1000);
  var code = $security.randomStringWithAlphabet(_WA_OTP_LENGTH, "0123456789");
  var salt = $security.randomString(32);
  var hash = _waOtpHash(code, salt);
  var expiresAt = _waOtpDate(now + _WA_OTP_TTL_MS);
  var recordId = "";
  var throttled = false;

  try {
    $app.runInTransaction(function(txApp) {
      var recentPairFilter = "user = {:user} && phone = {:phone} && created >= {:cutoff}";

      if (_waOtpAtLimit(txApp, recentPairFilter, {
        user: userId,
        phone: phone,
        cutoff: minuteCutoff
      }, 1) ||
        _waOtpAtLimit(txApp, "user = {:user} && created >= {:cutoff}", {
          user: userId,
          cutoff: hourCutoff
        }, _WA_OTP_SENDS_PER_HOUR) ||
        _waOtpAtLimit(txApp, "phone = {:phone} && created >= {:cutoff}", {
          phone: phone,
          cutoff: hourCutoff
        }, _WA_OTP_SENDS_PER_HOUR) ||
        _waOtpAtLimit(txApp, "user = {:user} && created >= {:cutoff}", {
          user: userId,
          cutoff: dayCutoff
        }, _WA_OTP_SENDS_PER_DAY) ||
        _waOtpAtLimit(txApp, "phone = {:phone} && created >= {:cutoff}", {
          phone: phone,
          cutoff: dayCutoff
        }, _WA_OTP_SENDS_PER_DAY)) {
        throttled = true;
        return;
      }

      _waOtpInvalidateOpenRecords(txApp, userId, phone);

      var collection = txApp.findCollectionByNameOrId("phone_verification_otps");
      var record = new Record(collection);
      record.set("user", userId);
      record.set("phone", phone);
      record.set("otp_hash", hash);
      record.set("otp_salt", salt);
      record.set("expires_at", expiresAt);
      record.set("failed_attempts", 0);
      record.set("status", _WA_OTP_STATUS_PENDING);
      record.set("is_used", false);
      txApp.save(record);
      recordId = record.id;
    });
  } catch (_) {
    $app.logger().error("WhatsApp OTP request transaction failed");
    return e.json(500, {
      error: "verification_unavailable",
      message: "Phone verification is temporarily unavailable. Please try again."
    });
  }

  if (throttled) {
    return e.json(429, {
      error: "too_many_requests",
      message: "Too many verification requests. Please wait before trying again."
    });
  }

  var payload = {
    messaging_product: "whatsapp",
    to: phone.slice(1),
    type: "template",
    template: {
      name: "sdm_otp_verify",
      language: { code: "en_US" },
      components: [
        {
          type: "body",
          parameters: [
            { type: "text", text: code },
            { type: "text", text: code }
          ]
        },
        {
          type: "button",
          sub_type: "url",
          index: 0,
          parameters: [{ type: "text", text: code }]
        }
      ]
    }
  };

  var response;
  try {
    response = $http.send({
      url: "https://graph.facebook.com/" + version + "/" + phoneId + "/messages",
      method: "POST",
      headers: {
        "Authorization": "Bearer " + token,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload),
      timeout: 15
    });
  } catch (_) {
    _waOtpMarkDeliveryFailed(recordId);
    $app.logger().warn("WhatsApp OTP delivery request failed");
    return e.json(503, {
      error: "delivery_unavailable",
      message: "The verification code could not be sent. Please try again later."
    });
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    _waOtpMarkDeliveryFailed(recordId);
    $app.logger().warn("WhatsApp OTP provider rejected delivery", "status", response.statusCode);
    return e.json(503, {
      error: "delivery_unavailable",
      message: "The verification code could not be sent. Please try again later."
    });
  }

  try {
    $app.runInTransaction(function(txApp) {
      var record = txApp.findRecordById("phone_verification_otps", recordId);
      if (record.getString("status") !== _WA_OTP_STATUS_PENDING || record.getBool("is_used")) {
        throw new Error("OTP request is no longer pending");
      }
      record.set("status", _WA_OTP_STATUS_ACTIVE);
      txApp.save(record);
    });
  } catch (_) {
    _waOtpMarkDeliveryFailed(recordId);
    $app.logger().error("WhatsApp OTP activation failed after delivery");
    return e.json(503, {
      error: "delivery_unavailable",
      message: "The verification code could not be activated. Please request a new code."
    });
  }

  return e.json(200, {
    ok: true,
    message: "OTP sent to your WhatsApp number."
  });
});

routerAdd("POST", "/api/auth/verify-whatsapp-otp", function(e) {
  var user = _waOtpAuthenticatedUser(e);
  if (!user) {
    return e.json(401, {
      error: "authentication_required",
      message: "Authentication is required. Please sign in again."
    });
  }

  var body = e.requestInfo().body;
  var phone = _waOtpNormalizeMalaysianPhone(body.phone);
  var code = String(body.code || "").trim();
  if (!phone || !/^\d{6}$/.test(code)) {
    return e.json(400, {
      error: "verification_failed",
      message: "The verification code is invalid or expired. Please request a new code."
    });
  }

  var userId = user.id;
  var now = Date.now();
  var nowString = _waOtpDate(now);
  var hourCutoff = _waOtpDate(now - 60 * 60 * 1000);
  var outcome = "invalid";

  try {
    $app.runInTransaction(function(txApp) {
      var records = _waOtpRecords(
        txApp,
        "user = {:user} && phone = {:phone} && status = {:status} && is_used = false",
        "-created",
        1,
        { user: userId, phone: phone, status: _WA_OTP_STATUS_ACTIVE }
      );

      if (!records.length) return;

      var record = records[0];
      var failures = record.getInt("failed_attempts");
      var hourlyFailures = _waOtpFailureCount(txApp, userId, phone, hourCutoff);
      if (failures >= _WA_OTP_MAX_FAILURES_PER_CODE ||
          hourlyFailures >= _WA_OTP_MAX_FAILURES_PER_HOUR) {
        record.set("status", _WA_OTP_STATUS_LOCKED);
        record.set("is_used", true);
        txApp.save(record);
        outcome = "throttled";
        return;
      }

      var expiry = new Date(record.getString("expires_at").replace(" ", "T")).getTime();
      if (!isFinite(expiry) || now > expiry) {
        record.set("status", _WA_OTP_STATUS_EXPIRED);
        record.set("is_used", true);
        txApp.save(record);
        return;
      }

      var expectedHash = record.getString("otp_hash");
      var submittedHash = _waOtpHash(code, record.getString("otp_salt"));
      if (!expectedHash || !$security.equal(expectedHash, submittedHash)) {
        failures += 1;
        record.set("failed_attempts", failures);
        record.set("last_attempt_at", nowString);
        if (failures >= _WA_OTP_MAX_FAILURES_PER_CODE ||
            hourlyFailures + 1 >= _WA_OTP_MAX_FAILURES_PER_HOUR) {
          record.set("status", _WA_OTP_STATUS_LOCKED);
          record.set("is_used", true);
          outcome = "throttled";
        }
        txApp.save(record);
        return;
      }

      var existingOwners = txApp.findRecordsByFilter(
        "users",
        "phone = {:phone} && phone_verified = true && id != {:user}",
        "",
        1,
        0,
        { phone: phone, user: userId }
      );
      if (existingOwners.length) {
        record.set("status", _WA_OTP_STATUS_USED);
        record.set("is_used", true);
        txApp.save(record);
        return;
      }

      var authenticatedUser = txApp.findRecordById("users", userId);
      record.set("status", _WA_OTP_STATUS_USED);
      record.set("is_used", true);
      record.set("last_attempt_at", nowString);
      txApp.save(record);

      authenticatedUser.set("phone", phone);
      authenticatedUser.set("phone_verified", true);
      authenticatedUser.set("phone_verified_at", nowString);
      txApp.save(authenticatedUser);
      outcome = "verified";
    });
  } catch (_) {
    $app.logger().error("WhatsApp OTP verification transaction failed");
    return e.json(500, {
      error: "verification_unavailable",
      message: "Phone verification is temporarily unavailable. Please try again."
    });
  }

  if (outcome === "verified") {
    $app.logger().info("WhatsApp OTP verification completed", "user", userId);
    return e.json(200, {
      ok: true,
      message: "Phone number verified successfully."
    });
  }

  if (outcome === "throttled") {
    return e.json(429, {
      error: "too_many_attempts",
      message: "Too many verification attempts. Please request a new code later."
    });
  }

  return e.json(400, {
    error: "verification_failed",
    message: "The verification code is invalid or expired. Please request a new code."
  });
});

// Verification fields are server-managed. Native PocketBase superusers retain
// an emergency recovery path. Ordinary phone profile updates remain permitted,
// but changing the phone revokes any prior verification state.
onRecordCreateRequest(function(e) {
  if (!e.hasSuperuserAuth()) {
    e.record.set("phone_verified", false);
    e.record.set("phone_verified_at", "");
  }
  return e.next();
}, "users");

onRecordUpdateRequest(function(e) {
  if (e.hasSuperuserAuth()) return e.next();

  var body = e.requestInfo().body;
  if (body["phone_verified"] !== undefined || body["phone_verified_at"] !== undefined) {
    throw new ForbiddenError("Phone verification fields are server-managed.");
  }

  if (body["phone"] !== undefined &&
      e.record.getString("phone") !== e.record.original().getString("phone")) {
    e.record.set("phone_verified", false);
    e.record.set("phone_verified_at", "");
  }

  return e.next();
}, "users");
