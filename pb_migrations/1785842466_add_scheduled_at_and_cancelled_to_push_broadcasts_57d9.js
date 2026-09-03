migrate((app) => {
  const col = app.findCollectionByNameOrId("push_broadcasts")

  // Add scheduled_at date field
  col.fields.add(new DateField({ name: "scheduled_at" }))

  // Add "cancelled" to status options
  const statusField = col.fields.getByName("status")
  statusField.values = ["sent", "failed", "pending", "cancelled"]
  statusField.maxSelect = 1

  app.save(col)
}, (app) => {
  const col = app.findCollectionByNameOrId("push_broadcasts")
  col.fields.removeByName("scheduled_at")
  const statusField = col.fields.getByName("status")
  statusField.values = ["sent", "failed", "pending"]
  statusField.maxSelect = 1
  app.save(col)
})
