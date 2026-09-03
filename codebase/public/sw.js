/* ─── My Healthy Start · Service Worker ───────────────────────────────────── */
const CACHE_NAME = "sdm-v2";
const LMS_CACHE = "sdm-lms-v1";
const LOGO = "/public_423c_17351677b8b244428bdb9895249c6fca.webp";
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

/* ── Install ── */
self.addEventListener("install", () => { self.skipWaiting(); });

/* ── Activate: claim clients and clean old caches ── */
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME && k !== LMS_CACHE).map(k => caches.delete(k)))
    ).then(() => clients.claim())
  );
});

/* ── Fetch: cache LMS lesson metadata from PocketBase ── */
self.addEventListener("fetch", (event) => {
  const url = event.request.url;

  // Cache PocketBase lesson/course/quiz API responses for offline access
  if (url.includes("/api/collections/lessons/") ||
      url.includes("/api/collections/courses/") ||
      url.includes("/api/collections/lesson_quizzes/") ||
      url.includes("/api/collections/course_modules/")) {
    event.respondWith(
      caches.open(LMS_CACHE).then(async (cache) => {
        const cached = await cache.match(event.request);
        if (cached) {
          const dateHeader = cached.headers.get("x-cached-at");
          if (dateHeader && Date.now() - Number(dateHeader) < CACHE_TTL_MS) {
            return cached;
          }
        }
        try {
          const fresh = await fetch(event.request.clone());
          if (fresh.ok) {
            const headers = new Headers(fresh.headers);
            headers.set("x-cached-at", String(Date.now()));
            const cloned = fresh.clone();
            const body = await cloned.arrayBuffer();
            cache.put(event.request, new Response(body, { status: fresh.status, headers }));
          }
          return fresh;
        } catch {
          if (cached) return cached;
          return new Response(JSON.stringify({ error: "offline" }), { status: 503, headers: { "Content-Type": "application/json" } });
        }
      })
    );
    return;
  }

  // Cache direct video files only when explicitly requested via message
  // (handled in 'message' event below — do not auto-intercept large video files)
});

/* ── Message: manual video cache + offline sync trigger ── */
self.addEventListener("message", (event) => {
  const { type, url } = event.data ?? {};

  if (type === "CACHE_VIDEO" && url) {
    event.waitUntil(
      caches.open(LMS_CACHE).then(async (cache) => {
        try {
          const res = await fetch(url);
          if (res.ok) await cache.put(url, res);
          event.ports[0]?.postMessage({ ok: true });
        } catch {
          event.ports[0]?.postMessage({ ok: false });
        }
      })
    );
  }

  if (type === "PURGE_LMS_CACHE") {
    event.waitUntil(caches.delete(LMS_CACHE));
  }
});

/* ── Background Sync: flush offline xAPI queue ── */
self.addEventListener("sync", (event) => {
  if (event.tag === "xapi-sync") {
    // Notify all clients to run their sync logic
    event.waitUntil(
      clients.matchAll({ type: "window" }).then(cls =>
        Promise.all(cls.map(c => c.postMessage({ type: "SYNC_XAPI" })))
      )
    );
  }
});

/* ─────────────────────────────────────────────────────────────────────────────
   PUSH NOTIFICATIONS
───────────────────────────────────────────────────────────────────────────── */
self.addEventListener("push", (event) => {
  if (!event.data) return;
  let data = {};
  try { data = event.data.json(); } catch { data = { title: "My Healthy Start", body: event.data.text() }; }

  const title = data.title || "My Healthy Start · Sihat Dari Mula";
  const options = {
    body: data.body || "",
    icon: data.icon || LOGO,
    badge: LOGO,
    tag: data.tag || "sdm-push",
    data: { url: data.url || "/" },
    vibrate: [200, 100, 200],
    requireInteraction: false,
    actions: [
      { action: "open", title: "Open App" },
      { action: "dismiss", title: "Dismiss" },
    ],
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  if (event.action === "dismiss") return;
  const targetUrl = event.notification.data?.url || "/";
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin) && "focus" in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(targetUrl);
    })
  );
});

self.addEventListener("notificationclose", () => {});
