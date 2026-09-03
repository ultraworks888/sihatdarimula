migrate((app) => {
  // 1. Add role field to users
  const users = app.findCollectionByNameOrId("users")
  users.fields.add(new SelectField({
    name: "role",
    values: ["user", "admin", "superadmin"],
    maxSelect: 1,
  }))
  users.listRule = "id = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  users.viewRule = "id = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  users.updateRule = "id = @request.auth.id || @request.auth.role = 'superadmin'"
  users.deleteRule = "id = @request.auth.id || @request.auth.role = 'superadmin'"
  app.save(users)

  // 2. Allow admins to CRUD articles
  const articles = app.findCollectionByNameOrId("articles")
  articles.createRule = "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  articles.updateRule = "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  articles.deleteRule = "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  app.save(articles)

  // 3. Allow admins to list children for analytics
  const children = app.findCollectionByNameOrId("children")
  children.listRule = "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  children.viewRule = "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  app.save(children)

  // 4. Allow admins to see all notification queue entries
  const queue = app.findCollectionByNameOrId("notification_queue")
  queue.listRule = "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  queue.viewRule = "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  app.save(queue)

  // 5. Allow admins to see all growth logs for analytics
  const growth = app.findCollectionByNameOrId("growth_logs")
  growth.listRule = "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'"
  app.save(growth)

}, (app) => {
  const users = app.findCollectionByNameOrId("users")
  users.fields.removeByName("role")
  users.listRule = "id = @request.auth.id"
  users.viewRule = "id = @request.auth.id"
  users.updateRule = "id = @request.auth.id"
  users.deleteRule = "id = @request.auth.id"
  app.save(users)

  const articles = app.findCollectionByNameOrId("articles")
  articles.createRule = null
  articles.updateRule = null
  articles.deleteRule = null
  app.save(articles)

  const children = app.findCollectionByNameOrId("children")
  children.listRule = "user = @request.auth.id"
  children.viewRule = "user = @request.auth.id"
  app.save(children)

  const queue = app.findCollectionByNameOrId("notification_queue")
  queue.listRule = "user = @request.auth.id"
  queue.viewRule = "user = @request.auth.id"
  app.save(queue)

  const growth = app.findCollectionByNameOrId("growth_logs")
  growth.listRule = "user = @request.auth.id"
  app.save(growth)
})