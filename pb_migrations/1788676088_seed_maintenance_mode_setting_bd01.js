// Reconciles the known applied filename/effect; PB v0.29.3 tracks filenames,
// not content hashes. An existing value (especially "true") is never reset.
migrate((app) => {
  const rows = app.findRecordsByFilter(
    "lms_settings", "key = {:key}", "", 1, 0, { key: "maintenance_mode" }
  );
  if (rows.length) return;
  const record = new Record(app.findCollectionByNameOrId("lms_settings"));
  record.set("key", "maintenance_mode");
  record.set("value", "false");
  app.save(record);
}, (app) => {
  // Preserve operator state on rollback. We cannot know whether this row was
  // pre-existing or seeded here. Removing it would also activate fail-closed.
});
