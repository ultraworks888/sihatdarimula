migrate((app) => {
  const usersId = app.findCollectionByNameOrId("users").id;

  // 1. COURSES
  const courses = new Collection({
    name: "courses",
    type: "base",
    listRule: "is_published = true || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule: "is_published = true || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    updateRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    deleteRule: "@request.auth.role = 'superadmin'",
    fields: [
      { type: "text", name: "title_en", required: true, max: 200 },
      { type: "text", name: "title_ms", max: 200 },
      { type: "text", name: "title_zh", max: 200 },
      { type: "text", name: "description_en", max: 2000 },
      { type: "text", name: "description_ms", max: 2000 },
      { type: "text", name: "description_zh", max: 2000 },
      { type: "file", name: "thumbnail", maxSelect: 1 },
      { type: "select", name: "category", values: ["parenting","nutrition","development","wellbeing","breastfeeding","pregnancy"], maxSelect: 1 },
      { type: "select", name: "level", values: ["beginner","intermediate","advanced"], maxSelect: 1 },
      { type: "bool", name: "is_published" },
      { type: "bool", name: "is_featured" },
      { type: "bool", name: "has_modules" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  });
  app.save(courses);

  // 2. COURSE MODULES
  const coursesId = app.findCollectionByNameOrId("courses").id;
  const modules = new Collection({
    name: "course_modules",
    type: "base",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    updateRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    deleteRule: "@request.auth.role = 'superadmin'",
    fields: [
      { type: "relation", name: "course", required: true, collectionId: coursesId, maxSelect: 1, cascadeDelete: true },
      { type: "text", name: "title_en", required: true, max: 200 },
      { type: "text", name: "title_ms", max: 200 },
      { type: "text", name: "title_zh", max: 200 },
      { type: "number", name: "order" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  });
  app.save(modules);

  // 3. LESSONS
  const modulesId = app.findCollectionByNameOrId("course_modules").id;
  const lessons = new Collection({
    name: "lessons",
    type: "base",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    updateRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    deleteRule: "@request.auth.role = 'superadmin'",
    fields: [
      { type: "relation", name: "course", required: true, collectionId: coursesId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "module", collectionId: modulesId, maxSelect: 1 },
      { type: "text", name: "title_en", required: true, max: 200 },
      { type: "text", name: "title_ms", max: 200 },
      { type: "text", name: "title_zh", max: 200 },
      { type: "text", name: "description_en", max: 1000 },
      { type: "text", name: "description_ms", max: 1000 },
      { type: "text", name: "description_zh", max: 1000 },
      { type: "text", name: "video_url", max: 500 },
      { type: "select", name: "video_provider", values: ["youtube","cloudflare_stream","bunny","direct"], maxSelect: 1 },
      { type: "number", name: "video_duration" },
      { type: "number", name: "completion_threshold" },
      { type: "bool", name: "has_quiz" },
      { type: "number", name: "order" },
      { type: "bool", name: "is_published" },
      { type: "bool", name: "is_free_preview" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  });
  app.save(lessons);

  // 4. LESSON QUIZZES
  const lessonsId = app.findCollectionByNameOrId("lessons").id;
  const quizzes = new Collection({
    name: "lesson_quizzes",
    type: "base",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    updateRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    deleteRule: "@request.auth.role = 'superadmin'",
    fields: [
      { type: "relation", name: "lesson", required: true, collectionId: lessonsId, maxSelect: 1, cascadeDelete: true },
      { type: "json", name: "questions" },
      { type: "number", name: "passing_score" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  });
  app.save(quizzes);

  // 5. ENROLLMENTS
  const enrollments = new Collection({
    name: "enrollments",
    type: "base",
    listRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    deleteRule: "user = @request.auth.id || @request.auth.role = 'superadmin'",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "course", required: true, collectionId: coursesId, maxSelect: 1, cascadeDelete: true },
      { type: "number", name: "progress_percent" },
      { type: "bool", name: "is_completed" },
      { type: "date", name: "completed_at" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  });
  app.save(enrollments);

  // 6. LESSON PROGRESS
  const lessonProgress = new Collection({
    name: "lesson_progress",
    type: "base",
    listRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: "@request.auth.id != '' && @request.body.user = @request.auth.id",
    updateRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    deleteRule: "user = @request.auth.id || @request.auth.role = 'superadmin'",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "lesson", required: true, collectionId: lessonsId, maxSelect: 1, cascadeDelete: true },
      { type: "relation", name: "course", required: true, collectionId: coursesId, maxSelect: 1, cascadeDelete: true },
      { type: "number", name: "watch_percent" },
      { type: "number", name: "watch_seconds" },
      { type: "number", name: "last_position" },
      { type: "bool", name: "is_video_complete" },
      { type: "bool", name: "is_quiz_passed" },
      { type: "number", name: "quiz_score" },
      { type: "bool", name: "is_completed" },
      { type: "date", name: "completed_at" },
      { type: "bool", name: "offline_pending" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  });
  app.save(lessonProgress);

  // 7. XAPI STATEMENTS
  const xapi = new Collection({
    name: "xapi_statements",
    type: "base",
    listRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule: "user = @request.auth.id || @request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: "@request.auth.id != ''",
    updateRule: null,
    deleteRule: "@request.auth.role = 'superadmin'",
    fields: [
      { type: "relation", name: "user", required: true, collectionId: usersId, maxSelect: 1, cascadeDelete: true },
      { type: "select", name: "verb", required: true, values: ["initialized","progressed","completed","paused","resumed","passed","failed","abandoned"], maxSelect: 1 },
      { type: "select", name: "object_type", values: ["lesson","course","quiz"], maxSelect: 1 },
      { type: "text", name: "object_id", max: 100 },
      { type: "bool", name: "result_completion" },
      { type: "bool", name: "result_success" },
      { type: "number", name: "result_score" },
      { type: "number", name: "result_duration" },
      { type: "number", name: "result_progress" },
      { type: "json", name: "context_json" },
      { type: "date", name: "statement_timestamp" },
      { type: "bool", name: "synced_offline" },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false }
    ]
  });
  app.save(xapi);

  // 8. LMS SETTINGS (for Brevo API key etc.)
  const settings = new Collection({
    name: "lms_settings",
    type: "base",
    listRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    viewRule: "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'",
    createRule: "@request.auth.role = 'superadmin'",
    updateRule: "@request.auth.role = 'superadmin'",
    deleteRule: "@request.auth.role = 'superadmin'",
    fields: [
      { type: "text", name: "key", required: true, max: 100 },
      { type: "text", name: "value", max: 2000 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true }
    ]
  });
  app.save(settings);

}, (app) => {
  for (const name of ["lms_settings","xapi_statements","lesson_progress","enrollments","lesson_quizzes","lessons","course_modules","courses"]) {
    try { app.delete(app.findCollectionByNameOrId(name)); } catch(_) {}
  }
});
