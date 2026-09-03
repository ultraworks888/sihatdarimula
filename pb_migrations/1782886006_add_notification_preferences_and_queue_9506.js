migrate((app) => {
  const usersId = app.findCollectionByNameOrId("users").id
  const childrenId = app.findCollectionByNameOrId("children").id

  // Notification preferences per user
  const prefs = new Collection({
    name: "notification_preferences",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: null,
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "bool", name: "sms_enabled" },
      { type: "bool", name: "whatsapp_enabled" },
      { type: "bool", name: "in_app_enabled" },
      { type: "bool", name: "vaccine_reminders" },
      { type: "bool", name: "content_updates" },
      { type: "bool", name: "growth_reminders" },
      { type: "bool", name: "feeding_reminders" },
      { type: "autodate", name: "created", onCreate: true },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(prefs)

  // Notification queue for external Brevo service to consume
  const queue = new Collection({
    name: "notification_queue",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "child", collectionId: childrenId, maxSelect: 1, cascadeDelete: true },
      { type: "select", name: "channel", required: true, values: ["sms", "whatsapp", "in_app"], maxSelect: 1 },
      { type: "select", name: "type", required: true, values: ["vaccine_reminder", "content_update", "growth_reminder", "feeding_reminder", "otp"], maxSelect: 1 },
      { type: "select", name: "status", required: true, values: ["pending", "sent", "failed", "cancelled"], maxSelect: 1 },
      { type: "text", name: "phone", max: 20 },
      { type: "text", name: "title", max: 300 },
      { type: "text", name: "message", required: true, max: 2000 },
      { type: "text", name: "template_id", max: 100 },
      { type: "json", name: "template_params" },
      { type: "date", name: "scheduled_at" },
      { type: "date", name: "sent_at" },
      { type: "text", name: "error_message", max: 1000 },
      { type: "text", name: "external_id", max: 200 },
      { type: "autodate", name: "created", onCreate: true },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(queue)

  // In-app notifications (user-readable)
  const notifs = new Collection({
    name: "notifications",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: null,
    updateRule: "user = @request.auth.id",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "child", collectionId: childrenId, maxSelect: 1, cascadeDelete: true },
      { type: "select", name: "type", required: true, values: ["vaccine_reminder", "content_update", "growth_reminder", "feeding_reminder", "system"], maxSelect: 1 },
      { type: "text", name: "title", required: true, max: 300 },
      { type: "text", name: "message", required: true, max: 2000 },
      { type: "bool", name: "is_read" },
      { type: "autodate", name: "created", onCreate: true },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(notifs)
}, (app) => {
  const notifs = app.findCollectionByNameOrId("notifications")
  app.delete(notifs)
  const queue = app.findCollectionByNameOrId("notification_queue")
  app.delete(queue)
  const prefs = app.findCollectionByNameOrId("notification_preferences")
  app.delete(prefs)
})
