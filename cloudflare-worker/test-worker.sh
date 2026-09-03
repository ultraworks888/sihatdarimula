#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# WhatsApp Gateway — Phase A Test Suite
# Tests A through H per the Phase A security requirements
#
# Usage:
#   chmod +x test-worker.sh
#   ./test-worker.sh
#
# Configure the three variables below before running.
# ─────────────────────────────────────────────────────────────────────────────

# ── Configure these before running ───────────────────────────────────────────
WORKER_URL="https://mhs-whatsapp-gateway.YOUR-SUBDOMAIN.workers.dev"
VERIFY_TOKEN="your-test-verify-token"   # Must match WA_WEBHOOK_VERIFY_TOKEN secret
APP_SECRET="your-test-app-secret"       # Must match META_APP_SECRET secret
# ─────────────────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✓ PASS${NC}: $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗ FAIL${NC}: $1"; ((FAIL++)); }
section() { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }
info() { echo -e "  ${YELLOW}→${NC} $1"; }

check() {
  local label=$1
  local expected=$2
  local actual=$3
  if [ "$actual" = "$expected" ]; then
    pass "$label (HTTP $actual)"
  else
    fail "$label (expected HTTP $expected, got HTTP $actual)"
  fi
}

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  My Healthy Start — WhatsApp Gateway · Phase A Tests  ${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "  Worker URL:   $WORKER_URL"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Reference payload — compact JSON, no extra whitespace.
# This is what we sign. The exact bytes matter.
# ─────────────────────────────────────────────────────────────────────────────
BODY='{"object":"whatsapp_business_account","entry":[{"id":"123456789","changes":[{"value":{"messaging_product":"whatsapp","metadata":{"display_phone_number":"60123456789","phone_number_id":"123456789"},"messages":[{"from":"60123456789","id":"wamid.TEST001","type":"text","text":{"body":"Hello test"},"timestamp":"1700000000"}]},"field":"messages"}]}]}'

# Compute correct HMAC-SHA256 over the ORIGINAL bytes
# printf '%s' avoids the newline that 'echo' appends
SIG=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$APP_SECRET" | sed 's/.*= //')

echo "  Reference body: $(echo -n "$BODY" | wc -c | tr -d ' ') bytes"
echo "  Reference HMAC: sha256=$SIG"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
section "POST Tests (HMAC verification)"
# ─────────────────────────────────────────────────────────────────────────────

# A. Valid Meta signature → HTTP 200
echo ""
info "Test A: Valid Meta signature over exact original bytes → accepted"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WORKER_URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG" \
  --data-binary "$BODY")
check "A. Valid signature" "200" "$STATUS"

# B. Invalid signature (all zeros) → HTTP 403
echo ""
info "Test B: Invalid signature value → rejected"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WORKER_URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=0000000000000000000000000000000000000000000000000000000000000000" \
  --data-binary "$BODY")
check "B. All-zero signature" "403" "$STATUS"

# C. Missing X-Hub-Signature-256 header entirely → HTTP 403
echo ""
info "Test C: Missing X-Hub-Signature-256 header → rejected"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WORKER_URL" \
  -H "Content-Type: application/json" \
  --data-binary "$BODY")
check "C. No signature header" "403" "$STATUS"

# D. Correct signature from original body, but body is modified before sending → HTTP 403
# Demonstrates: signature is body-specific, any mutation is detected
echo ""
info "Test D: Body tampered after signature was computed → rejected"
TAMPERED='{"object":"whatsapp_business_account","entry":[{"id":"ATTACKER_ID","changes":[]}]}'
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WORKER_URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG" \
  --data-binary "$TAMPERED")
check "D. Tampered body with original signature" "403" "$STATUS"

# E. Valid signature but JSON reformatted (added whitespace) → HTTP 403
# Demonstrates: HMAC covers exact bytes, not semantic JSON value.
# JSON.stringify(JSON.parse(body)) would produce a DIFFERENT byte sequence
# than the original — confirming why re-serialisation is never a valid HMAC input.
echo ""
info "Test E: Same JSON value, different formatting (whitespace added) → rejected"
REFORMATTED='{ "object": "whatsapp_business_account", "entry": [ { "id": "123456789", "changes": [ ] } ] }'
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WORKER_URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG" \
  --data-binary "$REFORMATTED")
check "E. Reformatted JSON with original HMAC" "403" "$STATUS"

# F. Valid signature and exact original bytes (explicit --data-binary) → HTTP 200
# Identical to A but uses --data-binary explicitly to guarantee curl does not
# transform the body in any way
echo ""
info "Test F: Valid signature + exact bytes via --data-binary → accepted"
SIG_F=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$APP_SECRET" | sed 's/.*= //')
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$WORKER_URL" \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIG_F" \
  --data-binary "$BODY")
check "F. Exact bytes + valid signature" "200" "$STATUS"

# ─────────────────────────────────────────────────────────────────────────────
section "GET Tests (webhook verification challenge)"
# ─────────────────────────────────────────────────────────────────────────────

# G. Missing hub.verify_token parameter → HTTP 400
echo ""
info "Test G: Missing hub.verify_token in GET request → rejected"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
  "${WORKER_URL}?hub.mode=subscribe&hub.challenge=challenge_abc123")
check "G. Missing verify_token param" "400" "$STATUS"

# H. Invalid verify token → HTTP 403
echo ""
info "Test H: Wrong hub.verify_token value → rejected"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X GET \
  "${WORKER_URL}?hub.mode=subscribe&hub.verify_token=WRONG_TOKEN_VALUE&hub.challenge=challenge_abc123")
check "H. Invalid verify_token value" "403" "$STATUS"

# ─────────────────────────────────────────────────────────────────────────────
section "GET — Valid verification (bonus)"
# ─────────────────────────────────────────────────────────────────────────────

# Bonus: Valid GET → HTTP 200 + challenge echoed exactly
echo ""
info "Bonus: Valid GET verification → 200 + challenge string echoed"
CHALLENGE="challenge_$(date +%s)_test"
RESPONSE=$(curl -s -w "\n---STATUS:%{http_code}" -X GET \
  "${WORKER_URL}?hub.mode=subscribe&hub.verify_token=${VERIFY_TOKEN}&hub.challenge=${CHALLENGE}")
HTTP_STATUS=$(echo "$RESPONSE" | grep "---STATUS:" | cut -d: -f2)
BODY_RESP=$(echo "$RESPONSE" | grep -v "---STATUS:")
if [ "$HTTP_STATUS" = "200" ] && [ "$BODY_RESP" = "$CHALLENGE" ]; then
  pass "Bonus: Valid GET → 200, challenge echoed exactly: '$BODY_RESP'"
  ((PASS++))
else
  fail "Bonus: Valid GET → HTTP $HTTP_STATUS, body: '$BODY_RESP' (expected '$CHALLENGE')"
  ((FAIL++))
fi

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

exit $FAIL
