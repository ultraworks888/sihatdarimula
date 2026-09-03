migrate((app) => {
  const usersId = app.findCollectionByNameOrId("users").id

  const broadcasts = new Collection({
    name: "push_broadcasts",
    type: "base",
    listRule:   "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule:   "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "text",     name: "title",           required: true, max: 100 },
      { type: "text",     name: "message",          required: true, max: 300 },
      { type: "relation", name: "sent_by",          collectionId: usersId, maxSelect: 1 },
      { type: "text",     name: "target",           max: 20 },
      { type: "text",     name: "url",              max: 500 },
      { type: "select",   name: "status",           values: ["sent", "failed", "pending"], maxSelect: 1 },
      { type: "number",   name: "recipient_count" },
      { type: "text",     name: "onesignal_id",     max: 200 },
      { type: "autodate", name: "created",          onCreate: true },
      { type: "autodate", name: "updated",          onCreate: true, onUpdate: true },
    ],
  })
  app.save(broadcasts)
}, (app) => {
  const col = app.findCollectionByNameOrId("push_broadcasts")
  app.delete(col)
})
