#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# test-phase-bc.sh — Phase B/C: HMAC-SHA256 authentication + webhook processing
#
# Tests the new HMAC-SHA256 forwarding authentication between the Cloudflare
# Worker and PocketBase, plus all Phase B event recording and deduplication.
#
# PREREQUISITES
#   brew install jq          (JSON parsing)
#   openssl                  (pre-installed on macOS)
#
# REQUIRED ENVIRONMENT VARIABLES — never committed to source
#   WA_INTERNAL_FORWARD_SECRET  The HMAC-SHA256 signing key (matches whatsapp_server_secrets)
#   PB_ADMIN_TOKEN              App-level admin user token (NOT a PocketBase superuser token)
#                               Obtain via: POST /api/collections/users/auth-with-password
#                               Must be a user with role="admin" or role="superadmin"
#                               NOTE: Do NOT use a PocketBase superuser token here —
#                                     test P verifies that null-rule collections return 403
#                                     for app-level users; a superuser token would bypass that.
#
# OPTIONAL ENVIRONMENT VARIABLES
#   WA_META_APP_SECRET          Meta App Secret — required only for end-to-end test R
#                               If not set, test R is skipped with a clear message.
#   PB_BASE_URL                 Default: https://app.sihatdarimula.my
#   WORKER_URL                  Default: https://mhs-whatsapp-gateway.sihatdarimula.workers.dev
#
# USAGE
#   export WA_INTERNAL_FORWARD_SECRET="<your secret>"
#   export PB_ADMIN_TOKEN="<app-level admin token>"
#   export WA_META_APP_SECRET="<meta app secret>"   # optional — enables test R
#   chmod +x test-phase-bc.sh
#   ./test-phase-bc.sh
#
# SECURITY
#   Secret values are read from the calling shell environment.
#   They are never written to disk by this script.
#   Do NOT commit this script with secret values filled in.
#   Do NOT pass secrets as positional arguments (visible in process lists).
#
# TEST STRUCTURE
#   A–H  Authentication rejection tests (direct to PocketBase, locally signed)
#        Test I removed: do not empty the live secret during testing.
#        The server_misconfigured (500) path is verified by code inspection.
#   J–N  Event recording and deduplication tests (direct to PocketBase)
#   O    Database record verification (admin API read)
#   P    whatsapp_server_secrets access control (must return 403 for app-level admin)
#   Q    Secret value not present in any 200 response body
#   R    End-to-end integration: test payload → Cloudflare Worker → PocketBase → DB
#        (verifies Cloudflare WebCrypto and PocketBase $security.hs256() produce
#         compatible signatures for the same key and message)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
PB_BASE_URL="${PB_BASE_URL:-https://app.sihatdarimula.my}"
WORKER_URL="${WORKER_URL:-https://mhs-whatsapp-gateway.sihatdarimula.workers.dev}"
GATEWAY_SECRET="${WA_INTERNAL_FORWARD_SECRET:-}"
META_APP_SECRET="${WA_META_APP_SECRET:-}"
ADMIN_TOKEN="${PB_ADMIN_TOKEN:-}"

# ── Preflight checks ──────────────────────────────────────────────────────────
[ -z "$GATEWAY_SECRET" ] && { echo "ERROR: WA_INTERNAL_FORWARD_SECRET is not set"; exit 1; }
[ -z "$ADMIN_TOKEN" ]    && { echo "ERROR: PB_ADMIN_TOKEN is not set";              exit 1; }

command -v jq     >/dev/null 2>&1 || { echo "ERROR: jq required — brew install jq"; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl required";              exit 1; }
command -v curl    >/dev/null 2>&1 || { echo "ERROR: curl required";                 exit 1; }

# ── Run ID ───────────────────────────────────────────────────────────────────
# Timestamp-based: allows clean re-runs without manual DB cleanup between runs.
# All synthetic message IDs include RUN_ID so each run produces fresh dedup_keys.
RUN_ID=$(date +%s)

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'; BOLD='\033[1m'
pass()  { echo -e "${GREEN}PASS${RESET}  $1"; }
fail()  { echo -e "${RED}FAIL${RESET}  $1"; FAILURES=$((FAILURES + 1)); }
skip()  { echo -e "${YELLOW}SKIP${RESET}  $1"; }
FAILURES=0

# ── Signing helpers ───────────────────────────────────────────────────────────
# sign BODY SECRET → prints "TIMESTAMP DIGEST SIGNATURE" on one line
# Uses the same algorithm as the Cloudflare Worker's computeForwardingAuth():
#   bodyDigest     = hex(SHA-256(body bytes))
#   signatureInput = timestamp + "." + bodyDigest
#   signature      = hex(HMAC-SHA256(SECRET, signatureInput))
# Note: printf '%s' avoids the trailing newline that echo adds, ensuring the
# hash covers exactly the same bytes as the Worker's ArrayBuffer.
sign() {
  local body="$1" secret="$2"
  local ts digest sig_input sig
  ts=$(date +%s)
  digest=$(printf '%s' "$body" | openssl dgst -sha256 | awk '{print $NF}')
  sig_input="${ts}.${digest}"
  sig=$(printf '%s' "$sig_input" | openssl dgst -sha256 -hmac "$secret" | awk '{print $NF}')
  printf '%s %s %s' "$ts" "$digest" "$sig"
}

# direct_post BODY TS DIGEST SIG → full HTTP response body
direct_post() {
  curl -s -X POST "${PB_BASE_URL}/api/whatsapp/webhook" \
    -H "Content-Type: application/json" \
    -H "X-WhatsApp-Timestamp: $2" \
    -H "X-WhatsApp-Body-Digest: $3" \
    -H "X-WhatsApp-Signature: $4" \
    -d "$1"
}

# ── Canonical test payloads ───────────────────────────────────────────────────
# Each payload uses RUN_ID in message IDs so dedup_keys are unique per run.
# Payloads are minimal but structurally valid Meta webhook bodies.

MSG_BODY='{"object":"whatsapp_business_account","entry":[{"id":"WABA_'"${RUN_ID}"'","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"601234567890","phone_number_id":"PID"},"messages":[{"id":"wamid.test.msg.'"${RUN_ID}"'","from":"601234567890","timestamp":"'"${RUN_ID}"'","type":"text","text":{"body":"Hello test"}}]},"field":"messages"}]}]}'

STATUS_BODY='{"object":"whatsapp_business_account","entry":[{"id":"WABA_'"${RUN_ID}"'","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"601234567890","phone_number_id":"PID"},"statuses":[{"id":"wamid.test.st.'"${RUN_ID}"'","status":"delivered","timestamp":"'"${RUN_ID}"'","recipient_id":"601234567890"}]},"field":"messages"}]}]}'

UNSUP_BODY='{"object":"whatsapp_business_account","entry":[{"id":"WABA_'"${RUN_ID}"'","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"601234567890","phone_number_id":"PID"}},"field":"account_alerts_'"${RUN_ID}"'"}]}]}'

MIXED_BODY='{"object":"whatsapp_business_account","entry":[{"id":"WABA_'"${RUN_ID}"'","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"601234567890","phone_number_id":"PID"},"messages":[{"id":"wamid.test.mix.msg.'"${RUN_ID}"'","from":"601234567890","timestamp":"'"${RUN_ID}"'","type":"text","text":{"body":"Mixed"}}],"statuses":[{"id":"wamid.test.mix.st.'"${RUN_ID}"'","status":"sent","timestamp":"'"${RUN_ID}"'","recipient_id":"601234567890"}]},"field":"messages"}]}]}'

echo ""
echo -e "${BOLD}Phase B/C — HMAC-SHA256 Authentication + Webhook Processing Tests${RESET}"
echo -e "${BOLD}PocketBase: ${PB_BASE_URL}${RESET}"
echo -e "${BOLD}Worker:     ${WORKER_URL}${RESET}"
echo -e "${BOLD}Run ID:     ${RUN_ID}${RESET}"
echo "────────────────────────────────────────────────────────────────"
echo ""
echo -e "${BOLD}Authentication rejection tests (direct to PocketBase)${RESET}"
echo ""

# ── A: No authentication headers ─────────────────────────────────────────────
echo "Test A: No authentication headers → 401"
RESP=$(curl -s -X POST "${PB_BASE_URL}/api/whatsapp/webhook" \
  -H "Content-Type: application/json" \
  -d '{"object":"whatsapp_business_account"}')
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "A" || fail "A — expected error=unauthorized, got: $RESP"

# ── B: Old X-WhatsApp-Gateway-Secret scheme → 401 ────────────────────────────
echo "Test B: Old X-WhatsApp-Gateway-Secret header (old scheme) → 401"
RESP=$(curl -s -X POST "${PB_BASE_URL}/api/whatsapp/webhook" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: ${GATEWAY_SECRET}" \
  -d '{"object":"whatsapp_business_account"}')
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "B" || fail "B — expected error=unauthorized, got: $RESP"

# ── C: Valid timestamp + digest, wrong signature → 401 ───────────────────────
echo "Test C: Valid timestamp + digest, wrong signature → 401"
read -r TS DIGEST _SIG <<< "$(sign "$MSG_BODY" "$GATEWAY_SECRET")"
RESP=$(direct_post "$MSG_BODY" "$TS" "$DIGEST" "0000000000000000000000000000000000000000000000000000000000000000")
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "C" || fail "C — expected error=unauthorized, got: $RESP"

# ── D: Timestamp present, digest + signature absent → 401 ────────────────────
echo "Test D: Timestamp present, digest + signature absent → 401"
TS=$(date +%s)
RESP=$(curl -s -X POST "${PB_BASE_URL}/api/whatsapp/webhook" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Timestamp: ${TS}" \
  -d "$MSG_BODY")
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "D" || fail "D — expected error=unauthorized, got: $RESP"

# ── E: Expired timestamp (>300s old), otherwise valid → 401 ──────────────────
echo "Test E: Timestamp expired >300s ago, otherwise valid → 401"
OLD_TS=$(( $(date +%s) - 400 ))
OLD_DIGEST=$(printf '%s' "$MSG_BODY" | openssl dgst -sha256 | awk '{print $NF}')
OLD_SIG=$(printf '%s' "${OLD_TS}.${OLD_DIGEST}" | openssl dgst -sha256 -hmac "$GATEWAY_SECRET" | awk '{print $NF}')
RESP=$(direct_post "$MSG_BODY" "$OLD_TS" "$OLD_DIGEST" "$OLD_SIG")
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "E" || fail "E — expected error=unauthorized, got: $RESP"

# ── F: Future timestamp (>300s ahead), otherwise valid → 401 ─────────────────
echo "Test F: Timestamp >300s in the future, otherwise valid → 401"
FUTURE_TS=$(( $(date +%s) + 400 ))
FUT_DIGEST=$(printf '%s' "$MSG_BODY" | openssl dgst -sha256 | awk '{print $NF}')
FUT_SIG=$(printf '%s' "${FUTURE_TS}.${FUT_DIGEST}" | openssl dgst -sha256 -hmac "$GATEWAY_SECRET" | awk '{print $NF}')
RESP=$(direct_post "$MSG_BODY" "$FUTURE_TS" "$FUT_DIGEST" "$FUT_SIG")
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "F" || fail "F — expected error=unauthorized, got: $RESP"

# ── G: Non-integer timestamp → 401 ───────────────────────────────────────────
echo "Test G: Non-integer timestamp string \"abc\" → 401"
BAD_DIGEST=$(printf '%s' "$MSG_BODY" | openssl dgst -sha256 | awk '{print $NF}')
BAD_SIG=$(printf '%s' "abc.${BAD_DIGEST}" | openssl dgst -sha256 -hmac "$GATEWAY_SECRET" | awk '{print $NF}')
RESP=$(direct_post "$MSG_BODY" "abc" "$BAD_DIGEST" "$BAD_SIG")
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "G" || fail "G — expected error=unauthorized, got: $RESP"

# ── H: Float timestamp → 401 ─────────────────────────────────────────────────
echo "Test H: Float timestamp string → 401"
FLOAT_TS="$(date +%s).5"
FL_DIGEST=$(printf '%s' "$MSG_BODY" | openssl dgst -sha256 | awk '{print $NF}')
FL_SIG=$(printf '%s' "${FLOAT_TS}.${FL_DIGEST}" | openssl dgst -sha256 -hmac "$GATEWAY_SECRET" | awk '{print $NF}')
RESP=$(direct_post "$MSG_BODY" "$FLOAT_TS" "$FL_DIGEST" "$FL_SIG")
ERR=$(echo "$RESP" | jq -r '.error // "none"')
[ "$ERR" = "unauthorized" ] && pass "H" || fail "H — expected error=unauthorized, got: $RESP"

# Test I removed per Correction 3: do not empty the live secret during testing.
# The server_misconfigured (500) path is verified by code inspection of Steps 2–3
# in pb_hooks/whatsapp_webhook.pb.js.

echo ""
echo -e "${BOLD}Event recording and deduplication tests (direct to PocketBase)${RESET}"
echo ""

# ── J: Valid inbound message → 200 processed:1 ───────────────────────────────
echo "Test J: Valid inbound message payload → 200 { processed:1 }"
read -r TS DIGEST SIG <<< "$(sign "$MSG_BODY" "$GATEWAY_SECRET")"
RESP=$(direct_post "$MSG_BODY" "$TS" "$DIGEST" "$SIG")
OK=$(echo "$RESP" | jq -r '.ok // false')
PROC=$(echo "$RESP" | jq -r '.processed // -1')
DUP=$(echo "$RESP" | jq -r '.duplicates // -1')
[ "$OK" = "true" ] && [ "$PROC" = "1" ] && [ "$DUP" = "0" ] \
  && pass "J" || fail "J — got: $RESP"

# ── K: Same payload re-sent → 200 duplicates:1 ───────────────────────────────
echo "Test K: Same payload re-sent (deduplication) → 200 { duplicates:1 }"
read -r TS DIGEST SIG <<< "$(sign "$MSG_BODY" "$GATEWAY_SECRET")"
RESP=$(direct_post "$MSG_BODY" "$TS" "$DIGEST" "$SIG")
OK=$(echo "$RESP" | jq -r '.ok // false')
DUP=$(echo "$RESP" | jq -r '.duplicates // -1')
PROC=$(echo "$RESP" | jq -r '.processed // -1')
[ "$OK" = "true" ] && [ "$DUP" = "1" ] && [ "$PROC" = "0" ] \
  && pass "K" || fail "K — got: $RESP"

# ── L: Status update → 200 processed:1 ───────────────────────────────────────
echo "Test L: Status update payload → 200 { processed:1 }"
read -r TS DIGEST SIG <<< "$(sign "$STATUS_BODY" "$GATEWAY_SECRET")"
RESP=$(direct_post "$STATUS_BODY" "$TS" "$DIGEST" "$SIG")
OK=$(echo "$RESP" | jq -r '.ok // false')
PROC=$(echo "$RESP" | jq -r '.processed // -1')
[ "$OK" = "true" ] && [ "$PROC" = "1" ] \
  && pass "L" || fail "L — got: $RESP"

# ── M: Unsupported event → 200 ignored:1 ─────────────────────────────────────
echo "Test M: Unsupported event payload → 200 { ignored:1 }"
read -r TS DIGEST SIG <<< "$(sign "$UNSUP_BODY" "$GATEWAY_SECRET")"
RESP=$(direct_post "$UNSUP_BODY" "$TS" "$DIGEST" "$SIG")
OK=$(echo "$RESP" | jq -r '.ok // false')
IGN=$(echo "$RESP" | jq -r '.ignored // -1')
[ "$OK" = "true" ] && [ "$IGN" = "1" ] \
  && pass "M" || fail "M — got: $RESP"

# ── N: Mixed payload (message + status) → 200 processed:2 ────────────────────
echo "Test N: Mixed payload (one message + one status) → 200 { processed:2 }"
read -r TS DIGEST SIG <<< "$(sign "$MIXED_BODY" "$GATEWAY_SECRET")"
RESP=$(direct_post "$MIXED_BODY" "$TS" "$DIGEST" "$SIG")
OK=$(echo "$RESP" | jq -r '.ok // false')
PROC=$(echo "$RESP" | jq -r '.processed // -1')
[ "$OK" = "true" ] && [ "$PROC" = "2" ] \
  && pass "N" || fail "N — got: $RESP"

echo ""
echo -e "${BOLD}Database and security verification${RESET}"
echo ""

# ── O: Verify event records from J/L/M/N are in DB ───────────────────────────
echo "Test O: Verify event records in whatsapp_webhook_events DB"
sleep 1   # brief pause to ensure all writes are committed
DB_RESP=$(curl -s \
  "${PB_BASE_URL}/api/collections/whatsapp_webhook_events/records?sort=-created&perPage=50" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")
MSG_DEDUP="msg:wamid.test.msg.${RUN_ID}"
FOUND=$(echo "$DB_RESP" | jq -r --arg dk "$MSG_DEDUP" '.items[]? | select(.dedup_key == $dk) | .id' | head -1)
if [ -n "$FOUND" ]; then
  # Also verify the status update record
  ST_DEDUP="st:wamid.test.st.${RUN_ID}:delivered"
  ST_FOUND=$(echo "$DB_RESP" | jq -r --arg dk "$ST_DEDUP" '.items[]? | select(.dedup_key == $dk) | .id' | head -1)
  [ -n "$ST_FOUND" ] \
    && pass "O — message record ID: ${FOUND}, status record ID: ${ST_FOUND}" \
    || fail "O — message record found but status record '${ST_DEDUP}' missing; DB response: $(echo "$DB_RESP" | jq -c '.items | length')"
else
  fail "O — dedup_key '${MSG_DEDUP}' not found; total items in response: $(echo "$DB_RESP" | jq -r '.totalItems // "error"')"
fi

# ── P: whatsapp_server_secrets not accessible to app-level admin token ─────────
echo "Test P: whatsapp_server_secrets returns 403 for app-level admin token"
echo "        (If this returns 200, you are using a PocketBase superuser token — see script header)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${PB_BASE_URL}/api/collections/whatsapp_server_secrets/records" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")
[ "$HTTP_CODE" = "403" ] \
  && pass "P — 403 confirmed (app-level admin correctly blocked)" \
  || fail "P — expected 403, got ${HTTP_CODE} (if 200: token is a PocketBase superuser; re-run with an app-level admin token)"

# ── Q: Secret value not present in any 200 response body ─────────────────────
echo "Test Q: Secret value not present in any webhook 200 response body"
read -r TS DIGEST SIG <<< "$(sign "$MSG_BODY" "$GATEWAY_SECRET")"
# Re-send the same payload — will be deduplicated (200 with duplicates:1)
RESP=$(direct_post "$MSG_BODY" "$TS" "$DIGEST" "$SIG")
if echo "$RESP" | grep -qF "$GATEWAY_SECRET"; then
  fail "Q — secret value detected in response body!"
else
  pass "Q"
fi

echo ""
echo -e "${BOLD}End-to-end integration test (via Cloudflare Worker)${RESET}"
echo ""

# ── R: End-to-end via Cloudflare Worker ──────────────────────────────────────
# This test verifies that Cloudflare's WebCrypto implementation (crypto.subtle)
# and PocketBase's $security.hs256() produce compatible HMAC-SHA256 signatures
# for the same key and message. It is the only test that exercises the full
# production signing path.
echo "Test R: End-to-end — Cloudflare Worker → PocketBase → whatsapp_webhook_events"
if [ -z "$META_APP_SECRET" ]; then
  skip "R — WA_META_APP_SECRET not set; export it to enable this test"
  echo "       Required to compute X-Hub-Signature-256 for the Worker to accept the request"
else
  # Unique message ID prevents deduplication against other test runs
  E2E_ID="${RUN_ID}e2e"
  E2E_BODY='{"object":"whatsapp_business_account","entry":[{"id":"WABA_E2E_'"${E2E_ID}"'","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"601234567890","phone_number_id":"PID"},"messages":[{"id":"wamid.test.e2e.'"${E2E_ID}"'","from":"601234567890","timestamp":"'"${RUN_ID}"'","type":"text","text":{"body":"E2E compatibility test"}}]},"field":"messages"}]}]}'
  # Compute Meta X-Hub-Signature-256 — required for the Worker to accept the request
  META_SIG=$(printf '%s' "$E2E_BODY" | openssl dgst -sha256 -hmac "$META_APP_SECRET" | awk '{print $NF}')
  WORKER_RESP=$(curl -s -X POST "$WORKER_URL" \
    -H "Content-Type: application/json" \
    -H "X-Hub-Signature-256: sha256=${META_SIG}" \
    -d "$E2E_BODY")
  # Worker returns 200 regardless (Phase A reliability gap — expected until Phase C)
  echo "       Worker response: ${WORKER_RESP}"
  # Wait for PocketBase to process the forwarded event
  sleep 3
  E2E_DEDUP="msg:wamid.test.e2e.${E2E_ID}"
  E2E_RECORDS=$(curl -s \
    "${PB_BASE_URL}/api/collections/whatsapp_webhook_events/records?sort=-created&perPage=10" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")
  E2E_FOUND=$(echo "$E2E_RECORDS" | jq -r --arg dk "$E2E_DEDUP" '.items[]? | select(.dedup_key == $dk) | .id' | head -1)
  if [ -n "$E2E_FOUND" ]; then
    pass "R — DB record ID: ${E2E_FOUND} (WebCrypto ↔ \$security.hs256 signatures are compatible)"
  else
    fail "R — dedup_key '${E2E_DEDUP}' not found in DB after Worker forwarding"
    echo "       This means Cloudflare WebCrypto and PocketBase \$security.hs256() produced"
    echo "       different HMAC-SHA256 outputs for the same key and message."
    echo "       Check Worker logs in the Cloudflare dashboard for the PocketBase response code."
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────────"
if [ "$FAILURES" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All tests passed.${RESET}"
else
  echo -e "${RED}${BOLD}${FAILURES} test(s) FAILED.${RESET}"
  exit 1
fi
