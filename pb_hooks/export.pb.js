// GET /api/admin/export?type=<type>
// Supported types: users | children | enrollments | learners | retention | progress
// Returns: { csv: string, filename: string, rows: number }
routerAdd("GET", "/api/admin/export", (e) => {

  // ── Auth ─────────────────────────────────────────────────────────────────
  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  const role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  const exportType = e.request.url.query().get("type") || "";

  // ── CSV helpers (inside callback per Goja scoping rules) ─────────────────
  const esc    = (v) => '"' + String(v == null ? "" : v).replace(/"/g, '""') + '"';
  const toCSV  = (rows) => rows.map((r) => r.map(esc).join(",")).join("\r\n");
  const dateOf = (s) => (s || "").slice(0, 10);

  const today  = new Date();
  const pad    = (n) => String(n).padStart(2, "0");
  const todayStr = today.getFullYear() + "-" + pad(today.getMonth()+1) + "-" + pad(today.getDate());

  // Date threshold formatter (PocketBase date string format)
  const fmtThreshold = (d) =>
    d.getFullYear() + "-" + pad(d.getMonth()+1) + "-" + pad(d.getDate()) + " 00:00:00.000Z";

  // ── Export: User Accounts ─────────────────────────────────────────────────
  if (exportType === "users") {
    const headers = ["Name", "Email", "Phone", "Language", "Role", "Joined Date"];
    const rows = [headers];
    try {
      const users = $app.findRecordsByFilter("users", "id != ''", "-created", 0, 0, {});
      for (const u of users) {
        rows.push([
          u.getString("name"),
          u.getString("email"),
          u.getString("phone"),
          u.getString("language"),
          u.getString("role") || "user",
          dateOf(u.getString("created")),
        ]);
      }
    } catch (err) { $app.logger().error("export/users", "err", String(err)); }
    return e.json(200, { csv: toCSV(rows), filename: "users_" + todayStr + ".csv", rows: rows.length - 1 });
  }

  // ── Export: Children & Milestones ─────────────────────────────────────────
  if (exportType === "children") {
    const headers = ["Parent Name", "Parent Email", "Child Name", "Gender", "Is Born",
      "Date of Birth", "Due Date", "Age (months)"];
    const rows = [headers];
    try {
      const userMap = {};
      const users = $app.findRecordsByFilter("users", "id != ''", "", 0, 0, {});
      for (const u of users) userMap[u.id] = { name: u.getString("name"), email: u.getString("email") };

      const children = $app.findRecordsByFilter("children", "id != ''", "user", 0, 0, {});
      for (const c of children) {
        const parent  = userMap[c.getString("user")] || {};
        const isBorn  = c.getBool("is_born");
        const dob     = dateOf(c.getString("date_of_birth"));
        let   ageMonths = "";
        if (isBorn && dob) {
          const b = new Date(dob);
          ageMonths = String(Math.max(0,
            (today.getFullYear() - b.getFullYear()) * 12 + today.getMonth() - b.getMonth()
          ));
        }
        rows.push([
          parent.name  || "", parent.email || "",
          c.getString("name"), c.getString("gender"),
          isBorn ? "Yes" : "No", dob,
          dateOf(c.getString("due_date")), ageMonths,
        ]);
      }
    } catch (err) { $app.logger().error("export/children", "err", String(err)); }
    return e.json(200, { csv: toCSV(rows), filename: "children_" + todayStr + ".csv", rows: rows.length - 1 });
  }

  // ── Export: Course Enrolments ─────────────────────────────────────────────
  if (exportType === "enrollments") {
    const headers = ["User Name", "User Email", "Course Title", "Category", "Level",
      "Progress %", "Completed", "Completed Date", "Enrolled Date"];
    const rows = [headers];
    try {
      const userMap = {};
      const users = $app.findRecordsByFilter("users", "id != ''", "", 0, 0, {});
      for (const u of users) userMap[u.id] = { name: u.getString("name"), email: u.getString("email") };

      const courseMap = {};
      const courses = $app.findRecordsByFilter("courses", "id != ''", "", 0, 0, {});
      for (const c of courses) courseMap[c.id] = {
        title: c.getString("title_en"), category: c.getString("category"), level: c.getString("level"),
      };

      const enrollments = $app.findRecordsByFilter("enrollments", "id != ''", "-created", 0, 0, {});
      for (const enr of enrollments) {
        const user   = userMap[enr.getString("user")]     || {};
        const course = courseMap[enr.getString("course")] || {};
        const done   = enr.getBool("is_completed");
        rows.push([
          user.name   || "", user.email   || "",
          course.title || "", course.category || "", course.level || "",
          String(Math.round(enr.getFloat("progress_percent"))),
          done ? "Yes" : "No",
          done ? dateOf(enr.getString("completed_at")) : "",
          dateOf(enr.getString("created")),
        ]);
      }
    } catch (err) { $app.logger().error("export/enrollments", "err", String(err)); }
    return e.json(200, { csv: toCSV(rows), filename: "enrollments_" + todayStr + ".csv", rows: rows.length - 1 });
  }

  // ── Export: Learner Activity ───────────────────────────────────────────────
  if (exportType === "learners") {
    const headers = [
      "Name", "Email", "Language",
      "Courses Enrolled", "Courses Completed", "Lessons Completed",
      "Last Active Date", "Active (Last 7 Days)", "Active (Last 30 Days)",
    ];
    const rows = [headers];
    try {
      const d7  = new Date(today); d7.setDate(d7.getDate() - 7);
      const d30 = new Date(today); d30.setDate(d30.getDate() - 30);
      const d7str = fmtThreshold(d7), d30str = fmtThreshold(d30);

      const enrStats = {};
      const enrollments = $app.findRecordsByFilter("enrollments", "id != ''", "", 0, 0, {});
      for (const enr of enrollments) {
        const uid = enr.getString("user");
        if (!enrStats[uid]) enrStats[uid] = { total: 0, completed: 0 };
        enrStats[uid].total++;
        if (enr.getBool("is_completed")) enrStats[uid].completed++;
      }

      const lpStats = {};
      const lpRecords = $app.findRecordsByFilter("lesson_progress", "id != ''", "", 0, 0, {});
      for (const lp of lpRecords) {
        const uid = lp.getString("user");
        const upd = lp.getString("updated");
        if (!lpStats[uid]) lpStats[uid] = { lessons: 0, lastActive: "" };
        if (lp.getBool("is_completed")) lpStats[uid].lessons++;
        if (upd > lpStats[uid].lastActive) lpStats[uid].lastActive = upd;
      }

      const users = $app.findRecordsByFilter("users", "id != ''", "-created", 0, 0, {});
      for (const u of users) {
        const r = u.getString("role");
        if (r === "admin" || r === "superadmin") continue;
        const enr = enrStats[u.id] || { total: 0, completed: 0 };
        const lps = lpStats[u.id]  || { lessons: 0, lastActive: "" };
        const la  = lps.lastActive;
        rows.push([
          u.getString("name"), u.getString("email"), u.getString("language"),
          String(enr.total), String(enr.completed), String(lps.lessons),
          la ? dateOf(la) : "Never",
          la && la >= d7str  ? "Yes" : "No",
          la && la >= d30str ? "Yes" : "No",
        ]);
      }
    } catch (err) { $app.logger().error("export/learners", "err", String(err)); }
    return e.json(200, { csv: toCSV(rows), filename: "learner_activity_" + todayStr + ".csv", rows: rows.length - 1 });
  }

  // ── Export: User Retention ─────────────────────────────────────────────────
  if (exportType === "retention") {
    const headers = [
      "Name", "Email", "Joined Date", "Days Since Joining", "Language",
      "Courses Enrolled", "In Progress", "Courses Completed", "Completion Rate %", "Avg Course Progress %",
      "Lessons Completed", "Last Active Date", "Active (Last 7 Days)", "Active (Last 30 Days)",
    ];
    const rows = [headers];
    try {
      const d7  = new Date(today); d7.setDate(d7.getDate() - 7);
      const d30 = new Date(today); d30.setDate(d30.getDate() - 30);
      const d7str = fmtThreshold(d7), d30str = fmtThreshold(d30);

      const enrStats = {};
      const enrollments = $app.findRecordsByFilter("enrollments", "id != ''", "", 0, 0, {});
      for (const enr of enrollments) {
        const uid = enr.getString("user");
        if (!enrStats[uid]) enrStats[uid] = { total: 0, completed: 0, totalProgress: 0 };
        enrStats[uid].total++;
        enrStats[uid].totalProgress += enr.getFloat("progress_percent");
        if (enr.getBool("is_completed")) enrStats[uid].completed++;
      }

      const lpStats = {};
      const lpRecords = $app.findRecordsByFilter("lesson_progress", "id != ''", "", 0, 0, {});
      for (const lp of lpRecords) {
        const uid = lp.getString("user");
        const upd = lp.getString("updated");
        if (!lpStats[uid]) lpStats[uid] = { lessons: 0, lastActive: "" };
        if (lp.getBool("is_completed")) lpStats[uid].lessons++;
        if (upd > lpStats[uid].lastActive) lpStats[uid].lastActive = upd;
      }

      const users = $app.findRecordsByFilter("users", "id != ''", "-created", 0, 0, {});
      for (const u of users) {
        const r = u.getString("role");
        if (r === "admin" || r === "superadmin") continue;
        const enr        = enrStats[u.id] || { total: 0, completed: 0, totalProgress: 0 };
        const lps        = lpStats[u.id]  || { lessons: 0, lastActive: "" };
        const la         = lps.lastActive;
        const joinedStr  = u.getString("created");
        const daysSince  = Math.floor((today.getTime() - new Date(joinedStr).getTime()) / 86400000);
        const inProg     = enr.total - enr.completed;
        const compRate   = enr.total > 0 ? Math.round(enr.completed     / enr.total * 100) : 0;
        const avgProg    = enr.total > 0 ? Math.round(enr.totalProgress / enr.total)       : 0;
        rows.push([
          u.getString("name"), u.getString("email"),
          dateOf(joinedStr), String(daysSince), u.getString("language"),
          String(enr.total), String(inProg), String(enr.completed),
          String(compRate), String(avgProg), String(lps.lessons),
          la ? dateOf(la) : "Never",
          la && la >= d7str  ? "Yes" : "No",
          la && la >= d30str ? "Yes" : "No",
        ]);
      }
    } catch (err) { $app.logger().error("export/retention", "err", String(err)); }
    return e.json(200, { csv: toCSV(rows), filename: "user_retention_" + todayStr + ".csv", rows: rows.length - 1 });
  }

  // ── Export: Detailed Lesson Progress ──────────────────────────────────────
  if (exportType === "progress") {
    const headers = [
      "User Name", "User Email", "Course Title", "Lesson Title",
      "Watch %", "Watch Seconds", "Completed", "Quiz Passed", "Quiz Score %",
      "Completed Date", "Last Updated",
    ];
    const rows = [headers];
    try {
      const userMap = {};
      const users = $app.findRecordsByFilter("users", "id != ''", "", 0, 0, {});
      for (const u of users) userMap[u.id] = { name: u.getString("name"), email: u.getString("email") };

      const courseMap = {};
      const courses = $app.findRecordsByFilter("courses", "id != ''", "", 0, 0, {});
      for (const c of courses) courseMap[c.id] = c.getString("title_en");

      const lessonMap = {};
      const lessons = $app.findRecordsByFilter("lessons", "id != ''", "", 0, 0, {});
      for (const l of lessons) lessonMap[l.id] = l.getString("title_en");

      const lpRecords = $app.findRecordsByFilter("lesson_progress", "id != ''", "-updated", 0, 0, {});
      for (const lp of lpRecords) {
        const user = userMap[lp.getString("user")] || {};
        const done = lp.getBool("is_completed");
        rows.push([
          user.name || "", user.email || "",
          courseMap[lp.getString("course")] || "",
          lessonMap[lp.getString("lesson")] || "",
          String(Math.round(lp.getFloat("watch_percent"))),
          String(Math.round(lp.getFloat("watch_seconds"))),
          done ? "Yes" : "No",
          lp.getBool("is_quiz_passed") ? "Yes" : "No",
          String(Math.round(lp.getFloat("quiz_score"))),
          done ? dateOf(lp.getString("completed_at")) : "",
          dateOf(lp.getString("updated")),
        ]);
      }
    } catch (err) { $app.logger().error("export/progress", "err", String(err)); }
    return e.json(200, { csv: toCSV(rows), filename: "lesson_progress_" + todayStr + ".csv", rows: rows.length - 1 });
  }

  return e.json(400, {
    error: "Unknown export type",
    valid: ["users", "children", "enrollments", "learners", "retention", "progress"],
  });
});
