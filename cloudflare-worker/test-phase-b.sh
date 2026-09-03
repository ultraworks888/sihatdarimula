#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# My Healthy Start — Phase B Test Suite
# Tests A through L per the Phase B requirements
#
# Prerequisites:
#   - curl (pre-installed on macOS)
#   - jq   (install with: brew install jq)
#
# Usage:
#   chmod +x test-phase-b.sh
#   ./test-phase-b.sh
#
# Configure the four variables below before running.
# ─────────────────────────────────────────────────────────────────────────────

# ── Configure these before running ───────────────────────────────────────────

# The production PocketBase base URL (no trailing slash)
PB_BASE_URL="https://app.sihatdarimula.my"

# The internal gateway secret — must match WA_INTERNAL_FORWARD_SECRET in Cloudflare
GATEWAY_SECRET="your-wa-internal-forward-secret"

# A valid PocketBase admin or superadmin Bearer token for DB verification queries.
# Get one by logging into the app as admin, then opening browser DevTools → Application
# → Local Storage → look for the pb_auth key → copy the "token" value.
ADMIN_TOKEN="your-admin-bearer-token"

# A wrong secret value (must differ from GATEWAY_SECRET; used for rejection tests)
WRONG_SECRET="this-is-definitely-the-wrong-secret-value"

# ─────────────────────────────────────────────────────────────────────────────

WEBHOOK_URL="${PB_BASE_URL}/api/whatsapp/webhook"
RECORDS_URL="${PB_BASE_URL}/api/collections/whatsapp_webhook_events/records"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

pass()    { echo -e "  ${GREEN}✓ PASS${NC}: $1"; ((PASS++)); }
fail()    { echo -e "  ${RED}✗ FAIL${NC}: $1"; ((FAIL++)); }
section() { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }
info()    { echo -e "  ${YELLOW}→${NC} $1"; }

# Check HTTP status code
check_status() {
  local label=$1
  local expected=$2
  local actual=$3
  if [ "$actual" = "$expected" ]; then
    pass "$label (HTTP $actual)"
  else
    fail "$label (expected HTTP $expected, got HTTP $actual)"
  fi
}

# Check a JSON field value in a response body
check_json() {
  local label=$1
  local expected=$2
  local actual=$3
  if [ "$actual" = "$expected" ]; then
    pass "$label (got: $actual)"
  else
    fail "$label (expected: $expected, got: $actual)"
  fi
}

# Query the DB and return the count of records matching a filter
db_count() {
  local filter=$1
  local encoded_filter
  encoded_filter=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$filter'))" 2>/dev/null || \
                   python -c "import urllib, sys; print(urllib.quote('$filter'))" 2>/dev/null || \
                   echo "$filter" | sed 's/ /%20/g; s/=/%3D/g; s/"/%22/g; s/!/%21/g')
  local result
  result=$(curl -s \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    "${RECORDS_URL}?filter=${encoded_filter}&perPage=1&skipTotal=false")
  echo "$result" | jq -r '.totalItems // 0' 2>/dev/null || echo "0"
}

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  My Healthy Start — Phase B Test Suite (A–L)          ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "  Webhook URL: $WEBHOOK_URL"
echo ""

# Check jq is available
if ! command -v jq &>/dev/null; then
  echo -e "  ${RED}ERROR: jq is required. Install with: brew install jq${NC}"
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Unique run suffix — keeps each test run's message IDs separate from prior runs
# so tests can be repeated without manual cleanup
# ─────────────────────────────────────────────────────────────────────────────
RUN_ID="$(date +%s)"

# ─────────────────────────────────────────────────────────────────────────────
section "A — Valid gateway secret → accepted"
# ─────────────────────────────────────────────────────────────────────────────
info "POST with correct X-WhatsApp-Gateway-Secret and valid payload structure"

MSG_ID_A="wamid.TEST_A_${RUN_ID}"
PAYLOAD_A=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"111111111","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000001","phone_number_id":"111111111"},"messages":[{"from":"60100000001","id":"${MSG_ID_A}","type":"text","text":{"body":"Test A"},"timestamp":"1700000001"}]},"field":"messages"}]}]}
EOF
)

RESP_A=$(curl -s -w "\n---STATUS:%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_A")
STATUS_A=$(echo "$RESP_A" | grep "---STATUS:" | cut -d: -f2)
BODY_A=$(echo "$RESP_A" | grep -v "---STATUS:")
OK_A=$(echo "$BODY_A" | jq -r '.ok // false')

check_status "A. Valid secret → HTTP 200" "200" "$STATUS_A"
check_json   "A. Response ok=true" "true" "$OK_A"

# ─────────────────────────────────────────────────────────────────────────────
section "B — Missing gateway secret → rejected"
# ─────────────────────────────────────────────────────────────────────────────
info "POST with no X-WhatsApp-Gateway-Secret header"

MSG_ID_B="wamid.TEST_B_${RUN_ID}"
PAYLOAD_B=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"111111111","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000001","phone_number_id":"111111111"},"messages":[{"from":"60100000001","id":"${MSG_ID_B}","type":"text","text":{"body":"Test B"},"timestamp":"1700000002"}]},"field":"messages"}]}]}
EOF
)

STATUS_B=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  --data-raw "$PAYLOAD_B")
check_status "B. Missing secret → HTTP 401" "401" "$STATUS_B"

# Verify: no record was created for test B's message ID
COUNT_B=$(db_count "wa_message_id='${MSG_ID_B}'")
check_json "B. No record written for rejected event" "0" "$COUNT_B"

# ─────────────────────────────────────────────────────────────────────────────
section "C — Incorrect gateway secret → rejected"
# ─────────────────────────────────────────────────────────────────────────────
info "POST with wrong X-WhatsApp-Gateway-Secret value"

MSG_ID_C="wamid.TEST_C_${RUN_ID}"
PAYLOAD_C=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"111111111","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000001","phone_number_id":"111111111"},"messages":[{"from":"60100000001","id":"${MSG_ID_C}","type":"text","text":{"body":"Test C"},"timestamp":"1700000003"}]},"field":"messages"}]}]}
EOF
)

STATUS_C=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $WRONG_SECRET" \
  --data-raw "$PAYLOAD_C")
check_status "C. Wrong secret → HTTP 401" "401" "$STATUS_C"

COUNT_C=$(db_count "wa_message_id='${MSG_ID_C}'")
check_json "C. No record written for rejected event" "0" "$COUNT_C"

# ─────────────────────────────────────────────────────────────────────────────
section "D — Valid secret + malformed JSON → safely rejected"
# ─────────────────────────────────────────────────────────────────────────────
info "POST with correct secret but body is not valid JSON"

STATUS_D=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw 'this is not json {{{')
check_status "D. Malformed JSON → HTTP 4xx" "400" "$STATUS_D"
# Note: PocketBase may return 400 from its own JSON parser before the hook body
# validation runs. Either way, the result must be 4xx and no record must be written.

# ─────────────────────────────────────────────────────────────────────────────
section "E — Valid inbound message → exactly one DB record"
# ─────────────────────────────────────────────────────────────────────────────
info "POST a valid inbound text message and verify exactly one record in DB"

MSG_ID_E="wamid.TEST_E_${RUN_ID}"
PAYLOAD_E=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"222222222","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000002","phone_number_id":"222222222"},"messages":[{"from":"60100000002","id":"${MSG_ID_E}","type":"text","text":{"body":"Hello E"},"timestamp":"1700000005"}]},"field":"messages"}]}]}
EOF
)

RESP_E=$(curl -s -w "\n---STATUS:%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_E")
STATUS_E=$(echo "$RESP_E" | grep "---STATUS:" | cut -d: -f2)
BODY_E=$(echo "$RESP_E" | grep -v "---STATUS:")
PROCESSED_E=$(echo "$BODY_E" | jq -r '.processed // 0')

check_status "E. Valid message → HTTP 200"       "200" "$STATUS_E"
check_json   "E. Response processed=1"            "1"   "$PROCESSED_E"

COUNT_E=$(db_count "wa_message_id='${MSG_ID_E}'")
check_json   "E. Exactly one DB record created"   "1"   "$COUNT_E"

# ─────────────────────────────────────────────────────────────────────────────
section "F — Same inbound event twice → exactly one DB record"
# ─────────────────────────────────────────────────────────────────────────────
info "POST the same message ID twice — second delivery must be deduplicated"

MSG_ID_F="wamid.TEST_F_${RUN_ID}"
PAYLOAD_F=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"222222222","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000002","phone_number_id":"222222222"},"messages":[{"from":"60100000002","id":"${MSG_ID_F}","type":"text","text":{"body":"Hello F"},"timestamp":"1700000006"}]},"field":"messages"}]}]}
EOF
)

# First delivery
RESP_F1=$(curl -s -w "\n---STATUS:%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_F")
STATUS_F1=$(echo "$RESP_F1" | grep "---STATUS:" | cut -d: -f2)
BODY_F1=$(echo "$RESP_F1" | grep -v "---STATUS:")
PROC_F1=$(echo "$BODY_F1" | jq -r '.processed // 0')
DUPL_F1=$(echo "$BODY_F1" | jq -r '.duplicates // 0')

check_status "F.1 First delivery → HTTP 200"       "200" "$STATUS_F1"
check_json   "F.1 First delivery processed=1"       "1"   "$PROC_F1"
check_json   "F.1 First delivery duplicates=0"      "0"   "$DUPL_F1"

# Second delivery (same payload, same message ID)
RESP_F2=$(curl -s -w "\n---STATUS:%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_F")
STATUS_F2=$(echo "$RESP_F2" | grep "---STATUS:" | cut -d: -f2)
BODY_F2=$(echo "$RESP_F2" | grep -v "---STATUS:")
PROC_F2=$(echo "$BODY_F2" | jq -r '.processed // 0')
DUPL_F2=$(echo "$BODY_F2" | jq -r '.duplicates // 0')

check_status "F.2 Second delivery → HTTP 200 (acknowledged)"  "200" "$STATUS_F2"
check_json   "F.2 Second delivery processed=0"                 "0"   "$PROC_F2"
check_json   "F.2 Second delivery duplicates=1"                "1"   "$DUPL_F2"

COUNT_F=$(db_count "wa_message_id='${MSG_ID_F}'")
check_json   "F.3 Only one DB record after two deliveries"     "1"   "$COUNT_F"

# ─────────────────────────────────────────────────────────────────────────────
section "G — Two different message IDs → two DB records"
# ─────────────────────────────────────────────────────────────────────────────
info "POST two events with different wamid values — both must be stored"

MSG_ID_G1="wamid.TEST_G1_${RUN_ID}"
MSG_ID_G2="wamid.TEST_G2_${RUN_ID}"

PAYLOAD_G1=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"333333333","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000003","phone_number_id":"333333333"},"messages":[{"from":"60100000003","id":"${MSG_ID_G1}","type":"text","text":{"body":"G1"},"timestamp":"1700000007"}]},"field":"messages"}]}]}
EOF
)
PAYLOAD_G2=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"333333333","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000003","phone_number_id":"333333333"},"messages":[{"from":"60100000003","id":"${MSG_ID_G2}","type":"text","text":{"body":"G2"},"timestamp":"1700000008"}]},"field":"messages"}]}]}
EOF
)

curl -s -o /dev/null -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_G1"

curl -s -o /dev/null -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_G2"

COUNT_G1=$(db_count "wa_message_id='${MSG_ID_G1}'")
COUNT_G2=$(db_count "wa_message_id='${MSG_ID_G2}'")

check_json "G. First message ID has exactly one record"  "1" "$COUNT_G1"
check_json "G. Second message ID has exactly one record" "1" "$COUNT_G2"

# ─────────────────────────────────────────────────────────────────────────────
section "H — Duplicate status transition → exactly one DB record"
# ─────────────────────────────────────────────────────────────────────────────
info "POST the same status update (same wamid + same delivery status) twice"

MSG_ID_H="wamid.TEST_H_${RUN_ID}"
PAYLOAD_H=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"444444444","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000004","phone_number_id":"444444444"},"statuses":[{"id":"${MSG_ID_H}","status":"delivered","timestamp":"1700000009","recipient_id":"60100000004"}]},"field":"messages"}]}]}
EOF
)

curl -s -o /dev/null -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_H"

RESP_H2=$(curl -s -w "\n---STATUS:%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_H")
STATUS_H2=$(echo "$RESP_H2" | grep "---STATUS:" | cut -d: -f2)
BODY_H2=$(echo "$RESP_H2" | grep -v "---STATUS:")
DUPL_H2=$(echo "$BODY_H2" | jq -r '.duplicates // 0')

check_status "H. Duplicate status → HTTP 200 (acknowledged)" "200" "$STATUS_H2"
check_json   "H. Second delivery shows duplicates=1"          "1"   "$DUPL_H2"

# dedup_key = "st:{MSG_ID_H}:delivered"
DEDUP_H="st:${MSG_ID_H}:delivered"
COUNT_H=$(db_count "dedup_key='${DEDUP_H}'")
check_json   "H. Exactly one DB record for dedup_key"         "1"   "$COUNT_H"

# Verify different status transition for same message is stored separately
PAYLOAD_H_READ=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"444444444","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000004","phone_number_id":"444444444"},"statuses":[{"id":"${MSG_ID_H}","status":"read","timestamp":"1700000010","recipient_id":"60100000004"}]},"field":"messages"}]}]}
EOF
)
curl -s -o /dev/null -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_H_READ"

DEDUP_H_READ="st:${MSG_ID_H}:read"
COUNT_H_READ=$(db_count "dedup_key='${DEDUP_H_READ}'")
check_json "H. Different status transition (read) stored as separate record" "1" "$COUNT_H_READ"

# ─────────────────────────────────────────────────────────────────────────────
section "I — Unsupported valid webhook payload → recorded as unsupported"
# ─────────────────────────────────────────────────────────────────────────────
info "POST a valid WhatsApp structure with no messages or statuses arrays"

ENTRY_ID_I="555555555_${RUN_ID}"
PAYLOAD_I=$(cat <<EOF
{"object":"whatsapp_business_account","entry":[{"id":"${ENTRY_ID_I}","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60100000005","phone_number_id":"555555555"}},"field":"account_alerts"}]}]}
EOF
)

RESP_I=$(curl -s -w "\n---STATUS:%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-WhatsApp-Gateway-Secret: $GATEWAY_SECRET" \
  --data-raw "$PAYLOAD_I")
STATUS_I=$(echo "$RESP_I" | grep "---STATUS:" | cut -d: -f2)
BODY_I=$(echo "$RESP_I" | grep -v "---STATUS:")
IGNORED_I=$(echo "$BODY_I" | jq -r '.ignored // 0')

check_status "I. Unsupported event → HTTP 200"                   "200" "$STATUS_I"
check_json   "I. Response ignored=1"                              "1"   "$IGNORED_I"

# dedup_key = "unsup:{ENTRY_ID_I}:account_alerts"
DEDUP_I="unsup:${ENTRY_ID_I}:account_alerts"
COUNT_I=$(db_count "event_type='unsupported'&filter2=dedup_key='${DEDUP_I}'")
# Simpler: just check by dedup_key
COUNT_I=$(db_count "dedup_key='${DEDUP_I}'")
check_json   "I. Unsupported event written to DB with dedup_key" "1"   "$COUNT_I"

# ─────────────────────────────────────────────────────────────────────────────
section "J — Existing PWA remains operational"
# ─────────────────────────────────────────────────────────────────────────────
info "Public API collection endpoint must still respond correctly"

STATUS_J=$(curl -s -o /dev/null -w "%{http_code}" \
  "${PB_BASE_URL}/api/collections/articles/records?perPage=1")
check_status "J. Public articles API returns 200" "200" "$STATUS_J"

info "Root URL (PWA) must respond"
STATUS_J2=$(curl -s -o /dev/null -w "%{http_code}" "$PB_BASE_URL/")
check_status "J. Root URL returns 200" "200" "$STATUS_J2"

# ─────────────────────────────────────────────────────────────────────────────
section "K — Existing outbound WhatsApp configuration endpoint still works"
# ─────────────────────────────────────────────────────────────────────────────
info "GET /api/admin/whatsapp/config must still respond (admin auth required)"

RESP_K=$(curl -s -w "\n---STATUS:%{http_code}" -X GET \
  "${PB_BASE_URL}/api/admin/whatsapp/config" \
  -H "Authorization: Bearer $ADMIN_TOKEN")
STATUS_K=$(echo "$RESP_K" | grep "---STATUS:" | cut -d: -f2)
BODY_K=$(echo "$RESP_K" | grep -v "---STATUS:")
HAS_CONFIGURED_K=$(echo "$BODY_K" | jq 'has("configured")' 2>/dev/null || echo "false")

check_status "K. WhatsApp config endpoint returns 200"          "200"  "$STATUS_K"
check_json   "K. Response contains 'configured' field"          "true" "$HAS_CONFIGURED_K"

# ─────────────────────────────────────────────────────────────────────────────
section "L — Existing WhatsApp OTP endpoint still responds"
# ─────────────────────────────────────────────────────────────────────────────
info "POST /api/auth/request-whatsapp-otp with missing phone → 400 (not a crash)"

RESP_L=$(curl -s -w "\n---STATUS:%{http_code}" -X POST \
  "${PB_BASE_URL}/api/auth/request-whatsapp-otp" \
  -H "Content-Type: application/json" \
  --data-raw '{}')
STATUS_L=$(echo "$RESP_L" | grep "---STATUS:" | cut -d: -f2)
BODY_L=$(echo "$RESP_L" | grep -v "---STATUS:")
ERR_L=$(echo "$BODY_L" | jq -r '.error // ""')

check_status "L. OTP endpoint returns 400 for missing phone (not 500 or unreachable)" "400" "$STATUS_L"
check_json   "L. OTP response has error field"  "phone_required" "$ERR_L"

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
if [ "$FAIL" = "0" ]; then
  echo -e "  ${GREEN}${BOLD}All $TOTAL tests passed${NC}"
else
  echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC} of $TOTAL total"
fi
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}UNRESOLVED: Phase A Worker returns HTTP 200 to Meta even on PocketBase"
echo -e "  forwarding failure. Events during PocketBase downtime are silently lost."
echo -e "  Phase C must change the Worker to propagate 5xx to Meta to enable retries.${NC}"
echo ""

exit $FAIL
