migrate((app) => {
  const queue = app.findCollectionByNameOrId("notification_queue")
  queue.listRule = "user = @request.auth.id"
  queue.viewRule = "user = @request.auth.id"
  app.save(queue)
}, (app) => {
  const queue = app.findCollectionByNameOrId("notification_queue")
  queue.listRule = null
  queue.viewRule = null
  app.save(queue)
})