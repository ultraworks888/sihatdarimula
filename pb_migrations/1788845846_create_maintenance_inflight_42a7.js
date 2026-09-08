// Persistent admission evidence. No TTL/automatic stale-record cleanup: a dead
// process must leave drain blocked until an operator proves it cannot resume.
migrate((app) => {
  try {
    app.findCollectionByNameOrId("maintenance_inflight");
    return;
  } catch (_) { /* create once */ }
  const collection = new Collection({
    name: "maintenance_inflight", type: "base",
    listRule: null, viewRule: null, createRule: null, updateRule: null, deleteRule: null,
  });
  collection.fields.add(new SelectField({ name: "kind", required: true, maxSelect: 1,
    values: ["http", "builtin", "cron", "event", "mail"] }));
  collection.fields.add(new AutodateField({ name: "admitted_at", onCreate: true, onUpdate: false }));
  app.save(collection);
}, (app) => {
  // Preserve both schema and records. Deleting even one stale record could
  // manufacture a false drained state. A later reapply is intentionally safe.
});
