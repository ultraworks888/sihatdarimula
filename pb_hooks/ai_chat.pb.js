/**
 * AI Parenting Chatbot — Sihat Dari Mula
 * All helpers must be defined INSIDE each routerAdd callback.
 */

// ── User chat endpoint ────────────────────────────────────────────────────────

routerAdd("POST", "/api/chat/ask", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });

  function getAISettings() {
    try {
      var r = $app.findFirstRecordByFilter("ai_settings", "id != ''");
      return {
        key:   r.getString("gemini_key"),
        model: r.getString("model_id") || "gemini-3.5-flash-lite",
      };
    } catch (err) {
      $app.logger().error("getAISettings failed", "err", String(err));
      return { key: "", model: "gemini-3.5-flash-lite" };
    }
  }

  var SYSTEM_PROMPT =
    "You are a caring parenting assistant for Sihat Dari Mula, a Malaysian maternal and child health app. " +
    "Help mothers with questions about pregnancy, baby development, nutrition, breastfeeding, and child wellbeing only. " +
    "Keep answers practical and under 150 words. " +
    "For any medical concerns or emergencies, always advise the user to consult a doctor immediately. " +
    "Do not answer questions unrelated to parenting or child health. " +
    "Respond in the same language the user writes in — Bahasa Malaysia, Chinese, or English.";

  var settings = getAISettings();
  if (!settings.key) {
    return e.json(503, {
      error:   "not_configured",
      message: "AI assistant is not yet configured. Please add your Gemini API key in Admin → AI Chatbot.",
    });
  }

  var info    = e.requestInfo();
  var message = String(info.body.message || "").trim();
  if (!message) return e.json(400, { error: "message_required" });

  var rawHistory = Array.isArray(info.body.history) ? info.body.history : [];
  var contents   = [];
  var recent     = rawHistory.slice(-6);
  for (var i = 0; i < recent.length; i++) {
    var msg  = recent[i];
    var role = msg.role === "assistant" ? "model" : "user";
    var text = String(msg.content || "").trim();
    if (text) contents.push({ role: role, parts: [{ text: text }] });
  }
  contents.push({ role: "user", parts: [{ text: message }] });

  var payload = {
    systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
    contents: contents,
    generationConfig: { maxOutputTokens: 400, temperature: 0.7 },
  };

  var modelId = settings.model;
  var res;
  try {
    res = $http.send({
      url:     "https://generativelanguage.googleapis.com/v1beta/models/" + modelId + ":generateContent?key=" + settings.key,
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body:    JSON.stringify(payload),
      timeout: 30,
    });
  } catch (httpErr) {
    $app.logger().error("Gemini HTTP send failed", "err", String(httpErr));
    return e.json(500, {
      error:   "http_error",
      message: "Could not reach Gemini API: " + String(httpErr),
    });
  }

  $app.logger().info("Gemini response", "model", modelId, "status", res.statusCode);

  if (res.statusCode !== 200) {
    $app.logger().error("Gemini non-200", "status", res.statusCode, "body", res.raw);
    return e.json(500, {
      error:   "ai_error",
      message: "Gemini error (" + res.statusCode + "): " + res.raw.slice(0, 400),
    });
  }

  try {
    var answer = res.json.candidates[0].content.parts[0].text;
    return e.json(200, { answer: answer });
  } catch (parseErr) {
    $app.logger().error("Gemini parse failed", "raw", res.raw, "err", String(parseErr));
    return e.json(500, {
      error:   "parse_failed",
      message: "Unexpected AI response: " + String(parseErr),
    });
  }
});

// ── Admin status check ────────────────────────────────────────────────────────

routerAdd("GET", "/api/admin/ai/config", (e) => {
  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  var role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  try {
    var r      = $app.findFirstRecordByFilter("ai_settings", "id != ''");
    var val    = r.getString("gemini_key");
    var model  = r.getString("model_id") || "gemini-3.5-flash-lite";
    var masked = val ? val.slice(0, 8) + "..." : "";
    return e.json(200, { configured: !!val, masked: masked, model: model });
  } catch (err) {
    $app.logger().error("ai config status failed", "err", String(err));
    return e.json(200, { configured: false, masked: "", model: "" });
  }
});
