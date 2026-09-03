
migrate((app) => {
  const usersCol = app.findCollectionByNameOrId("users")
  const usersId = usersCol.id

  usersCol.fields.add(new TextField({ name: "name", max: 200 }))
  app.save(usersCol)

  // Children
  const children = new Collection({
    name: "children",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "text", name: "name", required: true, max: 100 },
      { type: "date", name: "date_of_birth" },
      { type: "date", name: "due_date" },
      { type: "select", name: "gender", values: ["boy", "girl", "other"], maxSelect: 1 },
      { type: "bool", name: "is_born" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(children)
  const childrenId = app.findCollectionByNameOrId("children").id

  // Growth logs
  const growthLogs = new Collection({
    name: "growth_logs",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "child", required: true, collectionId: childrenId, maxSelect: 1, cascadeDelete: true },
      { type: "date", name: "date", required: true },
      { type: "number", name: "weight_kg" },
      { type: "number", name: "height_cm" },
      { type: "number", name: "head_cm" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(growthLogs)

  // Nutrition logs
  const nutritionLogs = new Collection({
    name: "nutrition_logs",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "child", required: true, collectionId: childrenId, maxSelect: 1, cascadeDelete: true },
      { type: "date", name: "date", required: true },
      { type: "select", name: "type", required: true, values: ["breastfeed", "formula", "solid", "prenatal_diet"], maxSelect: 1 },
      { type: "number", name: "duration_min" },
      { type: "number", name: "volume_ml" },
      { type: "text", name: "food_name", max: 200 },
      { type: "text", name: "notes", max: 1000 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(nutritionLogs)

  // Activity logs
  const activityLogs = new Collection({
    name: "activity_logs",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "child", required: true, collectionId: childrenId, maxSelect: 1, cascadeDelete: true },
      { type: "date", name: "date", required: true },
      { type: "select", name: "type", required: true, values: ["tummy_time", "milestone", "playtime"], maxSelect: 1 },
      { type: "number", name: "duration_min" },
      { type: "text", name: "milestone_name", max: 200 },
      { type: "text", name: "notes", max: 1000 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(activityLogs)

  // Wellbeing logs (maternal)
  const wellbeingLogs = new Collection({
    name: "wellbeing_logs",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "date", name: "date", required: true },
      { type: "number", name: "mood_score" },
      { type: "number", name: "epds_score" },
      { type: "select", name: "type", required: true, values: ["mood", "epds"], maxSelect: 1 },
      { type: "text", name: "notes", max: 2000 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(wellbeingLogs)

  // Immunisation records
  const immunisations = new Collection({
    name: "immunisations",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id",
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "child", required: true, collectionId: childrenId, maxSelect: 1, cascadeDelete: true },
      { type: "text", name: "vaccine_name", required: true, max: 200 },
      { type: "number", name: "age_months" },
      { type: "bool", name: "is_completed" },
      { type: "date", name: "completed_date" },
      { type: "text", name: "notes", max: 500 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(immunisations)

  // Articles (public read, admin-only write)
  const articles = new Collection({
    name: "articles",
    type: "base",
    listRule: "",
    viewRule: "",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "text", name: "title", required: true, max: 300 },
      { type: "text", name: "summary", max: 500 },
      { type: "editor", name: "content" },
      { type: "select", name: "category", required: true, values: ["growth", "nutrition", "activity", "wellbeing", "immunisation", "pregnancy", "general"], maxSelect: 1 },
      { type: "number", name: "min_age_months" },
      { type: "number", name: "max_age_months" },
      { type: "bool", name: "is_pregnancy" },
      { type: "text", name: "reading_time", max: 20 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  })
  app.save(articles)

  // Bookmarks
  const articlesId = app.findCollectionByNameOrId("articles").id
  const bookmarks = new Collection({
    name: "bookmarks",
    type: "base",
    listRule: "user = @request.auth.id",
    viewRule: "user = @request.auth.id",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: null,
    deleteRule: "user = @request.auth.id",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "article", required: true, collectionId: articlesId, maxSelect: 1, cascadeDelete: true },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false }
    ]
  })
  app.save(bookmarks)

}, (app) => {
  const names = ["bookmarks", "articles", "immunisations", "wellbeing_logs", "activity_logs", "nutrition_logs", "growth_logs", "children"]
  for (const n of names) {
    try { app.delete(app.findCollectionByNameOrId(n)) } catch {}
  }
  const users = app.findCollectionByNameOrId("users")
  users.fields.removeByName("name")
  app.save(users)
})
