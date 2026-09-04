/**
 * Secure WhatsApp password recovery — My Healthy Start
 *
 * POST /api/auth/request-password-reset-whatsapp
 *   Body: { phone: "+601XXXXXXXXX" }
 *   Always returns the same success-shaped response. A message is sent only
 *   when the canonical phone belongs to an eligible, verified user.
 *
 * POST /api/auth/confirm-password-reset-whatsapp
 *   Body: { phone: "+601XXXXXXXXX", code: "123456", password: "newpassword" }
 *   Verifies and consumes the OTP while changing only its bound user's
 *   password in one database transaction.
 *
 * OTPs are generated with PocketBase's crypto/rand-backed $security helper
 * and persisted only as salted SHA-256 digests. The legacy plaintext
 * phone_otps collection is intentionally not used by this flow.
 */

"use strict";

var _PW_OTP_LENGTH = 6;
var _PW_OTP_TTL_MS = 10 * 60 * 1000;
var _PW_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
var _PW_OTP_SENDS_PER_HOUR = 5;
var _PW_OTP_SENDS_PER_DAY = 10;
var _PW_OTP_MAX_FAILURES_PER_CODE = 5;
var _PW_OTP_MAX_FAILURES_PER_HOUR = 10;
var _PW_OTP_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
var _PW_OTP_CLEANUP_BATCH_SIZE = 500;

var _PW_OTP_STATUS_PENDING = "pending";
var _PW_OTP_STATUS_ACTIVE = "active";
var _PW_OTP_STATUS_FAILED = "failed";
var _PW_OTP_STATUS_INVALIDATED = "invalidated";
var _PW_OTP_STATUS_EXPIRED = "expired";
var _PW_OTP_STATUS_LOCKED = "locked";
var _PW_OTP_STATUS_USED = "used";

function _pwOtpDate(value) {
  return new Date(value).toISOString().replace("T", " ");
}

function _pwOtpNormalizeMalaysianPhone(value) {
  var phone = String(value || "").trim().replace(/[\s().-]/g, "");

  if (/^01\d{8,9}$/.test(phone)) {
    phone = "+6" + phone;
  } else if (/^601\d{8,9}$/.test(phone)) {
    phone = "+" + phone;
  }

  if (!/^\+601\d{8,9}$/.test(phone)) return "";
  return phone;
}

function _pwOtpGenericInitiationResponse(e) {
  return e.json(200, {
    ok: true,
    message: "If this number is registered, a reset code has been sent to your WhatsApp."
  });
}

function _pwOtpGenericFailureResponse(e) {
  return e.json(400, {
    error: "invalid_otp",
    message: "Invalid or expired code. Please try again."
  });
}

function _pwOtpSetting(key) {
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

function _pwOtpFindEligibleUser(app, phone) {
  try {
    return app.findFirstRecordByFilter(
      "users",
      "phone = {:phone} && phone_verified = true",
      { phone: phone }
    );
  } catch (_) {
    return null;
  }
}

function _pwOtpHash(code, salt) {
  return $security.sha256(salt + ":" + code);
}

function _pwOtpRecords(app, filter, sort, limit, params) {
  return app.findRecordsByFilter(
    "password_reset_otps",
    filter,
    sort || "",
    limit || 0,
    0,
    params || {}
  );
}

function _pwOtpAtLimit(app, filter, params, limit) {
  return _pwOtpRecords(app, filter, "-created", limit, params).length >= limit;
}

function _pwOtpFailureCount(app, phone, cutoff) {
  var records = _pwOtpRecords(
    app,
    "phone = {:phone} && created >= {:cutoff}",
    "-created",
    100,
    { phone: phone, cutoff: cutoff }
  );
  var count = 0;

  for (var i = 0; i < records.length; i++) {
    count += records[i].getInt("failed_attempts");
  }
  return count;
}

function _pwOtpFailureLimitReached(codeFailures, phoneFailures) {
  return codeFailures >= _PW_OTP_MAX_FAILURES_PER_CODE ||
    phoneFailures >= _PW_OTP_MAX_FAILURES_PER_HOUR;
}

function _pwOtpInvalidateOtherOpenRecords(app, userId, phone, exceptId) {
  var records = _pwOtpRecords(
    app,
    "(user = {:user} || phone = {:phone}) && id != {:id} && is_used = false",
    "",
    100,
    { user: userId, phone: phone, id: exceptId }
  );

  for (var i = 0; i < records.length; i++) {
    records[i].set("status", _PW_OTP_STATUS_INVALIDATED);
    records[i].set("is_used", true);
    app.save(records[i]);
  }
}

function _pwOtpMarkDeliveryFailed(recordId) {
  try {
    $app.runInTransaction(function(txApp) {
      var record = txApp.findRecordById("password_reset_otps", recordId);
      if (record.getString("status") === _PW_OTP_STATUS_PENDING) {
        record.set("status", _PW_OTP_STATUS_FAILED);
        record.set("is_used", true);
        txApp.save(record);
      }
    });
  } catch (_) {
    $app.logger().error("Password reset OTP delivery cleanup failed");
  }
}

function _pwOtpIsExpired(now, expiresAt) {
  var expiry = new Date(String(expiresAt || "").replace(" ", "T")).getTime();
  return !isFinite(expiry) || now >= expiry;
}

function _pwOtpExpireStaleRecords(app, nowString) {
  var records = _pwOtpRecords(
    app,
    "(status = {:pending} || status = {:active}) && is_used = false && expires_at <= {:now}",
    "created",
    _PW_OTP_CLEANUP_BATCH_SIZE,
    {
      pending: _PW_OTP_STATUS_PENDING,
      active: _PW_OTP_STATUS_ACTIVE,
      now: nowString
    }
  );

  for (var i = 0; i < records.length; i++) {
    records[i].set("status", _PW_OTP_STATUS_EXPIRED);
    records[i].set("is_used", true);
    app.save(records[i]);
  }
}

function _pwOtpDeleteRetainedTerminalRecords(app, cutoff) {
  var records = _pwOtpRecords(
    app,
    "(status = {:failed} || status = {:invalidated} || status = {:expired} || status = {:locked} || status = {:used}) && created < {:cutoff}",
    "created",
    _PW_OTP_CLEANUP_BATCH_SIZE,
    {
      failed: _PW_OTP_STATUS_FAILED,
      invalidated: _PW_OTP_STATUS_INVALIDATED,
      expired: _PW_OTP_STATUS_EXPIRED,
      locked: _PW_OTP_STATUS_LOCKED,
      used: _PW_OTP_STATUS_USED,
      cutoff: cutoff
    }
  );

  for (var i = 0; i < records.length; i++) {
    app.delete(records[i]);
  }
}

// Terminal records are retained for seven days and processed in bounded
// batches. Active, unexpired OTPs are never selected for deletion.
cronAdd("password_reset_otp_cleanup", "37 * * * *", function() {
  var _PW_OTP_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
  var _PW_OTP_CLEANUP_BATCH_SIZE = 500;
  var _PW_OTP_STATUS_PENDING = "pending";
  var _PW_OTP_STATUS_ACTIVE = "active";
  var _PW_OTP_STATUS_FAILED = "failed";
  var _PW_OTP_STATUS_INVALIDATED = "invalidated";
  var _PW_OTP_STATUS_EXPIRED = "expired";
  var _PW_OTP_STATUS_LOCKED = "locked";
  var _PW_OTP_STATUS_USED = "used";

  function _pwOtpDate(value) {
    return new Date(value).toISOString().replace("T", " ");
  }

  function _pwOtpRecords(app, filter, sort, limit, params) {
    return app.findRecordsByFilter(
      "password_reset_otps",
      filter,
      sort || "",
      limit || 0,
      0,
      params || {}
    );
  }

  function _pwOtpExpireStaleRecords(app, nowString) {
    var records = _pwOtpRecords(
      app,
      "(status = {:pending} || status = {:active}) && is_used = false && expires_at <= {:now}",
      "created",
      _PW_OTP_CLEANUP_BATCH_SIZE,
      {
        pending: _PW_OTP_STATUS_PENDING,
        active: _PW_OTP_STATUS_ACTIVE,
        now: nowString
      }
    );
    for (var i = 0; i < records.length; i++) {
      records[i].set("status", _PW_OTP_STATUS_EXPIRED);
      records[i].set("is_used", true);
      app.save(records[i]);
    }
  }

  function _pwOtpDeleteRetainedTerminalRecords(app, cutoff) {
    var records = _pwOtpRecords(
      app,
      "(status = {:failed} || status = {:invalidated} || status = {:expired} || status = {:locked} || status = {:used}) && created < {:cutoff}",
      "created",
      _PW_OTP_CLEANUP_BATCH_SIZE,
      {
        failed: _PW_OTP_STATUS_FAILED,
        invalidated: _PW_OTP_STATUS_INVALIDATED,
        expired: _PW_OTP_STATUS_EXPIRED,
        locked: _PW_OTP_STATUS_LOCKED,
        used: _PW_OTP_STATUS_USED,
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
      _pwOtpExpireStaleRecords(txApp, _pwOtpDate(now));
      _pwOtpDeleteRetainedTerminalRecords(
        txApp,
        _pwOtpDate(now - _PW_OTP_RETENTION_MS)
      );
    });
  } catch (_) {
    $app.logger().error("Password reset OTP retention cleanup failed");
  }
});

routerAdd("POST", "/api/auth/request-password-reset-whatsapp", function(e) {
  var _PW_OTP_LENGTH = 6;
  var _PW_OTP_TTL_MS = 10 * 60 * 1000;
  var _PW_OTP_RESEND_COOLDOWN_MS = 60 * 1000;
  var _PW_OTP_SENDS_PER_HOUR = 5;
  var _PW_OTP_SENDS_PER_DAY = 10;
  var _PW_OTP_STATUS_PENDING = "pending";
  var _PW_OTP_STATUS_ACTIVE = "active";
  var _PW_OTP_STATUS_FAILED = "failed";
  var _PW_OTP_STATUS_INVALIDATED = "invalidated";

  function _pwOtpDate(value) {
    return new Date(value).toISOString().replace("T", " ");
  }

  function _pwOtpNormalizeMalaysianPhone(value) {
    var phone = String(value || "").trim().replace(/[\s().-]/g, "");
    if (/^01\d{8,9}$/.test(phone)) {
      phone = "+6" + phone;
    } else if (/^601\d{8,9}$/.test(phone)) {
      phone = "+" + phone;
    }
    if (!/^\+601\d{8,9}$/.test(phone)) return "";
    return phone;
  }

  function _pwOtpGenericInitiationResponse(event) {
    return event.json(200, {
      ok: true,
      message: "If this number is registered, a reset code has been sent to your WhatsApp."
    });
  }

  function _pwOtpSetting(key) {
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

  function _pwOtpFindEligibleUser(app, phone) {
    try {
      return app.findFirstRecordByFilter(
        "users",
        "phone = {:phone} && phone_verified = true",
        { phone: phone }
      );
    } catch (_) {
      return null;
    }
  }

  function _pwOtpHash(code, salt) {
    return $security.sha256(salt + ":" + code);
  }

  function _pwOtpRecords(app, filter, sort, limit, params) {
    return app.findRecordsByFilter(
      "password_reset_otps",
      filter,
      sort || "",
      limit || 0,
      0,
      params || {}
    );
  }

  function _pwOtpAtLimit(app, filter, params, limit) {
    return _pwOtpRecords(app, filter, "-created", limit, params).length >= limit;
  }

  function _pwOtpInvalidateOtherOpenRecords(app, userId, phone, exceptId) {
    var records = _pwOtpRecords(
      app,
      "(user = {:user} || phone = {:phone}) && id != {:id} && is_used = false",
      "",
      100,
      { user: userId, phone: phone, id: exceptId }
    );
    for (var i = 0; i < records.length; i++) {
      records[i].set("status", _PW_OTP_STATUS_INVALIDATED);
      records[i].set("is_used", true);
      app.save(records[i]);
    }
  }

  function _pwOtpMarkDeliveryFailed(recordId) {
    try {
      $app.runInTransaction(function(txApp) {
        var record = txApp.findRecordById("password_reset_otps", recordId);
        if (record.getString("status") === _PW_OTP_STATUS_PENDING) {
          record.set("status", _PW_OTP_STATUS_FAILED);
          record.set("is_used", true);
          txApp.save(record);
        }
      });
    } catch (_) {
      $app.logger().error("Password reset OTP delivery cleanup failed");
    }
  }

  var body = e.requestInfo().body;
  var phone = _pwOtpNormalizeMalaysianPhone(body.phone);

  // Malformed, foreign, unknown, and ineligible phones are intentionally
  // indistinguishable from eligible phones at the HTTP response boundary.
  if (!phone) return _pwOtpGenericInitiationResponse(e);

  var user = _pwOtpFindEligibleUser($app, phone);
  if (!user) return _pwOtpGenericInitiationResponse(e);

  var phoneId = _pwOtpSetting("whatsapp_phone_number_id");
  var token = _pwOtpSetting("whatsapp_access_token");
  var version = _pwOtpSetting("whatsapp_api_version") || "v20.0";
  if (!phoneId || !token) {
    $app.logger().warn("Password reset OTP provider configuration unavailable");
    return _pwOtpGenericInitiationResponse(e);
  }

  var userId = user.id;
  var now = Date.now();
  var minuteCutoff = _pwOtpDate(now - _PW_OTP_RESEND_COOLDOWN_MS);
  var hourCutoff = _pwOtpDate(now - 60 * 60 * 1000);
  var dayCutoff = _pwOtpDate(now - 24 * 60 * 60 * 1000);
  var code = $security.randomStringWithAlphabet(_PW_OTP_LENGTH, "0123456789");
  var salt = $security.randomString(32);
  var hash = _pwOtpHash(code, salt);
  var expiresAt = _pwOtpDate(now + _PW_OTP_TTL_MS);
  var recordId = "";
  var throttled = false;

  try {
    $app.runInTransaction(function(txApp) {
      if (_pwOtpAtLimit(txApp, "phone = {:phone} && created >= {:cutoff}", {
        phone: phone,
        cutoff: minuteCutoff
      }, 1) || _pwOtpAtLimit(txApp, "phone = {:phone} && created >= {:cutoff}", {
        phone: phone,
        cutoff: hourCutoff
      }, _PW_OTP_SENDS_PER_HOUR) || _pwOtpAtLimit(
        txApp,
        "phone = {:phone} && created >= {:cutoff}",
        { phone: phone, cutoff: dayCutoff },
        _PW_OTP_SENDS_PER_DAY
      )) {
        throttled = true;
        return;
      }

      var collection = txApp.findCollectionByNameOrId("password_reset_otps");
      var record = new Record(collection);
      record.set("user", userId);
      record.set("phone", phone);
      record.set("otp_hash", hash);
      record.set("otp_salt", salt);
      record.set("expires_at", expiresAt);
      record.set("failed_attempts", 0);
      record.set("status", _PW_OTP_STATUS_PENDING);
      record.set("is_used", false);
      txApp.save(record);
      recordId = record.id;
    });
  } catch (_) {
    $app.logger().error("Password reset OTP request transaction failed");
    return _pwOtpGenericInitiationResponse(e);
  }

  if (throttled) return _pwOtpGenericInitiationResponse(e);

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
    _pwOtpMarkDeliveryFailed(recordId);
    $app.logger().warn("Password reset OTP provider request failed");
    return _pwOtpGenericInitiationResponse(e);
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    _pwOtpMarkDeliveryFailed(recordId);
    $app.logger().warn(
      "Password reset OTP provider rejected delivery",
      "status",
      response.statusCode
    );
    return _pwOtpGenericInitiationResponse(e);
  }

  try {
    $app.runInTransaction(function(txApp) {
      var record = txApp.findRecordById("password_reset_otps", recordId);
      if (record.getString("status") !== _PW_OTP_STATUS_PENDING ||
          record.getBool("is_used")) {
        throw new Error("OTP request is no longer pending");
      }

      _pwOtpInvalidateOtherOpenRecords(txApp, userId, phone, recordId);
      record.set("status", _PW_OTP_STATUS_ACTIVE);
      txApp.save(record);
    });
  } catch (_) {
    _pwOtpMarkDeliveryFailed(recordId);
    $app.logger().error("Password reset OTP activation failed after delivery");
  }

  // Provider failure and throttling deliberately consume the same response
  // shape. Failed provider records count toward quotas (fail-closed), but are
  // never activated and therefore cannot authorize a reset.
  return _pwOtpGenericInitiationResponse(e);
});

routerAdd("POST", "/api/auth/confirm-password-reset-whatsapp", function(e) {
  var _PW_OTP_MAX_FAILURES_PER_CODE = 5;
  var _PW_OTP_MAX_FAILURES_PER_HOUR = 10;
  var _PW_OTP_STATUS_ACTIVE = "active";
  var _PW_OTP_STATUS_INVALIDATED = "invalidated";
  var _PW_OTP_STATUS_EXPIRED = "expired";
  var _PW_OTP_STATUS_LOCKED = "locked";
  var _PW_OTP_STATUS_USED = "used";

  function _pwOtpDate(value) {
    return new Date(value).toISOString().replace("T", " ");
  }

  function _pwOtpNormalizeMalaysianPhone(value) {
    var phone = String(value || "").trim().replace(/[\s().-]/g, "");
    if (/^01\d{8,9}$/.test(phone)) {
      phone = "+6" + phone;
    } else if (/^601\d{8,9}$/.test(phone)) {
      phone = "+" + phone;
    }
    if (!/^\+601\d{8,9}$/.test(phone)) return "";
    return phone;
  }

  function _pwOtpGenericFailureResponse(event) {
    return event.json(400, {
      error: "invalid_otp",
      message: "Invalid or expired code. Please try again."
    });
  }

  function _pwOtpHash(code, salt) {
    return $security.sha256(salt + ":" + code);
  }

  function _pwOtpRecords(app, filter, sort, limit, params) {
    return app.findRecordsByFilter(
      "password_reset_otps",
      filter,
      sort || "",
      limit || 0,
      0,
      params || {}
    );
  }

  function _pwOtpFailureCount(app, phone, cutoff) {
    var records = _pwOtpRecords(
      app,
      "phone = {:phone} && created >= {:cutoff}",
      "-created",
      100,
      { phone: phone, cutoff: cutoff }
    );
    var count = 0;
    for (var i = 0; i < records.length; i++) {
      count += records[i].getInt("failed_attempts");
    }
    return count;
  }

  function _pwOtpFailureLimitReached(codeFailures, phoneFailures) {
    return codeFailures >= _PW_OTP_MAX_FAILURES_PER_CODE ||
      phoneFailures >= _PW_OTP_MAX_FAILURES_PER_HOUR;
  }

  function _pwOtpInvalidateOtherOpenRecords(app, userId, phone, exceptId) {
    var records = _pwOtpRecords(
      app,
      "(user = {:user} || phone = {:phone}) && id != {:id} && is_used = false",
      "",
      100,
      { user: userId, phone: phone, id: exceptId }
    );
    for (var i = 0; i < records.length; i++) {
      records[i].set("status", _PW_OTP_STATUS_INVALIDATED);
      records[i].set("is_used", true);
      app.save(records[i]);
    }
  }

  function _pwOtpIsExpired(now, expiresAt) {
    var expiry = new Date(String(expiresAt || "").replace(" ", "T")).getTime();
    return !isFinite(expiry) || now >= expiry;
  }

  var body = e.requestInfo().body;
  var phone = _pwOtpNormalizeMalaysianPhone(body.phone);
  var code = String(body.code || "").trim();
  var password = String(body.password || "");

  if (!password) {
    return e.json(400, {
      error: "missing_fields",
      message: "Phone, OTP code, and new password are required."
    });
  }
  if (password.length < 8) {
    return e.json(400, {
      error: "password_too_short",
      message: "Password must be at least 8 characters."
    });
  }
  if (!phone || !/^\d{6}$/.test(code)) {
    return _pwOtpGenericFailureResponse(e);
  }

  var now = Date.now();
  var nowString = _pwOtpDate(now);
  var hourCutoff = _pwOtpDate(now - 60 * 60 * 1000);
  var outcome = "invalid";

  try {
    $app.runInTransaction(function(txApp) {
      var records = _pwOtpRecords(
        txApp,
        "phone = {:phone} && status = {:status} && is_used = false",
        "-created",
        1,
        { phone: phone, status: _PW_OTP_STATUS_ACTIVE }
      );
      if (!records.length) return;

      var record = records[0];
      var failures = record.getInt("failed_attempts");
      var hourlyPhoneFailures = _pwOtpFailureCount(txApp, phone, hourCutoff);
      if (_pwOtpFailureLimitReached(failures, hourlyPhoneFailures)) {
        record.set("status", _PW_OTP_STATUS_LOCKED);
        record.set("is_used", true);
        txApp.save(record);
        return;
      }

      if (_pwOtpIsExpired(now, record.getString("expires_at"))) {
        record.set("status", _PW_OTP_STATUS_EXPIRED);
        record.set("is_used", true);
        txApp.save(record);
        return;
      }

      var expectedHash = record.getString("otp_hash");
      var submittedHash = _pwOtpHash(code, record.getString("otp_salt"));
      if (!expectedHash || !$security.equal(expectedHash, submittedHash)) {
        failures += 1;
        record.set("failed_attempts", failures);
        record.set("last_attempt_at", nowString);
        if (_pwOtpFailureLimitReached(failures, hourlyPhoneFailures + 1)) {
          record.set("status", _PW_OTP_STATUS_LOCKED);
          record.set("is_used", true);
        }
        txApp.save(record);
        return;
      }

      var userId = record.getString("user");
      var user;
      try {
        user = txApp.findRecordById("users", userId);
      } catch (_) {
        record.set("status", _PW_OTP_STATUS_INVALIDATED);
        record.set("is_used", true);
        txApp.save(record);
        return;
      }

      if (user.getString("phone") !== phone || !user.getBool("phone_verified")) {
        record.set("status", _PW_OTP_STATUS_INVALIDATED);
        record.set("is_used", true);
        txApp.save(record);
        return;
      }

      _pwOtpInvalidateOtherOpenRecords(txApp, userId, phone, record.id);
      record.set("status", _PW_OTP_STATUS_USED);
      record.set("is_used", true);
      record.set("last_attempt_at", nowString);
      txApp.save(record);

      user.setPassword(password);
      txApp.save(user);
      outcome = "reset";
    });
  } catch (_) {
    $app.logger().error("Password reset OTP transaction failed");
    return e.json(500, {
      error: "reset_unavailable",
      message: "Password reset is temporarily unavailable. Please try again."
    });
  }

  if (outcome !== "reset") return _pwOtpGenericFailureResponse(e);

  $app.logger().info("Password reset via WhatsApp completed");
  return e.json(200, {
    ok: true,
    message: "Password reset successfully."
  });
});
