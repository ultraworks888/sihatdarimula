migrate((app) => {
  const col = new Collection({
    name:       "ai_settings",
    type:       "base",
    listRule:   null,
    viewRule:   null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "text", name: "gemini_key", max: 500 }
    ]
  });
  app.save(col);

  // Seed one empty record so the hook can always find and update it
  const r = new Record(col);
  r.set("gemini_key", "");
  app.save(r);
}, (app) => {
  const col = app.findCollectionByNameOrId("ai_settings");
  app.delete(col);
});
