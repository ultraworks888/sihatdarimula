/**
 * Migration: create_whatsapp_webhook_events
 *
 * Creates the whatsapp_webhook_events collection for Phase B inbound webhook recording.
 *
 * Security model (matches notification_queue / push_broadcasts conventions):
 *   - createRule / updateRule / deleteRule: null (locked — only hook server-side code writes)
 *   - listRule / viewRule: admin and superadmin only
 *
 * Race-safe deduplication:
 *   A partial UNIQUE index on dedup_key (WHERE dedup_key != '') is created as part of
 *   the collection definition via collection.indexes. This is managed by PocketBase —
 *   the index is automatically dropped when the collection is deleted in the down migration.
 *   SQLite partial indexes (WHERE clause) are supported since SQLite 3.8.0 (2013).
 *
 *   dedup_key values:
 *     Inbound messages:  "msg:{wa_message_id}"
 *     Status updates:    "st:{wa_message_id}:{delivery_status}"
 *     Unsupported:       "unsup:{entry_id}:{field}" where stable, otherwise ""
 *     Empty string:      excluded from uniqueness enforcement (truly unidentifiable events)
 */

migrate((app) => {
  const usersId = app.findCollectionByNameOrId("users").id;

  const collection = new Collection({
    name: "whatsapp_webhook_events",
    type: "base",
    listRule:   "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule:   "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    indexes: [
      "CREATE UNIQUE INDEX idx_whatsapp_webhook_dedup ON whatsapp_webhook_events(dedup_key) WHERE dedup_key != ''"
    ],
    fields: [
      // event_type: the category of WhatsApp webhook event
      //   message       — inbound message from a user
      //   status_update — delivery status update for an outbound message
      //   unsupported   — valid WhatsApp payload structure but not yet handled
      { type: "select", name: "event_type", required: true,
        values: ["message", "status_update", "unsupported"], maxSelect: 1 },

      // direction: flow direction relative to the app
      //   inbound — message arriving from a user
      //   status  — delivery receipt for our outbound message
      { type: "select", name: "direction",
        values: ["inbound", "status"], maxSelect: 1 },

      // from_phone: sender phone for inbound messages;
      //             recipient_id for status updates (phone that received our message)
      { type: "text", name: "from_phone", max: 30 },

      // wa_message_id: Meta's wamid string (e.g. "wamid.HBgN...")
      //   For messages: the inbound message ID
      //   For statuses: the original outbound message ID whose status changed
      { type: "text", name: "wa_message_id", max: 200 },

      // dedup_key: composite idempotency key (see migration header)
      //   Partial UNIQUE index enforces uniqueness where non-empty
      { type: "text", name: "dedup_key", max: 200 },

      // status: our internal processing state (not Meta's delivery status)
      //   received  — event arrived and was recorded; no further processing yet
      //   processed — business logic has been applied (Phase C+)
      //   ignored   — unsupported event type; recorded but not acted on
      //   error     — processing attempted but failed
      { type: "select", name: "status",
        values: ["received", "processed", "ignored", "error"], maxSelect: 1 },

      // matched_user: Phase C+ only — not populated in Phase B
      { type: "relation", name: "matched_user",
        collectionId: usersId, maxSelect: 1 },

      // payload: the relevant portion of the Meta event for audit and debugging
      //   Access is restricted to admin/superadmin by collection rules
      { type: "json", name: "payload" },

      // error_detail: human-readable error description for error-status records
      { type: "text", name: "error_detail", max: 2000 },

      // created: set once on insert by PocketBase
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
    ],
  });

  app.save(collection);

}, (app) => {
  // Down: delete the collection and all its records.
  // The UNIQUE index is automatically dropped with the collection.
  const collection = app.findCollectionByNameOrId("whatsapp_webhook_events");
  app.delete(collection);
});
