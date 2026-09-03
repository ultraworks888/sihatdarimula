/**
 * LMS Course Inactivity Reminder — My Healthy Start
 *
 * POST /api/lms/send-reminders
 * Called by: a cron job that POSTs to this URL every 24h
 *
 * Finds enrollments that are incomplete and have had no activity for
 * `reminder_days` days (default 3), then sends a WhatsApp reminder via
 * Meta Cloud API using the approved template with trigger_event = 'course_reminder'.
 *
 * Template variables resolved from context:
 *   first_name    — first name of the user
 *   user_name     — full name of the user
 *   child_name    — first child's name (or "your little one")
 *   course_name   — localized course title
 *   progress      — e.g. "45%"
 *   app_link      — app URL from lms_settings
 *
 * GET /api/lms/reminder-status — health-check, returns config status.
 */

routerAdd("POST", "/api/lms/send-reminders", (e) => {
  function getSetting(key) {
    try {
      const rec = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key });
      return rec.getString("value");
    } catch (_) { return ""; }
  }
  function formatPhone(p) {
    p = String(p || "").replace(/[\s\-\(\)]/g, "");
    if (p.startsWith("+")) p = p.slice(1);
    return p;
  }
  function firstName(name) {
    const n = String(name || "").trim();
    return n.split(" ")[0] || "there";
  }
  function resolveVars(jsonStr, ctx) {
    let vars;
    try { vars = JSON.parse(jsonStr || "[]"); } catch (_) { return []; }
    if (!Array.isArray(vars) || !vars.length) return [];
    return vars.slice().sort((a, b) => (a.index || 0) - (b.index || 0))
               .map(v => String(ctx[v.name] || v.example || ""));
  }
  function sendTemplate(phoneId, token, version, to, tplName, langCode, bodyParams) {
    const payload = {
      messaging_product: "whatsapp", to, type: "template",
      template: { name: tplName, language: { code: langCode } }
    };
    if (bodyParams.length > 0) {
      payload.template.components = [{
        type: "body",
        parameters: bodyParams.map(t => ({ type: "text", text: t }))
      }];
    }
    return $http.send({
      url: `https://graph.facebook.com/${version}/${phoneId}/messages`,
      method: "POST",
      headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(payload), timeout: 15,
    });
  }

  const phoneId     = getSetting("whatsapp_phone_number_id");
  const token       = getSetting("whatsapp_access_token");
  const version     = getSetting("whatsapp_api_version") || "v20.0";
  const reminderDays = parseInt(getSetting("reminder_days") || "3", 10);

  if (!phoneId || !token) {
    return e.json(503, { error: "WhatsApp credentials not configured in lms_settings." });
  }

  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - reminderDays);
  const cutoff = cutoffDate.toISOString().replace("T", " ").slice(0, 23) + "Z";

  const enrollments = $app.findRecordsByFilter(
    "enrollments",
    "is_completed = false && updated < {:cutoff}",
    "-updated", 50, 0, { cutoff }
  );

  let sent = 0, failed = 0, skipped = 0;
  const results = [];

  for (const enr of enrollments) {
    try {
      const userId = enr.getString("user");
      let user;
      try { user = $app.findRecordById("users", userId); } catch (_) { skipped++; continue; }

      const phone = user.getString("phone");
      if (!phone) { skipped++; continue; }

      // Respect opt-out
      try {
        const pref = $app.findFirstRecordByFilter("notification_preferences", "user = {:u}", { u: userId });
        if (!pref.getBool("whatsapp_enabled")) { skipped++; continue; }
      } catch (_) {}

      const langMap  = { en: "en", ms: "ms", zh: "zh_CN" };
      const langCode = langMap[user.getString("language")] || "en";

      let tpl = null;
      try {
        tpl = $app.findFirstRecordByFilter("whatsapp_templates",
          "trigger_event = 'course_reminder' && language_code = {:lc} && approval_status = 'approved' && is_active = true",
          { lc: langCode });
      } catch (_) {}
      if (!tpl && langCode !== "en") {
        try {
          tpl = $app.findFirstRecordByFilter("whatsapp_templates",
            "trigger_event = 'course_reminder' && language_code = 'en' && approval_status = 'approved' && is_active = true", {});
        } catch (_) {}
      }
      if (!tpl) { skipped++; continue; }

      const courseId = enr.getString("course");
      let courseName = "your parenting course";
      try {
        const course = $app.findRecordById("courses", courseId);
        const lang = user.getString("language");
        courseName = (lang && lang !== "en" ? course.getString("title_" + lang) : "")
                     || course.getString("title_en") || courseName;
      } catch (_) {}

      let childName = "your little one";
      try {
        const kids = $app.findRecordsByFilter("children", "user = {:u}", "-created", 1, 0, { u: userId });
        if (kids.length > 0) childName = kids[0].getString("name") || childName;
      } catch (_) {}

      const progress = Math.round(enr.getFloat("progress_percent"));

      const ctx = {
        first_name:  firstName(user.getString("name")),
        user_name:   user.getString("name") || "there",
        child_name:  childName,
        course_name: courseName,
        progress:    `${progress}%`,
        app_link:    getSetting("app_url") || "https://app.sihatdarimula.my",
      };
      const res = sendTemplate(phoneId, token, version, formatPhone(phone),
        tpl.getString("meta_template_name"), tpl.getString("language_code"), resolveVars(tpl.getString("variables"), ctx));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        sent++;
        results.push({ user: userId, status: "sent" });
        $app.logger().info("LMS course reminder sent", "user", userId, "course", courseId);
      } else {
        failed++;
        results.push({ user: userId, status: "failed", code: res.statusCode });
        $app.logger().warn("LMS course reminder failed", "user", userId, "status", res.statusCode, "body", res.raw);
      }
    } catch (err) {
      failed++;
      $app.logger().error("LMS course reminder error", "error", String(err));
    }
  }

  return e.json(200, { ok: true, checked: enrollments.length, sent, skipped, failed, cutoff_date: cutoff, results });
});


routerAdd("GET", "/api/lms/reminder-status", (e) => {
  function hasSetting(key) {
    try { $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key }); return true; }
    catch (_) { return false; }
  }
  return e.json(200, {
    configured: {
      whatsapp_phone_number_id: hasSetting("whatsapp_phone_number_id"),
      whatsapp_access_token:    hasSetting("whatsapp_access_token"),
      reminder_days:            hasSetting("reminder_days"),
    },
  });
});
