// GET /api/admin/analytics
// Returns aggregated learning metrics: enrollments, lesson progress,
// active learners, weekly activity trend, and per-course performance.
routerAdd("GET", "/api/admin/analytics", (e) => {

  if (!e.auth) return e.json(401, { error: "Unauthorized" });
  const role = e.auth.getString("role");
  if (role !== "admin" && role !== "superadmin") return e.json(403, { error: "Forbidden" });

  // ── Date helpers ─────────────────────────────────────────────────────────
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  const fmt = (d) => d.getFullYear() + "-" + pad(d.getMonth()+1) + "-" + pad(d.getDate()) + " 00:00:00.000Z";

  const d7  = new Date(now); d7.setDate(d7.getDate() - 7);
  const d30 = new Date(now); d30.setDate(d30.getDate() - 30);

  // ── Enrollments ──────────────────────────────────────────────────────────
  let totalEnrollments = 0, completedEnrollments = 0, totalProgress = 0;
  // courseId → { enrollments, completed, totalProgress, lessonsCompleted }
  const courseStats = {};

  try {
    const rows = $app.findRecordsByFilter("enrollments", "id != ''", "", 0, 0, {});
    for (const row of rows) {
      totalEnrollments++;
      const cid      = row.getString("course");
      const done     = !!row.get("is_completed");
      const progress = Number(row.get("progress_percent")) || 0;

      if (done) completedEnrollments++;
      totalProgress += progress;

      if (!courseStats[cid]) courseStats[cid] = { enrollments: 0, completed: 0, totalProgress: 0, lessonsCompleted: 0 };
      courseStats[cid].enrollments++;
      if (done) courseStats[cid].completed++;
      courseStats[cid].totalProgress += progress;
    }
  } catch (err) {
    $app.logger().error("analytics: enrollments error", "err", String(err));
  }

  // ── Lesson progress ───────────────────────────────────────────────────────
  let totalLessonsCompleted = 0;
  const active7d  = {};
  const active30d = {};
  // week label → { userId: true }  (last 5 × 7-day buckets)
  const weekBuckets = {};
  const weekLabels  = ["4 wks ago", "3 wks ago", "2 wks ago", "Last week", "This week"];

  try {
    const rows = $app.findRecordsByFilter("lesson_progress", "id != ''", "", 0, 0, {});
    for (const row of rows) {
      const uid      = row.getString("user");
      const cid      = row.getString("course");
      const done     = !!row.get("is_completed");
      const updated  = row.getString("updated"); // "YYYY-MM-DD HH:MM:SS.000Z"

      if (done) {
        totalLessonsCompleted++;
        if (courseStats[cid]) courseStats[cid].lessonsCompleted++;
      }

      // Active-learner windows (string-compare works for PocketBase ISO dates)
      if (updated >= fmt(d7))  active7d[uid]  = true;
      if (updated >= fmt(d30)) active30d[uid] = true;

      // Weekly bucket — key by 7-day window
      const msSince = now.getTime() - new Date(updated).getTime();
      const daysAgo = Math.floor(msSince / 86400000);
      const wk = daysAgo <  7 ? "This week"
               : daysAgo < 14 ? "Last week"
               : daysAgo < 21 ? "2 wks ago"
               : daysAgo < 28 ? "3 wks ago"
               : daysAgo < 35 ? "4 wks ago"
               : null;
      if (wk) {
        if (!weekBuckets[wk]) weekBuckets[wk] = {};
        weekBuckets[wk][uid] = true;
      }
    }
  } catch (err) {
    $app.logger().error("analytics: lesson_progress error", "err", String(err));
  }

  // ── Courses ───────────────────────────────────────────────────────────────
  const courses = [];
  try {
    const rows = $app.findRecordsByFilter("courses", "is_published = true", "-created", 0, 0, {});
    for (const c of rows) {
      const cid   = c.id;
      const stats = courseStats[cid] || { enrollments: 0, completed: 0, totalProgress: 0, lessonsCompleted: 0 };
      courses.push({
        id:                cid,
        title:             c.getString("title_en"),
        category:          c.getString("category"),
        enrollment_count:  stats.enrollments,
        completion_count:  stats.completed,
        completion_rate:   stats.enrollments > 0 ? Math.round(stats.completed   / stats.enrollments * 100) : 0,
        avg_progress:      stats.enrollments > 0 ? Math.round(stats.totalProgress / stats.enrollments)     : 0,
        lessons_completed: stats.lessonsCompleted,
      });
    }
    // Rank by enrollment count descending
    courses.sort((a, b) => b.enrollment_count - a.enrollment_count);
  } catch (err) {
    $app.logger().error("analytics: courses error", "err", String(err));
  }

  // ── Weekly activity chart data ────────────────────────────────────────────
  const weekly_activity = weekLabels.map((label) => ({
    label,
    learners: weekBuckets[label] ? Object.keys(weekBuckets[label]).length : 0,
  }));

  // ── Aggregate response ────────────────────────────────────────────────────
  return e.json(200, {
    enrollments: {
      total:           totalEnrollments,
      completed:       completedEnrollments,
      in_progress:     totalEnrollments - completedEnrollments,
      completion_rate: totalEnrollments > 0 ? Math.round(completedEnrollments / totalEnrollments * 100) : 0,
      avg_progress:    totalEnrollments > 0 ? Math.round(totalProgress        / totalEnrollments)       : 0,
    },
    learners: {
      active_7d:  Object.keys(active7d).length,
      active_30d: Object.keys(active30d).length,
    },
    lessons: {
      total_completed: totalLessonsCompleted,
    },
    courses,
    weekly_activity,
  });
});
