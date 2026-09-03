migrate((app) => {
  const prefs = app.findCollectionByNameOrId("notification_preferences")
  prefs.fields.add(new BoolField({ name: "push_enabled" }))
  app.save(prefs)
}, (app) => {
  const prefs = app.findCollectionByNameOrId("notification_preferences")
  prefs.fields.removeByName("push_enabled")
  app.save(prefs)
})
