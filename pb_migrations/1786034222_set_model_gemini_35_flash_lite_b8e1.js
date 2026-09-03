migrate((app) => {
  try {
    const r = app.findFirstRecordByFilter("ai_settings", "id != ''");
    r.set("model_id", "gemini-3.5-flash-lite");
    app.save(r);
  } catch (_) {}
}, (app) => {
  try {
    const r = app.findFirstRecordByFilter("ai_settings", "id != ''");
    r.set("model_id", "gemini-2.5-flash");
    app.save(r);
  } catch (_) {}
});
