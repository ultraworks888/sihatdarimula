migrate((app) => {
  const collection = app.findCollectionByNameOrId("push_broadcasts");
  collection.fields.add(new TextField({ name: "idempotency_key", max: 36 }));
  collection.fields.add(new TextField({ name: "request_hash", max: 64, hidden: true }));
  collection.fields.add(new DateField({ name: "dispatch_started_at" }));
  collection.fields.add(new DateField({ name: "next_attempt_at", hidden: true }));
  collection.fields.add(new NumberField({
    name: "dispatch_attempts", min: 0, max: 3, onlyInt: true,
  }));
  const status = collection.fields.getByName("status");
  status.values = ["sent", "failed", "pending", "cancelled", "processing", "review_required"];
  collection.addIndex(
    "idx_push_broadcast_idempotency",
    true,
    "idempotency_key",
    "idempotency_key != ''"
  );
  collection.addIndex(
    "idx_push_broadcast_dispatch_queue",
    false,
    "status, scheduled_at, dispatch_started_at",
    ""
  );
  app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("push_broadcasts");
  collection.removeIndex("idx_push_broadcast_dispatch_queue");
  collection.removeIndex("idx_push_broadcast_idempotency");
  collection.fields.removeByName("dispatch_attempts");
  collection.fields.removeByName("dispatch_started_at");
  collection.fields.removeByName("next_attempt_at");
  collection.fields.removeByName("request_hash");
  collection.fields.removeByName("idempotency_key");
  const status = collection.fields.getByName("status");
  status.values = ["sent", "failed", "pending", "cancelled"];
  app.save(collection);
});
