# WhatsApp Webhook Verification Gateway
## My Healthy Start · Cloudflare Worker · Phase A

SECURITY GATEWAY ONLY — no business logic, no user matching, no application logic.

---

## What this Worker does

```
Meta WhatsApp Cloud API
  ↓  POST with X-Hub-Signature-256
Cloudflare Worker  ←── this file
  ↓  raw body → HMAC-SHA256 → verified
  ↓  adds X-WhatsApp-Gateway-Secret
PocketBase  (Phase B — not yet implemented)
  ↓
Application / PWA
```

---

## Required secrets

| Secret | Description | Where it comes from |
|---|---|---|
| `META_APP_SECRET` | Meta app secret for HMAC verification | Meta Developer Console → Your App → App Settings → App Secret |
| `WA_WEBHOOK_VERIFY_TOKEN` | Token Meta sends in GET verification | You choose this value — enter it here AND in Meta's webhook config |
| `WA_INTERNAL_FORWARD_SECRET` | Internal shared secret authenticating the Worker to PocketBase | Generate a strong random value (see below) |

**These are never in source code.** They live exclusively as Cloudflare Worker secrets.

Generate a strong `WA_INTERNAL_FORWARD_SECRET`:
```bash
openssl rand -hex 32
```

---

## Setup — Step by step

### Step 1 — Create a Cloudflare account

1. Go to [https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)
2. Create a free account
3. No domain or credit card required for Workers

---

### Step 2 — Install Wrangler (Cloudflare's CLI)

Wrangler requires Node.js, which you already have.

```bash
npm install -g wrangler
```

Verify:
```bash
wrangler --version
```

---

### Step 3 — Authenticate Wrangler

```bash
wrangler login
```

This opens a browser window. Sign in with your Cloudflare account. When the browser shows "Successfully authorised Wrangler", close it and return to the terminal.

---

### Step 4 — Navigate to the Worker directory

From the project root:
```bash
cd cloudflare-worker
```

All subsequent commands run from inside `cloudflare-worker/`.

---

### Step 5 — Update wrangler.toml

Open `wrangler.toml` and replace the placeholder in `POCKETBASE_WEBHOOK_URL`:

```toml
POCKETBASE_WEBHOOK_URL = "https://YOUR-SITE.sg-host.com/api/whatsapp/webhook"
```

Replace `YOUR-SITE.sg-host.com` with your actual production site domain.
(Find it: open your Coderick project → the live URL shown in the preview)

**Do not put secrets in wrangler.toml.**

---

### Step 6 — Set the three secrets

Each command below prompts you to paste the value and press Enter.
The value is sent directly to Cloudflare and is never stored locally.

```bash
wrangler secret put META_APP_SECRET
```
→ Paste your Meta app secret when prompted

```bash
wrangler secret put WA_WEBHOOK_VERIFY_TOKEN
```
→ Paste the verify token you will also enter in Meta's webhook config.
  Choose any string — example: a UUID or random alphanumeric string.
  Write it down; you will need to enter it in the Meta Developer Console.

```bash
wrangler secret put WA_INTERNAL_FORWARD_SECRET
```
→ Paste the value from `openssl rand -hex 32` (generated in the Secrets section above)

Confirm all three secrets are set:
```bash
wrangler secret list
```

You should see:
```
META_APP_SECRET
WA_INTERNAL_FORWARD_SECRET
WA_WEBHOOK_VERIFY_TOKEN
```

---

### Step 7 — Deploy the Worker

```bash
wrangler deploy
```

Successful output looks like:
```
✓ Uploading worker script
✓ Deployed mhs-whatsapp-gateway

https://mhs-whatsapp-gateway.YOUR-SUBDOMAIN.workers.dev
```

**The URL shown is your Worker URL.** Copy it — you will need it for Meta.

---

### Step 8 — Note your Worker URL

The URL format is:
```
https://mhs-whatsapp-gateway.YOUR-SUBDOMAIN.workers.dev
```

Where `YOUR-SUBDOMAIN` is your Cloudflare account subdomain (assigned when you created your account). The Wrangler deploy output shows the full URL.

---

### Step 9 — Configure Meta's webhook

1. Go to [https://developers.facebook.com](https://developers.facebook.com)
2. Select your app
3. In the left sidebar: **WhatsApp** → **Configuration**
4. Under **Webhook**, click **Edit**
5. Set:
   - **Callback URL**: `https://mhs-whatsapp-gateway.YOUR-SUBDOMAIN.workers.dev`
   - **Verify Token**: the exact value you set for `WA_WEBHOOK_VERIFY_TOKEN`
6. Click **Verify and Save**

Meta will send a GET request to your Worker. If the verify token matches, the webhook will be confirmed.

7. Under **Webhook Fields**, click **Manage**
8. Subscribe to the **messages** field

---

## Running the tests

```bash
# Make the script executable (first time only)
chmod +x test-worker.sh

# Edit the three configuration variables at the top of the script
nano test-worker.sh
# Set:
#   WORKER_URL   — your Worker URL from Step 8
#   VERIFY_TOKEN — your WA_WEBHOOK_VERIFY_TOKEN value
#   APP_SECRET   — your META_APP_SECRET value

# Run the tests
./test-worker.sh
```

All 9 tests (A–H plus bonus) should pass.

---

## Phase A behaviour when PocketBase endpoint does not exist

During Phase A, the PocketBase endpoint (`/api/whatsapp/webhook`) does not yet exist.
When the Worker forwards a verified event and PocketBase returns 404:

- The Worker logs: `Forward failed: PocketBase responded HTTP 404`
- The Worker returns **HTTP 200 to Meta**
- This is intentional — returning 5xx would trigger Meta's automatic retry logic,
  which would create duplicate deliveries once the endpoint is live in Phase B
- No event data is lost at this stage — Cloudflare Worker logs capture the receipt

---

## Security notes

| Property | Implementation |
|---|---|
| Signature verification | `crypto.subtle.verify()` — WebCrypto, timing-safe by spec |
| Token comparison | HMAC-based ephemeral-key equaliser — timing-safe |
| Secrets | Cloudflare Worker secrets — never in source, never in env, never in browser |
| Body bytes | `request.arrayBuffer()` before any parsing — original bytes guaranteed |
| JSON not parsed before verification | Correct — parsing happens after HMAC passes |
| Re-serialisation | Not used at any point |
| Logging | Timestamps, status, byte counts only — no secrets, no payloads, no PII |

### What the Worker explicitly does NOT do

- It does not parse the JSON body before verification
- It does not use IP range filtering as a substitute for HMAC
- It does not use re-serialised JSON for HMAC computation
- It does not log `META_APP_SECRET`, `WA_WEBHOOK_VERIFY_TOKEN`, or `WA_INTERNAL_FORWARD_SECRET`
- It does not log the full webhook payload
- It does not contain any WhatsApp business logic
- It does not match users or modify application state

---

## Rollback procedure

To immediately stop the Worker from receiving any traffic:

**Option A — Delete the Worker:**
```bash
wrangler delete
```
Then remove the webhook URL from Meta's Developer Console.

**Option B — Disable without deleting (pause the Worker):**
1. Go to [https://dash.cloudflare.com](https://dash.cloudflare.com)
2. Workers & Pages → mhs-whatsapp-gateway
3. Settings → toggle the Worker to **Disabled**

**Option C — Remove from Meta only:**
Go to Meta Developer Console → WhatsApp → Configuration → delete the webhook URL.
The Worker still runs but receives no traffic.

After rollback, update the Meta webhook URL to a valid endpoint or remove it entirely to prevent failed verification attempts.

---

## Phase B (not yet implemented)

Phase B adds the PocketBase side:
- `POST /api/whatsapp/webhook` endpoint in PocketBase hooks
- Validates `X-WhatsApp-Gateway-Secret` header using `$security.equal()` + `$os.getenv()`
- Deduplication by `wa_message_id`
- `whatsapp_webhook_events` collection
- User matching and business logic

The Worker code does not change in Phase B. Only PocketBase receives the new hook.
