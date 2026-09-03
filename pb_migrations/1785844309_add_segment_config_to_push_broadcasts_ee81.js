migrate((app) => {
  const col = app.findCollectionByNameOrId("push_broadcasts")
  col.fields.add(new JSONField({ name: "segment_config" }))
  app.save(col)
}, (app) => {
  const col = app.findCollectionByNameOrId("push_broadcasts")
  col.fields.removeByName("segment_config")
  app.save(col)
})
