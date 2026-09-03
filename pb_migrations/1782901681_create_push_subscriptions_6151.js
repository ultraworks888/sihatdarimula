migrate((app) => {
  const usersId = app.findCollectionByNameOrId("users").id

  const col = new Collection({
    name: "push_subscriptions",
    type: "base",
    listRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: null,
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "text",   name: "endpoint",   required: true, max: 1000 },
      { type: "text",   name: "p256dh",     required: true, max: 300 },
      { type: "text",   name: "auth",       required: true, max: 100 },
      { type: "text",   name: "user_agent", max: 500 },
      { type: "select", name: "platform",   values: ["android", "ios", "desktop", "unknown"], maxSelect: 1 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
  })
  app.save(col)
}, (app) => {
  const col = app.findCollectionByNameOrId("push_subscriptions")
  app.delete(col)
})