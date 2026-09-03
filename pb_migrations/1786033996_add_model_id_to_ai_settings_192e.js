migrate((app) => {
  const col = app.findCollectionByNameOrId("ai_settings");
  col.fields.add(new TextField({ name: "model_id", max: 100 }));
  app.save(col);

  // Seed the default model on the existing record
  try {
    const r = app.findFirstRecordByFilter("ai_settings", "id != ''");
    r.set("model_id", "gemini-2.5-flash");
    app.save(r);
  } catch (_) {}
}, (app) => {
  const col = app.findCollectionByNameOrId("ai_settings");
  col.fields.removeByName("model_id");
  app.save(col);
});
