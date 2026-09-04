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
var _WA_OTP_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
var _WA_OTP_CLEANUP_BATCH_SIZE = 500;

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

function _waOtpFailureCount(app, filter, params) {
  var records = _waOtpRecords(
    app,
    filter,
    "-created",
    100,
    params
  );
  var count = 0;

  for (var i = 0; i < records.length; i++) {
    count += records[i].getInt("failed_attempts");
  }
  return count;
}

function _waOtpUserFailureCount(app, userId, cutoff) {
  return _waOtpFailureCount(
    app,
    "user = {:user} && created >= {:cutoff}",
    { user: userId, cutoff: cutoff }
  );
}

function _waOtpPhoneFailureCount(app, phone, cutoff) {
  return _waOtpFailureCount(
    app,
    "phone = {:phone} && created >= {:cutoff}",
    { phone: phone, cutoff: cutoff }
  );
}

function _waOtpFailureLimitReached(codeFailures, userFailures, phoneFailures) {
  return codeFailures >= _WA_OTP_MAX_FAILURES_PER_CODE ||
    userFailures >= _WA_OTP_MAX_FAILURES_PER_HOUR ||
    phoneFailures >= _WA_OTP_MAX_FAILURES_PER_HOUR;
}

// Cooldown is deliberately enforced for both dimensions. A user cannot avoid
// it by changing phone numbers, and a phone cannot be spammed through multiple
// authenticated accounts.
function _waOtpSendCooldownReached(app, userId, phone, cutoff) {
  return _waOtpAtLimit(app, "user = {:user} && created >= {:cutoff}", {
    user: userId,
    cutoff: cutoff
  }, 1) || _waOtpAtLimit(app, "phone = {:phone} && created >= {:cutoff}", {
    phone: phone,
    cutoff: cutoff
  }, 1);
}

function _waOtpIsExpired(now, expiresAt) {
  var expiry = new Date(String(expiresAt || "").replace(" ", "T")).getTime();
  return !isFinite(expiry) || now >= expiry;
}

function _waOtpExpireStaleRecords(app, nowString) {
  var records = _waOtpRecords(
    app,
    "(status = {:pending} || status = {:active}) && is_used = false && expires_at <= {:now}",
    "created",
    _WA_OTP_CLEANUP_BATCH_SIZE,
    {
      pending: _WA_OTP_STATUS_PENDING,
      active: _WA_OTP_STATUS_ACTIVE,
      now: nowString
    }
  );

  for (var i = 0; i < records.length; i++) {
    records[i].set("status", _WA_OTP_STATUS_EXPIRED);
    records[i].set("is_used", true);
    app.save(records[i]);
  }
}

function _waOtpDeleteRetainedTerminalRecords(app, cutoff) {
  var records = _waOtpRecords(
    app,
    "(status = {:failed} || status = {:invalidated} || status = {:expired} || status = {:locked} || status = {:used}) && created < {:cutoff}",
    "created",
    _WA_OTP_CLEANUP_BATCH_SIZE,
    {
      failed: _WA_OTP_STATUS_FAILED,
      invalidated: _WA_OTP_STATUS_INVALIDATED,
      expired: _WA_OTP_STATUS_EXPIRED,
      locked: _WA_OTP_STATUS_LOCKED,
      used: _WA_OTP_STATUS_USED,
      cutoff: cutoff
    }
  );

  for (var i = 0; i < records.length; i++) {
    app.delete(records[i]);
  }
}

// Hourly, first expire stale pending/active records, then retain terminal audit
// metadata for seven days. Valid active OTPs are never deleted by this job.
cronAdd("phone_verification_otp_cleanup", "23 * * * *", function() {
  var _WA_OTP_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
  var _WA_OTP_CLEANUP_BATCH_SIZE = 500;
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

  function _waOtpExpireStaleRecords(app, nowString) {
    var records = _waOtpRecords(
      app,
      "(status = {:pending} || status = {:active}) && is_used = false && expires_at <= {:now}",
      "created",
      _WA_OTP_CLEANUP_BATCH_SIZE,
      {
        pending: _WA_OTP_STATUS_PENDING,
        active: _WA_OTP_STATUS_ACTIVE,
        now: nowString
      }
    );

    for (var i = 0; i < records.length; i++) {
      records[i].set("status", _WA_OTP_STATUS_EXPIRED);
      records[i].set("is_used", true);
      app.save(records[i]);
    }
  }

  function _waOtpDeleteRetainedTerminalRecords(app, cutoff) {
    var records = _waOtpRecords(
      app,
      "(status = {:failed} || status = {:invalidated} || status = {:expired} || status = {:locked} || status = {:used}) && created < {:cutoff}",
      "created",
      _WA_OTP_CLEANUP_BATCH_SIZE,
      {
        failed: _WA_OTP_STATUS_FAILED,
        invalidated: _WA_OTP_STATUS_INVALIDATED,
        expired: _WA_OTP_STATUS_EXPIRED,
        locked: _WA_OTP_STATUS_LOCKED,
        used: _WA_OTP_STATUS_USED,
        cutoff: cutoff
      }
    );

    for (var i = 0; i < records.length; i++) {
      app.delete(records[i]);
    }
  }

  var now = Date.now();

  try {
    $app.runInTransaction(function(txApp) {
      _waOtpExpireStaleRecords(txApp, _waOtpDate(now));
      _waOtpDeleteRetainedTerminalRecords(
        txApp,
        _waOtpDate(now - _WA_OTP_RETENTION_MS)
      );
    });
  } catch (_) {
    $app.logger().error("WhatsApp OTP retention cleanup failed");
  }
});

routerAdd("POST", "/api/auth/request-whatsapp-otp", function(e) {
  var _WA_OTP_LENGTH = 6;
  var _WA_OTP_TTL_MS = 10 * 60 * 1000;
  var _WA_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
  var _WA_OTP_SENDS_PER_HOUR = 5;
  var _WA_OTP_SENDS_PER_DAY = 10;
  var _WA_OTP_STATUS_PENDING = "pending";
  var _WA_OTP_STATUS_ACTIVE = "active";
  var _WA_OTP_STATUS_FAILED = "failed";
  var _WA_OTP_STATUS_INVALIDATED = "invalidated";

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

  function _waOtpAuthenticatedUser(event) {
    if (!event.auth) return null;
    try {
      if (event.auth.collection().name !== "users") return null;
      return $app.findRecordById("users", event.auth.id);
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

  function _waOtpSendCooldownReached(app, userId, phone, cutoff) {
    return _waOtpAtLimit(app, "user = {:user} && created >= {:cutoff}", {
      user: userId,
      cutoff: cutoff
    }, 1) || _waOtpAtLimit(app, "phone = {:phone} && created >= {:cutoff}", {
      phone: phone,
      cutoff: cutoff
    }, 1);
  }

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
      if (_waOtpSendCooldownReached(txApp, userId, phone, minuteCutoff) ||
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
  var _WA_OTP_MAX_FAILURES_PER_CODE = 5;
  var _WA_OTP_MAX_FAILURES_PER_HOUR = 10;
  var _WA_OTP_STATUS_ACTIVE = "active";
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

  function _waOtpAuthenticatedUser(event) {
    if (!event.auth) return null;
    try {
      if (event.auth.collection().name !== "users") return null;
      return $app.findRecordById("users", event.auth.id);
    } catch (_) {
      return null;
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

  function _waOtpFailureCount(app, filter, params) {
    var records = _waOtpRecords(app, filter, "-created", 100, params);
    var count = 0;
    for (var i = 0; i < records.length; i++) {
      count += records[i].getInt("failed_attempts");
    }
    return count;
  }

  function _waOtpUserFailureCount(app, userId, cutoff) {
    return _waOtpFailureCount(
      app,
      "user = {:user} && created >= {:cutoff}",
      { user: userId, cutoff: cutoff }
    );
  }

  function _waOtpPhoneFailureCount(app, phone, cutoff) {
    return _waOtpFailureCount(
      app,
      "phone = {:phone} && created >= {:cutoff}",
      { phone: phone, cutoff: cutoff }
    );
  }

  function _waOtpFailureLimitReached(codeFailures, userFailures, phoneFailures) {
    return codeFailures >= _WA_OTP_MAX_FAILURES_PER_CODE ||
      userFailures >= _WA_OTP_MAX_FAILURES_PER_HOUR ||
      phoneFailures >= _WA_OTP_MAX_FAILURES_PER_HOUR;
  }

  function _waOtpIsExpired(now, expiresAt) {
    var expiry = new Date(String(expiresAt || "").replace(" ", "T")).getTime();
    return !isFinite(expiry) || now >= expiry;
  }

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
      var hourlyUserFailures = _waOtpUserFailureCount(txApp, userId, hourCutoff);
      var hourlyPhoneFailures = _waOtpPhoneFailureCount(txApp, phone, hourCutoff);
      if (_waOtpFailureLimitReached(
        failures,
        hourlyUserFailures,
        hourlyPhoneFailures
      )) {
        record.set("status", _WA_OTP_STATUS_LOCKED);
        record.set("is_used", true);
        txApp.save(record);
        outcome = "throttled";
        return;
      }

      if (_waOtpIsExpired(now, record.getString("expires_at"))) {
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
        if (_waOtpFailureLimitReached(
          failures,
          hourlyUserFailures + 1,
          hourlyPhoneFailures + 1
        )) {
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
  var body = e.requestInfo().body;
  if (!e.hasSuperuserAuth() &&
      (body["phone_verified"] !== undefined || body["phone_verified_at"] !== undefined)) {
    throw new ForbiddenError("Phone verification fields are server-managed.");
  }

  // Applies to every REST caller, including native PocketBase superusers. A
  // superuser may use the emergency recovery path only in a later request once
  // the persisted phone is unchanged.
  if (body["phone"] !== undefined &&
      e.record.getString("phone") !== e.record.original().getString("phone")) {
    e.record.set("phone_verified", false);
    e.record.set("phone_verified_at", "");
  }

  return e.next();
}, "users");
