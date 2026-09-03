// Daily push reminder — runs at 9 AM Malaysia time (01:00 UTC)
cronAdd("push_reminder_daily", "0 1 * * *", () => {
  // ── 1. Load OneSignal credentials from lms_settings ──────────────────────
  let appId, apiKey;
  try {
    appId  = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_app_id"  }).getString("value");
    apiKey = $app.findFirstRecordByFilter("lms_settings", "key = {:k}", { k: "onesignal_api_key" }).getString("value");
  } catch (_) {
    $app.logger().error("push_reminders: OneSignal settings not found in lms_settings");
    return;
  }

  if (!appId || !apiKey) {
    $app.logger().error("push_reminders: empty OneSignal credentials");
    return;
  }

  // ── 2. Build cutoff timestamp (2 days ago) ────────────────────────────────
  const now = new Date();
  const cutoffDate = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
  const pad = n => String(n).padStart(2, "0");
  const cutoff = cutoffDate.getFullYear() + "-"
    + pad(cutoffDate.getMonth() + 1) + "-"
    + pad(cutoffDate.getDate()) + " 00:00:00.000Z";

  // ── 3. Collect unique user IDs with at least one incomplete enrollment ────
  const enrollments = $app.findRecordsByFilter(
    "enrollments", "is_completed = false", "", 0, 0, {}
  );

  const userIdSet = {};
  for (const e of enrollments) {
    userIdSet[e.getString("user")] = true;
  }
  const userIds = Object.keys(userIdSet);

  if (userIds.length === 0) return;

  // ── 4. Filter to users with no lesson_progress in the last 2 days ─────────
  const inactiveIds = [];
  for (const uid of userIds) {
    try {
      $app.findFirstRecordByFilter(
        "lesson_progress",
        "user = {:u} && updated >= {:c}",
        { u: uid, c: cutoff }
      );
      // Has recent activity — skip
    } catch (_) {
      inactiveIds.push(uid);
    }
  }

  if (inactiveIds.length === 0) {
    $app.logger().info("push_reminders: no inactive users today");
    return;
  }

  $app.logger().info("push_reminders: sending reminders", "count", inactiveIds.length);

  // ── 5. Get app URL from PocketBase meta settings ──────────────────────────
  let appURL = "";
  try { appURL = $app.settings().meta.appURL || ""; } catch (_) {}

  // ── 6. Send push notification via OneSignal REST API ─────────────────────
  const res = $http.send({
    url: "https://onesignal.com/api/v1/notifications",
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Basic " + apiKey,
    },
    body: JSON.stringify({
      app_id: appId,
      include_external_user_ids: inactiveIds,
      channel_for_external_user_ids: "push",
      headings: {
        en: "Continue your learning journey! \uD83D\uDCDA",
        ms: "Teruskan pembelajaran anda! \uD83D\uDCDA",
        zh: "\u7EE7\u7EED\u4F60\u7684\u5B66\u4E60\u4E4B\u65C5\uFF01",
      },
      contents: {
        en: "You haven\u2019t studied in a few days. Just one lesson today keeps your progress going!",
        ms: "Anda belum belajar beberapa hari. Satu pelajaran hari ini sudah membantu!",
        zh: "\u60A8\u5DF2\u591A\u5929\u6CA1\u6709\u5B66\u4E60\u3002\u4ECA\u5929\u53EA\u9700\u4E00\u8282\u8BFE\uFF01",
      },
      url: appURL + "/content",
    }),
    timeout: 30,
  });

  if (res.statusCode >= 400) {
    $app.logger().error(
      "push_reminders: OneSignal API error",
      "status", res.statusCode,
      "body",   res.raw
    );
  } else {
    $app.logger().info("push_reminders: notifications sent successfully");
  }
});
