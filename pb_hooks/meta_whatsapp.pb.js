/**
 * Meta WhatsApp Cloud API — Send Triggers
 * Sihat Dari Mula
 *
 * Credentials read from lms_settings (saved via /admin/whatsapp):
 *   whatsapp_phone_number_id  — Meta Phone Number ID
 *   whatsapp_access_token     — Permanent System User token
 *   whatsapp_api_version      — e.g. "v20.0" (default)
 *   app_url                   — App URL used in message links
 *
 * Endpoints:
 *   POST /api/whatsapp/send-welcome           — called by frontend after phone is saved
 *   POST /api/whatsapp/send-milestone-reminders — admin / cron, weekly cadence
 *   POST /api/admin/whatsapp/meta-blast       — admin, sends course_announcement / promotional_blast
 *
 * Auto-triggered:
 *   onRecordAfterCreateSuccess("enrollments") — Enrolment Confirmation
 *   onRecordAfterUpdateSuccess("enrollments") — Course Completion
 */

// ─── 1. Welcome Message ─────────────────────────────────────────────────────────
// Frontend calls this (fire-and-forget) right after saving the user's phone number.

routerAdd("POST", "/api/whatsapp/send-welcome", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });

  function getSetting(key) {
    try { return $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key }).getString("value"); }
    catch (_) { return ""; }
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

  const user    = $app.findRecordById("users", e.auth.id);
  const phone   = user.getString("phone");
  if (!phone) return e.json(400, { error: "No phone number on account." });

  const phoneId = getSetting("whatsapp_phone_number_id");
  const token   = getSetting("whatsapp_access_token");
  const version = getSetting("whatsapp_api_version") || "v20.0";
  if (!phoneId || !token) return e.json(200, { ok: false, reason: "not_configured" });

  const langMap  = { en: "en", ms: "ms", zh: "zh_CN" };
  const langCode = langMap[user.getString("language")] || "en";

  let tpl = null;
  try {
    tpl = $app.findFirstRecordByFilter("whatsapp_templates",
      "trigger_event = 'user_registration' && language_code = {:lc} && approval_status = 'approved' && is_active = true",
      { lc: langCode });
  } catch (_) {}
  if (!tpl && langCode !== "en") {
    try {
      tpl = $app.findFirstRecordByFilter("whatsapp_templates",
        "trigger_event = 'user_registration' && language_code = 'en' && approval_status = 'approved' && is_active = true", {});
    } catch (_) {}
  }
  if (!tpl) {
    $app.logger().warn("WhatsApp welcome: no approved template", "user", e.auth.id);
    return e.json(200, { ok: false, reason: "no_template" });
  }

  const ctx = {
    first_name: firstName(user.getString("name")),
    user_name:  user.getString("name") || "there",
    app_link:   getSetting("app_url") || "https://app.sihatdarimula.my",
  };
  const res = sendTemplate(phoneId, token, version, formatPhone(phone),
    tpl.getString("meta_template_name"), tpl.getString("language_code"), resolveVars(tpl.getString("variables"), ctx));

  if (res.statusCode >= 200 && res.statusCode < 300) {
    $app.logger().info("WhatsApp welcome sent", "user", e.auth.id);
    return e.json(200, { ok: true });
  }
  $app.logger().warn("WhatsApp welcome failed", "user", e.auth.id, "status", res.statusCode, "body", res.raw);
  return e.json(200, { ok: false, reason: "send_failed" }); // Always 200 — don't block frontend
});


// ─── 2. Enrolment Confirmation ──────────────────────────────────────────────────
// Fires automatically whenever an enrollment record is created.

onRecordAfterCreateSuccess((e) => {
  try {
    function getSetting(key) {
      try { return $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key }).getString("value"); }
      catch (_) { return ""; }
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

    const phoneId = getSetting("whatsapp_phone_number_id");
    const token   = getSetting("whatsapp_access_token");
    if (!phoneId || !token) { e.next(); return; }
    const version = getSetting("whatsapp_api_version") || "v20.0";

    const userId = e.record.getString("user");
    const user   = $app.findRecordById("users", userId);
    const phone  = user.getString("phone");
    if (!phone) { e.next(); return; }

    // Respect opt-out (treat missing preference as opted-in)
    try {
      const pref = $app.findFirstRecordByFilter("notification_preferences", "user = {:u}", { u: userId });
      if (!pref.getBool("whatsapp_enabled")) { e.next(); return; }
    } catch (_) {}

    const langMap  = { en: "en", ms: "ms", zh: "zh_CN" };
    const langCode = langMap[user.getString("language")] || "en";

    let tpl = null;
    try {
      tpl = $app.findFirstRecordByFilter("whatsapp_templates",
        "trigger_event = 'course_enrollment' && language_code = {:lc} && approval_status = 'approved' && is_active = true",
        { lc: langCode });
    } catch (_) {}
    if (!tpl && langCode !== "en") {
      try {
        tpl = $app.findFirstRecordByFilter("whatsapp_templates",
          "trigger_event = 'course_enrollment' && language_code = 'en' && approval_status = 'approved' && is_active = true", {});
      } catch (_) {}
    }
    if (!tpl) { e.next(); return; }

    const courseId = e.record.getString("course");
    let courseName = "";
    try {
      const course = $app.findRecordById("courses", courseId);
      const langSuffix = user.getString("language");
      courseName = (langSuffix && langSuffix !== "en" ? course.getString("title_" + langSuffix) : "")
                   || course.getString("title_en") || "";
    } catch (_) {}

    const ctx = {
      first_name:  firstName(user.getString("name")),
      user_name:   user.getString("name") || "there",
      course_name: courseName,
      app_link:    getSetting("app_url") || "https://app.sihatdarimula.my",
    };
    const res = sendTemplate(phoneId, token, version, formatPhone(phone),
      tpl.getString("meta_template_name"), tpl.getString("language_code"), resolveVars(tpl.getString("variables"), ctx));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      $app.logger().info("WhatsApp enrolment sent", "user", userId, "course", courseId);
    } else {
      $app.logger().warn("WhatsApp enrolment failed", "user", userId, "status", res.statusCode, "body", res.raw);
    }
  } catch (err) {
    $app.logger().error("WhatsApp enrolment hook error", "error", String(err));
  }
  e.next();
}, "enrollments");


// ─── 3. Course Completion ───────────────────────────────────────────────────────
// Fires on every enrollment update; guards against duplicates by checking
// that completed_at was set within the last 5 minutes.

onRecordAfterUpdateSuccess((e) => {
  try {
    if (!e.record.getBool("is_completed")) { e.next(); return; }
    const completedAtStr = e.record.getString("completed_at");
    if (!completedAtStr) { e.next(); return; }
    const completedTime = new Date(completedAtStr.replace(" ", "T")).getTime();
    if (isNaN(completedTime) || Date.now() - completedTime > 5 * 60 * 1000) { e.next(); return; }

    function getSetting(key) {
      try { return $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key }).getString("value"); }
      catch (_) { return ""; }
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

    const phoneId = getSetting("whatsapp_phone_number_id");
    const token   = getSetting("whatsapp_access_token");
    if (!phoneId || !token) { e.next(); return; }
    const version = getSetting("whatsapp_api_version") || "v20.0";

    const userId = e.record.getString("user");
    const user   = $app.findRecordById("users", userId);
    const phone  = user.getString("phone");
    if (!phone) { e.next(); return; }

    try {
      const pref = $app.findFirstRecordByFilter("notification_preferences", "user = {:u}", { u: userId });
      if (!pref.getBool("whatsapp_enabled")) { e.next(); return; }
    } catch (_) {}

    const langMap  = { en: "en", ms: "ms", zh: "zh_CN" };
    const langCode = langMap[user.getString("language")] || "en";

    let tpl = null;
    try {
      tpl = $app.findFirstRecordByFilter("whatsapp_templates",
        "trigger_event = 'course_completion' && language_code = {:lc} && approval_status = 'approved' && is_active = true",
        { lc: langCode });
    } catch (_) {}
    if (!tpl && langCode !== "en") {
      try {
        tpl = $app.findFirstRecordByFilter("whatsapp_templates",
          "trigger_event = 'course_completion' && language_code = 'en' && approval_status = 'approved' && is_active = true", {});
      } catch (_) {}
    }
    if (!tpl) { e.next(); return; }

    const courseId = e.record.getString("course");
    let courseName = "";
    try {
      const course = $app.findRecordById("courses", courseId);
      const langSuffix = user.getString("language");
      courseName = (langSuffix && langSuffix !== "en" ? course.getString("title_" + langSuffix) : "")
                   || course.getString("title_en") || "";
    } catch (_) {}

    const ctx = {
      first_name:      firstName(user.getString("name")),
      user_name:       user.getString("name") || "there",
      course_name:     courseName,
      app_link:        getSetting("app_url") || "https://app.sihatdarimula.my",
      completion_date: new Date().toLocaleDateString("en-MY"),
    };
    const res = sendTemplate(phoneId, token, version, formatPhone(phone),
      tpl.getString("meta_template_name"), tpl.getString("language_code"), resolveVars(tpl.getString("variables"), ctx));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      $app.logger().info("WhatsApp completion sent", "user", userId, "course", courseId);
    } else {
      $app.logger().warn("WhatsApp completion failed", "user", userId, "status", res.statusCode, "body", res.raw);
    }
  } catch (err) {
    $app.logger().error("WhatsApp completion hook error", "error", String(err));
  }
  e.next();
}, "enrollments");


// ─── 4. Baby Milestone Reminders ───────────────────────────────────────────────
// Call this from a weekly cron job: POST /api/whatsapp/send-milestone-reminders
// Sends to children who reached 6w, 3m, 6m, 9m, or 12m milestones this week.

routerAdd("POST", "/api/whatsapp/send-milestone-reminders", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  const role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Admin access required." });

  function getSetting(key) {
    try { return $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key }).getString("value"); }
    catch (_) { return ""; }
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

  const phoneId = getSetting("whatsapp_phone_number_id");
  const token   = getSetting("whatsapp_access_token");
  const version = getSetting("whatsapp_api_version") || "v20.0";
  if (!phoneId || !token) return e.json(503, { error: "WhatsApp credentials not configured." });

  // Key milestone ages in weeks: 6w, 3m, 6m, 9m, 12m
  const MILESTONE_WEEKS = [6, 13, 26, 39, 52];
  const WEEK_MS  = 7 * 24 * 60 * 60 * 1000;
  const now      = Date.now();

  // Find children born within the last 14 months who are born (not due)
  const dobCutoff = new Date(now - 14 * 30 * 24 * 60 * 60 * 1000);
  const dobCutoffStr = dobCutoff.toISOString().replace("T", " ").slice(0, 23) + "Z";
  const children = $app.findRecordsByFilter(
    "children",
    "date_of_birth != '' && date_of_birth >= {:dob} && is_born = true",
    "", 0, 0, { dob: dobCutoffStr }
  );

  let sent = 0, skipped = 0, failed = 0;
  const results = [];

  for (const child of children) {
    try {
      const dobStr = child.getString("date_of_birth");
      if (!dobStr) { skipped++; continue; }
      const dobMs    = new Date(dobStr.replace(" ", "T")).getTime();
      if (isNaN(dobMs)) { skipped++; continue; }
      const ageMs    = now - dobMs;
      const ageWeeks = ageMs / WEEK_MS;

      // Is this child at a milestone week right now?
      const atMilestone = MILESTONE_WEEKS.find(mw => ageWeeks >= mw && ageWeeks < mw + 1);
      if (!atMilestone) { skipped++; continue; }

      // Dedup: check notification_queue for a growth_reminder sent in the past 7 days for this child
      const windowStart = new Date(now - WEEK_MS).toISOString().replace("T", " ").slice(0, 23) + "Z";
      let alreadySent = false;
      try {
        $app.findFirstRecordByFilter("notification_queue",
          "child = {:c} && type = 'growth_reminder' && channel = 'whatsapp' && created >= {:ws}",
          { c: child.id, ws: windowStart });
        alreadySent = true;
      } catch (_) {}
      if (alreadySent) { skipped++; continue; }

      const userId = child.getString("user");
      const user   = $app.findRecordById("users", userId);
      const phone  = user.getString("phone");
      if (!phone) { skipped++; continue; }

      try {
        const pref = $app.findFirstRecordByFilter("notification_preferences", "user = {:u}", { u: userId });
        if (!pref.getBool("whatsapp_enabled")) { skipped++; continue; }
      } catch (_) {}

      const langMap  = { en: "en", ms: "ms", zh: "zh_CN" };
      const langCode = langMap[user.getString("language")] || "en";

      let tpl = null;
      try {
        tpl = $app.findFirstRecordByFilter("whatsapp_templates",
          "trigger_event = 'milestone_reminder' && language_code = {:lc} && approval_status = 'approved' && is_active = true",
          { lc: langCode });
      } catch (_) {}
      if (!tpl && langCode !== "en") {
        try {
          tpl = $app.findFirstRecordByFilter("whatsapp_templates",
            "trigger_event = 'milestone_reminder' && language_code = 'en' && approval_status = 'approved' && is_active = true", {});
        } catch (_) {}
      }
      if (!tpl) { skipped++; continue; }

      const ageMonths = Math.round(atMilestone / 4.33);
      const ageLabel  = atMilestone < 12
        ? `${atMilestone} weeks`
        : `${ageMonths} months`;

      const ctx = {
        first_name:     firstName(user.getString("name")),
        user_name:      user.getString("name") || "there",
        child_name:     child.getString("name") || "your little one",
        child_age:      ageLabel,
        milestone_name: `${ageMonths}-month milestone`,
        app_link:       getSetting("app_url") || "https://app.sihatdarimula.my",
      };
      const res = sendTemplate(phoneId, token, version, formatPhone(phone),
        tpl.getString("meta_template_name"), tpl.getString("language_code"), resolveVars(tpl.getString("variables"), ctx));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Log to notification_queue for deduplication and audit
        const qCol = $app.findCollectionByNameOrId("notification_queue");
        const qRec = new Record(qCol);
        qRec.set("user",    userId);
        qRec.set("child",   child.id);
        qRec.set("channel", "whatsapp");
        qRec.set("type",    "growth_reminder");
        qRec.set("status",  "sent");
        qRec.set("phone",   phone);
        qRec.set("message", `Milestone reminder — ${ageLabel}`);
        qRec.set("sent_at", new Date().toISOString().replace("T", " ").slice(0, 23) + "Z");
        $app.save(qRec);
        sent++;
        results.push({ child: child.id, age: ageLabel, status: "sent" });
        $app.logger().info("WhatsApp milestone sent", "user", userId, "child", child.id, "age", ageLabel);
      } else {
        failed++;
        results.push({ child: child.id, age: ageLabel, status: "failed", code: res.statusCode });
        $app.logger().warn("WhatsApp milestone failed", "user", userId, "status", res.statusCode, "body", res.raw);
      }
    } catch (err) {
      failed++;
      $app.logger().error("WhatsApp milestone error", "child", child.id, "error", String(err));
    }
  }

  return e.json(200, { ok: true, checked: children.length, sent, skipped, failed, results });
});


// ─── 5. Admin Meta Blast ────────────────────────────────────────────────────────
// Sends a blast to all opted-in users using a specific approved template.
// Body: { trigger_event: "course_announcement"|"promotional_blast", context: { course_name: "..." } }

routerAdd("POST", "/api/admin/whatsapp/meta-blast", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  const role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Admin access required." });

  function getSetting(key) {
    try { return $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: key }).getString("value"); }
    catch (_) { return ""; }
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

  const body         = e.requestInfo().body;
  const triggerEvent = String(body.trigger_event || "").trim();
  const extraCtx     = body.context || {};
  if (!triggerEvent) return e.json(400, { error: "trigger_event is required." });

  const phoneId = getSetting("whatsapp_phone_number_id");
  const token   = getSetting("whatsapp_access_token");
  const version = getSetting("whatsapp_api_version") || "v20.0";
  if (!phoneId || !token) return e.json(503, { error: "WhatsApp credentials not configured." });

  const users = $app.findRecordsByFilter("users", "phone != ''", "", 0, 0, {});

  let sent = 0, skipped = 0, failed = 0;
  const results = [];

  for (const user of users) {
    try {
      const phone = user.getString("phone");
      if (!phone) { skipped++; continue; }

      try {
        const pref = $app.findFirstRecordByFilter("notification_preferences", "user = {:u}", { u: user.id });
        if (!pref.getBool("whatsapp_enabled")) { skipped++; continue; }
      } catch (_) {}

      const langMap  = { en: "en", ms: "ms", zh: "zh_CN" };
      const langCode = langMap[user.getString("language")] || "en";

      let tpl = null;
      try {
        tpl = $app.findFirstRecordByFilter("whatsapp_templates",
          "trigger_event = {:ev} && language_code = {:lc} && approval_status = 'approved' && is_active = true",
          { ev: triggerEvent, lc: langCode });
      } catch (_) {}
      if (!tpl && langCode !== "en") {
        try {
          tpl = $app.findFirstRecordByFilter("whatsapp_templates",
            "trigger_event = {:ev} && language_code = 'en' && approval_status = 'approved' && is_active = true",
            { ev: triggerEvent });
        } catch (_) {}
      }
      if (!tpl) { skipped++; continue; }

      const ctx = {
        first_name: firstName(user.getString("name")),
        user_name:  user.getString("name") || "there",
        app_link:   getSetting("app_url") || "https://app.sihatdarimula.my",
        ...extraCtx, // Caller can pass course_name, course_description, etc.
      };
      const res = sendTemplate(phoneId, token, version, formatPhone(phone),
        tpl.getString("meta_template_name"), tpl.getString("language_code"), resolveVars(tpl.getString("variables"), ctx));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        sent++;
        results.push({ user: user.id, status: "sent" });
      } else {
        failed++;
        results.push({ user: user.id, status: "failed", code: res.statusCode });
        $app.logger().warn("WhatsApp blast failed", "user", user.id, "status", res.statusCode);
      }
    } catch (err) {
      failed++;
      $app.logger().error("WhatsApp blast error", "user", user.id, "error", String(err));
    }
  }

  $app.logger().info("WhatsApp meta blast done", "event", triggerEvent, "sent", sent, "failed", failed);
  return e.json(200, { ok: true, sent, skipped, failed, results });
});
