migrate((app) => {
  const otps = new Collection({
    name: "phone_otps",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "text", name: "phone", required: true, max: 20 },
      { type: "text", name: "code", required: true, max: 10 },
      { type: "date", name: "expires_at" },
      { type: "bool", name: "is_used" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false }
    ]
  });
  app.save(otps);
}, (app) => {
  try { app.delete(app.findCollectionByNameOrId("phone_otps")); } catch(_) {}
});
