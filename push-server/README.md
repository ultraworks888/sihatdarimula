# My Healthy Start · Push Notification Server

A lightweight Node.js process that delivers native Web Push notifications to parents' phones whenever a new notification is created in the app.

## How it works

```
New notification created in PocketBase
        ↓  (realtime event)
Push server receives event
        ↓
Looks up user's device subscriptions  (push_subscriptions table)
        ↓
Sends signed Web Push to each device  (web-push + VAPID)
        ↓
Phone displays native OS notification
(works even when the app is closed)
```

---

## Prerequisites

- **Node.js 18+** — required for native `fetch` support
- Access to your **Coderick PocketBase URL**
- Your **VAPID key pair** (one-time generation, see below)

---

## Step 1 — Generate VAPID keys

Run this **once** on any machine (does not need to be your server):

```bash
npx web-push generate-vapid-keys
```

You'll get output like:

```
Public Key:
BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U

Private Key:
UqixuQc5-sZBtZbMq6E1_ym_kSHFUGHQB_9hjSPLBgs
```

> **Keep the private key secret.** Only paste it into your push server's environment. The public key goes in both places — the push server AND your Coderick frontend env.

---

## Step 2 — Add the public key to Coderick

In your Coderick project settings, add this environment variable:

```
VITE_VAPID_PUBLIC_KEY=<your public key>
```

This enables the "Enable Push Notifications" toggle in the app for parents.

---

## Step 3 — Set up the push server environment

```bash
cd push-server
cp .env.example .env
```

Open `.env` and fill in:

| Variable | Value |
|---|---|
| `POCKETBASE_URL` | `https://app.sihatdarimula.my` |
| `PB_ADMIN_EMAIL` | `sdmadmin@ultra.works` |
| `PB_ADMIN_PASSWORD` | Your superadmin password |
| `VAPID_PUBLIC_KEY` | The public key from Step 1 |
| `VAPID_PRIVATE_KEY` | The private key from Step 1 |
| `VAPID_EMAIL` | Any email you own (e.g. `sdmadmin@ultra.works`) |

---

## Step 4 — Install and run locally (for testing)

```bash
cd push-server
npm install
npm start
```

You should see:

```
────────────────────────────────────────────────────────────
  My Healthy Start · Push Notification Server
  PocketBase: https://app.sihatdarimula.my
────────────────────────────────────────────────────────────

🔐  Authenticated with PocketBase as superadmin
👂  Listening for new notifications via realtime…
```

Trigger a test by creating a record in the `notifications` collection from the PocketBase admin panel. Your phone (with push enabled in the app) should receive a native notification within seconds.

---

## Step 5 — Deploy to a hosting provider

The push server must run **continuously** (it holds an open SSE connection to PocketBase). Any Node.js host works. Below are three easy options:

### Option A — Railway (recommended, free tier available)

1. Create a free account at [railway.app](https://railway.app)
2. Click **New Project → Deploy from GitHub repo**
3. Point it to a GitHub repo containing just the `push-server/` folder contents (or your full project — Railway detects `package.json` in subdirectories)
4. In Railway: **Variables** → add all six env vars from your `.env`
5. Railway auto-deploys on every git push and keeps the process alive 24/7

### Option B — Render (free tier available)

1. Create account at [render.com](https://render.com)
2. New → **Background Worker** (not a web service — no port needed)
3. Root directory: `push-server`
4. Build command: `npm install`
5. Start command: `npm start`
6. Add env vars in the Render dashboard
7. Deploy

### Option C — Any VPS / server (DigitalOcean, Linode, AWS EC2, etc.)

```bash
# On your server
git clone <your-repo>
cd push-server
npm install
cp .env.example .env
nano .env   # fill in values

# Run with PM2 (keeps it alive after reboots)
npm install -g pm2
pm2 start server.js --name sdm-push
pm2 save
pm2 startup
```

---

## What the server handles automatically

| Scenario | Behaviour |
|---|---|
| User has no push subscription | Skips silently |
| Push subscription expired (410/404) | Deletes it from PocketBase automatically |
| Push rate-limited or server error | Logs warning, continues for other devices |
| PocketBase auth token expires (~60 min) | Reconnects and re-authenticates automatically |
| Realtime connection drops | Reconnects after 10 seconds |
| SIGINT / SIGTERM | Gracefully unsubscribes and exits |

---

## Payload shape sent to devices

The push server sends this JSON to each subscribed device:

```json
{
  "title": "Time for Aiman's MMR vaccine! 💉",
  "body": "The MMR vaccine is due this week. Tap to view details.",
  "url": "/track",
  "tag": "sdm-abc123",
  "icon": "/public_423c_17351677b8b244428bdb9895249c6fca.webp"
}
```

The service worker (`public/sw.js`) receives this and displays the native OS notification. Tapping the notification opens the app at the `url` path.

---

## iOS-specific note

On **iOS 16.4+**, Web Push only works when the app has been **added to the home screen** (via Safari → Share → Add to Home Screen). The "Enable" button in the app's Notification Settings will only appear for supported devices. Regular Mobile Safari browsing does not support push.
