/**
 * WhatsApp OTP for phone verification — My Healthy Start
 *
 * POST /api/auth/request-whatsapp-otp
 *   Body: { phone: "+601XXXXXXXXX" }
 *   Generates a 6-digit OTP, stores it in phone_otps, sends via Meta Cloud API.
 *   Requires in lms_settings:
 *     - whatsapp_phone_number_id   Meta Phone Number ID
 *     - whatsapp_access_token      Permanent System User token
 *     - whatsapp_api_version       e.g. "v20.0" (optional, defaults to v20.0)
 *   Meta template: sdm_otp_verify (AUTHENTICATION, en_US, approved)
 *   Template structure:
 *     - Body: {{1}} and {{2}} — both = OTP code
 *     - Button index 0: url type — OTP code appended as URL suffix
 *
 * POST /api/auth/verify-whatsapp-otp
 *   Body: { phone: "+601XXXXXXXXX", code: "123456" }
 *   Verifies the OTP, marks it as used.
 */

routerAdd("POST", "/api/auth/request-whatsapp-otp", (e) => {
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
      message: "WhatsApp OTP is not yet configured. Contact the administrator."
    });
  }

  // Generate 6-digit OTP
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
          type:       "button",
          sub_type:   "url",
          index:      0,
          parameters: [{ type: "text", text: code }]
        }
      ]
    }
  };

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

  $app.logger().info("WhatsApp OTP Meta response", "status", res.statusCode, "body", res.raw);

  if (res.statusCode >= 200 && res.statusCode < 300) {
    return e.json(200, { ok: true, message: "OTP sent to your WhatsApp number." });
  }

  let metaError = "";
  try { metaError = JSON.stringify(res.json); } catch(_) { metaError = res.raw; }
  return e.json(500, { error: "send_failed", message: "Failed to send WhatsApp message. Please try again.", detail: metaError });
});


routerAdd("POST", "/api/auth/verify-whatsapp-otp", (e) => {
  const body  = e.requestInfo().body;
  const phone = String(body.phone || "").trim();
  const code  = String(body.code  || "").trim();

  if (!phone || !code) {
    return e.json(400, { error: "missing_fields", message: "Phone and OTP code are required." });
  }

  try {
    const otp = $app.findFirstRecordByFilter(
      "phone_otps",
      "phone = {:p} && code = {:c} && is_used = false",
      { p: phone, c: code }
    );

    const expiresStr = otp.getString("expires_at");
    const expiry     = new Date(expiresStr.replace(" ", "T").replace("Z", "+00:00"));
    if (Date.now() > expiry.getTime()) {
      return e.json(400, { error: "expired", message: "This OTP has expired. Please request a new one." });
    }

    otp.set("is_used", true);
    $app.save(otp);

    $app.logger().info("WhatsApp OTP verified", "phone", phone.slice(0, 6) + "****");
    return e.json(200, { ok: true, message: "Phone number verified successfully." });

  } catch(_) {
    return e.json(400, { error: "invalid_otp", message: "Invalid or expired code. Please try again." });
  }
});
