/**
 * WhatsApp Password Reset — My Healthy Start
 *
 * POST /api/auth/request-password-reset-whatsapp
 *   Body: { phone: "+601XXXXXXXXX" }
 *   Finds user by phone, sends 6-digit OTP via Meta Cloud API.
 *   Always returns ok (prevents phone enumeration).
 *
 * POST /api/auth/confirm-password-reset-whatsapp
 *   Body: { phone: "+601XXXXXXXXX", code: "123456", password: "newpassword" }
 *   Verifies OTP, resets password.
 *
 * Meta template: sdm_otp_verify (AUTHENTICATION, en_US, approved)
 * Template structure:
 *   - Body: {{1}} and {{2}} — both = OTP code
 *   - Button index 0: url type — OTP code appended as URL suffix
 */

routerAdd("POST", "/api/auth/request-password-reset-whatsapp", (e) => {
  function getSetting(key) {
    try {
      const rec = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key });
      return rec.getString("value");
    } catch(_) { return ""; }
  }
  function formatPhone(p) {
    p = String(p || "").replace(/[\s\-\(\)]/g, "");
    if (p.startsWith("+")) p = p.slice(1);
    return p;
  }

  const body  = e.requestInfo().body;
  const phone = String(body.phone || "").trim();
  if (!phone) return e.json(400, { error: "phone_required", message: "Phone number is required." });

  const phoneId = getSetting("whatsapp_phone_number_id");
  const token   = getSetting("whatsapp_access_token");
  const version = getSetting("whatsapp_api_version") || "v20.0";

  if (!phoneId || !token) {
    return e.json(503, {
      error: "whatsapp_not_configured",
      message: "WhatsApp is not yet configured. Contact the administrator."
    });
  }

  // Silently check if user exists — don't reveal registration status
  let userExists = false;
  try {
    $app.findFirstRecordByFilter("users", "phone = {:p}", { p: phone });
    userExists = true;
  } catch(_) {}

  if (userExists) {
    const code         = String(Math.floor(100000 + Math.random() * 900000));
    const expiresAt    = new Date(Date.now() + 10 * 60 * 1000);
    const expiresAtStr = expiresAt.toISOString().replace("T", " ").slice(0, 23) + "Z";

    // Invalidate any existing unused OTPs for this phone
    try {
      const existing = $app.findRecordsByFilter("phone_otps", "phone = {:p} && is_used = false", "", 0, 0, { p: phone });
      for (const rec of existing) { rec.set("is_used", true); $app.save(rec); }
    } catch(_) {}

    // Store new OTP
    const otpCol = $app.findCollectionByNameOrId("phone_otps");
    const otpRec = new Record(otpCol);
    otpRec.set("phone",      phone);
    otpRec.set("code",       code);
    otpRec.set("expires_at", expiresAtStr);
    otpRec.set("is_used",    false);
    $app.save(otpRec);

    // Send via Meta Cloud API — sdm_otp_verify (AUTHENTICATION, en_US)
    // Body has {{1}} and {{2}} — both are the OTP code.
    // Button at index 0 is url type — OTP code is the URL suffix param.
    const payload = {
      messaging_product: "whatsapp",
      to:   formatPhone(phone),
      type: "template",
      template: {
        name:     "sdm_otp_verify",
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
            type:     "button",
            sub_type: "url",
            index:    0,
            parameters: [{ type: "text", text: code }]
          }
        ]
      }
    };

    try {
      const res = $http.send({
        url:    `https://graph.facebook.com/${version}/${phoneId}/messages`,
        method: "POST",
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type":  "application/json",
        },
        body:    JSON.stringify(payload),
        timeout: 15,
      });
      $app.logger().info("Password reset OTP sent via Meta", "phone", phone.slice(0, 6) + "****", "status", res.statusCode, "body", res.raw);
    } catch(err) {
      $app.logger().warn("Password reset OTP send failed", "phone", phone.slice(0, 6) + "****", "error", String(err));
    }
  }

  // Always return success — never reveal whether phone is registered
  return e.json(200, { ok: true, message: "If this number is registered, a reset code has been sent to your WhatsApp." });
});


routerAdd("POST", "/api/auth/confirm-password-reset-whatsapp", (e) => {
  const body     = e.requestInfo().body;
  const phone    = String(body.phone    || "").trim();
  const code     = String(body.code     || "").trim();
  const password = String(body.password || "").trim();

  if (!phone || !code || !password) {
    return e.json(400, { error: "missing_fields", message: "Phone, OTP code, and new password are required." });
  }
  if (password.length < 8) {
    return e.json(400, { error: "password_too_short", message: "Password must be at least 8 characters." });
  }

  // Verify OTP
  let otp;
  try {
    otp = $app.findFirstRecordByFilter(
      "phone_otps",
      "phone = {:p} && code = {:c} && is_used = false",
      { p: phone, c: code }
    );
  } catch(_) {
    return e.json(400, { error: "invalid_otp", message: "Invalid or expired code. Please try again." });
  }

  // Check expiry
  const expiresStr = otp.getString("expires_at");
  const expiry     = new Date(expiresStr.replace(" ", "T").replace("Z", "+00:00"));
  if (Date.now() > expiry.getTime()) {
    return e.json(400, { error: "expired", message: "This OTP has expired. Please request a new one." });
  }

  // Find user by phone
  let user;
  try {
    user = $app.findFirstRecordByFilter("users", "phone = {:p}", { p: phone });
  } catch(_) {
    return e.json(404, { error: "user_not_found", message: "No account found with this phone number." });
  }

  // Mark OTP used and reset password
  otp.set("is_used", true);
  $app.save(otp);

  user.setPassword(password);
  $app.save(user);

  $app.logger().info("Password reset via WhatsApp", "phone", phone.slice(0, 6) + "****");
  return e.json(200, { ok: true, message: "Password reset successfully." });
});
