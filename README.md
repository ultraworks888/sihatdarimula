# My Healthy Start · Push Notification Server

A lightweight Node.js process that delivers native Web Push notifications to parents' phones whenever a new notification is created in the app.

## How it works

New notification created in PocketBase
        ↓  (realtime event)
Push server receives event
        ↓
Looks up user's device subscriptions  (push_subscriptions table)
        ↓
Sends signed Web Push to each device  (web-push + VAPID)
        ↓
Phone displays native OS notification (works even when the app is closed)

---

## Step 1 — Set up environment variables

| Variable | Value |
|---|---|
| POCKETBASE_URL | https://app.sihatdarimula.my |
| PB_ADMIN_EMAIL | sdmadmin@ultra.works |
| PB_ADMIN_PASSWORD | Your superadmin password |
| VAPID_PUBLIC_KEY | Your VAPID public key |
| VAPID_PRIVATE_KEY | Your VAPID private key |
| VAPID_EMAIL | sdmadmin@ultra.works |

---

## Step 2 — Deploy to Railway

1. Push these files to a private GitHub repo
2. Go to railway.app → New Project → Deploy from GitHub repo
3. Add all 6 variables in the Railway Variables tab
4. Deploy — check Logs for "Authenticated" and "Listening"

## iOS note

On iOS 16.4+, Web Push only works when the app is added to the home screen via Safari → Share → Add to Home Screen.