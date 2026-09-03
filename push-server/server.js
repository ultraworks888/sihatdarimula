/**
 * ─────────────────────────────────────────────────────────────────────────────
 *  My Healthy Start · Sihat Dari Mula
 *  Push Notification Server
 *
 *  What this does:
 *  1. Authenticates with PocketBase as a superadmin
 *  2. Opens a realtime subscription on the `notifications` collection
 *  3. Whenever a new notification record is created, sends a native Web Push
 *     to every device the user has subscribed from
 *  4. Automatically removes expired/invalid subscriptions from the database
 *  5. Reconnects automatically if the connection drops or the token expires
 * ─────────────────────────────────────────────────────────────────────────────
 */

// PocketBase realtime (SSE) requires EventSource in Node.js
import EventSource from "eventsource";
global.EventSource = EventSource;

import PocketBase from "pocketbase";
import webpush    from "web-push";

/* ── 1. Validate required environment variables ──────────────────────────── */
const REQUIRED_VARS = [
  "POCKETBASE_URL",
  "PB_ADMIN_EMAIL",
  "PB_ADMIN_PASSWORD",
  "VAPID_PUBLIC_KEY",
  "VAPID_PRIVATE_KEY",
  "VAPID_EMAIL",
];

const missing = REQUIRED_VARS.filter((k) => !process.env[k]);
if (missing.length) {
  console.error(`\n❌  Missing required environment variables:\n   ${missing.join("\n   ")}`);
  console.error("\n   Copy .env.example → .env and fill in all values.\n");
  process.exit(1);
}

/* ── 2. Configure web-push with VAPID keys ───────────────────────────────── */
webpush.setVapidDetails(
  `mailto:${process.env.VAPID_EMAIL}`,
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

/* ── 3. PocketBase client ────────────────────────────────────────────────── */
const pb = new PocketBase(process.env.POCKETBASE_URL);
pb.autoCancellation(false); // server-side: never auto-cancel requests

/* ── 4. Notification type → in-app deep-link URL ────────────────────────── */
const TYPE_URLS = {
  vaccine_reminder : "/track",
  content_update   : "/content",
  growth_reminder  : "/track",
  feeding_reminder : "/track",
  system           : "/",
};

/* ── 5. Send a push to every device registered for a user ───────────────── */
async function sendPushToUser(userId, notification) {
  let subscriptions;
  try {
    subscriptions = await pb
      .collection("push_subscriptions")
      .getFullList({ filter: `user = "${userId}"` });
  } catch (err) {
    console.warn(`⚠️  Could not fetch subscriptions for user ${userId.slice(0, 8)}… — ${err.message}`);
    return;
  }

  if (!subscriptions.length) {
    console.log(`   ℹ️  No push subscriptions for user ${userId.slice(0, 8)}… — skipping`);
    return;
  }

  const payload = JSON.stringify({
    title : notification.title   || "My Healthy Start",
    body  : notification.message || "",
    url   : TYPE_URLS[notification.type] ?? "/",
    tag   : `sdm-${notification.id}`,
    icon  : "/public_423c_17351677b8b244428bdb9895249c6fca.webp",
  });

  let sent = 0, removed = 0, failed = 0;

  await Promise.allSettled(
    subscriptions.map(async (sub) => {
      const pushSub = {
        endpoint : sub.endpoint,
        keys     : { p256dh: sub.p256dh, auth: sub.auth },
      };

      try {
        await webpush.sendNotification(pushSub, payload);
        sent++;
      } catch (err) {
        /* 410 Gone / 404 Not Found → subscription is no longer valid */
        if (err.statusCode === 410 || err.statusCode === 404) {
          try {
            await pb.collection("push_subscriptions").delete(sub.id);
            removed++;
          } catch { /* already deleted — ignore */ }
        } else {
          failed++;
          console.warn(`   ⚠️  Push failed [${sub.id.slice(0, 8)}] status=${err.statusCode}: ${err.body ?? err.message}`);
        }
      }
    })
  );

  const parts = [];
  if (sent)    parts.push(`${sent} sent`);
  if (removed) parts.push(`${removed} expired removed`);
  if (failed)  parts.push(`${failed} failed`);
  console.log(`   📲  ${parts.join(" · ")} (user ${userId.slice(0, 8)}…)`);
}

/* ── 6. Authenticate with PocketBase as superadmin ──────────────────────── */
async function authenticate() {
  await pb
    .collection("_superusers")
    .authWithPassword(process.env.PB_ADMIN_EMAIL, process.env.PB_ADMIN_PASSWORD);
  console.log("🔐  Authenticated with PocketBase as superadmin");
}

/* ── 7. Open a realtime subscription on `notifications` ─────────────────── */
let unsubscribeFn = null;

async function subscribeToNotifications() {
  unsubscribeFn = await pb.collection("notifications").subscribe("*", async (event) => {
    if (event.action !== "create") return;

    const rec = event.record;
    console.log(`\n📨  New notification [${rec.type}] for user ${String(rec.user).slice(0, 8)}…`);
    console.log(`    "${rec.title}"`);

    await sendPushToUser(rec.user, rec);
  });

  console.log("👂  Listening for new notifications via realtime…\n");
}

/* ── 8. Main loop — reconnects on auth expiry or connection drop ─────────── */
async function start() {
  console.log("─".repeat(60));
  console.log("  My Healthy Start · Push Notification Server");
  console.log(`  PocketBase: ${process.env.POCKETBASE_URL}`);
  console.log("─".repeat(60) + "\n");

  while (true) {
    try {
      await authenticate();
      await subscribeToNotifications();

      /*
       * Keep alive until:
       *   a) the auth token is about to expire (~55 min → reconnect before 60 min expiry)
       *   b) the auth store is unexpectedly cleared
       */
      await new Promise((_, reject) => {
        // Proactively reconnect before token expires (PocketBase default TTL = 60 min)
        const refreshTimer = setTimeout(
          () => reject(new Error("Scheduled token refresh")),
          55 * 60 * 1000
        );

        const unsubChange = pb.authStore.onChange((token) => {
          if (!token) {
            clearTimeout(refreshTimer);
            reject(new Error("Auth store cleared unexpectedly"));
          }
        });

        // Store cleanup refs for later
        start._cleanup = () => { clearTimeout(refreshTimer); unsubChange(); };
      });
    } catch (err) {
      console.warn(`\n🔄  ${err.message} — reconnecting in 10 s…\n`);

      // Tear down existing subscription before reconnecting
      if (unsubscribeFn) {
        try { await unsubscribeFn(); } catch { /* ignore */ }
        unsubscribeFn = null;
      }
      if (start._cleanup) { start._cleanup(); start._cleanup = null; }

      await new Promise((r) => setTimeout(r, 10_000));
    }
  }
}

/* ── 9. Graceful shutdown ────────────────────────────────────────────────── */
async function shutdown(signal) {
  console.log(`\n⛔  ${signal} received — shutting down gracefully…`);
  if (unsubscribeFn) {
    try { await unsubscribeFn(); } catch { /* ignore */ }
  }
  if (start._cleanup) start._cleanup();
  console.log("👋  Push server stopped.\n");
  process.exit(0);
}

process.on("SIGINT",  () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

/* ── Go! ─────────────────────────────────────────────────────────────────── */
start().catch((err) => {
  console.error("💥  Fatal error:", err);
  process.exit(1);
});
