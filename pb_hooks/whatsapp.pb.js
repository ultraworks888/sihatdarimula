// WhatsApp Business configuration endpoints
// Credentials are stored in lms_settings (server-side only — never returned to the browser)

// GET /api/admin/whatsapp/config — check whether credentials are configured
routerAdd("GET", "/api/admin/whatsapp/config", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  const role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  const getKey = (k) => {
    try {
      const r = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k });
      return r.getString("value");
    } catch { return ""; }
  };

  const phoneId  = getKey("whatsapp_phone_number_id");
  const token    = getKey("whatsapp_access_token");
  const version  = getKey("whatsapp_api_version") || "v20.0";

  return e.json(200, {
    configured:    !!(phoneId && token),
    has_phone_id:  !!phoneId,
    has_token:     !!token,
    api_version:   version,
  });
});

// POST /api/admin/whatsapp/config — save credentials (values stored server-side only)
routerAdd("POST", "/api/admin/whatsapp/config", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  const role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  const info = e.requestInfo();
  const phoneId  = String(info.body["phone_number_id"] || "").trim();
  const token    = String(info.body["access_token"]    || "").trim();
  const version  = String(info.body["api_version"]     || "v20.0").trim();

  const saveKey = (k, v) => {
    if (!v) return;
    try {
      const r = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k });
      r.set("value", v);
      $app.save(r);
    } catch {
      const coll = $app.findCollectionByNameOrId("lms_settings");
      const r    = new Record(coll);
      r.set("key",   k);
      r.set("value", v);
      $app.save(r);
    }
  };

  if (phoneId) saveKey("whatsapp_phone_number_id", phoneId);
  if (token)   saveKey("whatsapp_access_token",    token);
  saveKey("whatsapp_api_version", version);

  $app.logger().info("whatsapp config saved", "by", e.auth.id);
  return e.json(200, { ok: true });
});

// DELETE /api/admin/whatsapp/config — clear credentials
routerAdd("DELETE", "/api/admin/whatsapp/config", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  const role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  const keys = ["whatsapp_phone_number_id", "whatsapp_access_token", "whatsapp_api_version"];
  for (const k of keys) {
    try {
      const r = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k });
      $app.delete(r);
    } catch { /* not set — skip */ }
  }

  return e.json(200, { ok: true });
});
