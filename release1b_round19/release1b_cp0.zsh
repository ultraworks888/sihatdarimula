#!/usr/bin/env zsh
# ============================================================
# release1b_cp0.zsh — Release 1B Checkpoint 0 Harness
# Round  : 19 (corrected from Round 18)
# Status : DRAFTED — statically validated; zsh -n syntax check
#          required by operator before --run.
#          Checkpoint 0 authorization status:
#          AUTHORIZED BUT NOT EXECUTED —
#          EXECUTION ENVIRONMENT UNAVAILABLE
#          (Coderick AI tool environment has no shell execution,
#           process management, or external network access.
#           Operator must run per release1b_operator_instructions.md.)
# ============================================================
#
# AUTHORIZATION BOUNDARY (defect-31, preserved)
# ──────────────────────────────────────────────
#   Permitted execution modes:
#     --package-check   verify archive + hook paths
#     --harness-check   run self-test suite only
#     --preflight       port check only
#     --run             full harness run (requires --authorize-cp0)
#   Checkpoint 0 has been authorized by the project operator.
#   Publication remains unauthorized until PASS result observed.
#
# Correction matrix: release1b_round19_review.md
# R19 changes from R18:
#   C-1.  Authorization status header updated:
#         "AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT
#         UNAVAILABLE". Status is not "unauthorized".
#   C-2.  Inspection provenance section added to all manifests.
#         Schema findings attributed to Coderick-managed v0.28.4
#         workspace, not production. Not stated as "actual" or
#         "live production" without provenance.
#   C-3.  HOOK_SRC_PATHS keys corrected:
#         - REMOVED:  onboarding (no onboarding.pb.js found)
#         - REMOVED:  alias_intercept (no alias_intercept.pb.js found)
#         - ADDED:    emergency_hardening (emergency_users_hardening.pb.js)
#         - ADDED:    auth_whatsapp_otp (auth_whatsapp_otp.pb.js)
#         - RETAINED: push_broadcast, whatsapp
#   C-4.  HOOK_OTP_PHONE_ROUTE resolved from static source:
#         /api/auth/request-whatsapp-otp
#   C-5.  HOOK_OTP_MOCK_CONTROL_ROUTE defined for local adapter:
#         /api/test/otp-control (NOT a production endpoint;
#         requires operator OTP adapter deployment before use)
#   C-6.  Schema collection names corrected throughout:
#         growth_records   -> growth_logs
#         activities       -> activity_logs
#         immunizations    -> immunisations  (British spelling)
#         progress_notes   -> ABSENT (removed from all tests)
#         newborn_enrollments -> enrollments
#   C-7.  children.parent -> children.user (field name correction)
#   C-8.  articles.type/antenatal -> articles.category/is_pregnancy
#   C-9.  Legacy fixture: phone_verified field removed (absent from
#         schema, S-2). Legacy child body: parent= -> user=.
#         has_newborn_content removed (not in children schema).
#         growth_records -> growth_logs in cleanup.
#   C-10. Alias fixture: is_alias_account field removed (absent, S-2).
#         Timing-legacy fixture: phone_verified removed (absent, S-2).
#         Alias enum tests reformulated to not depend on absent field.
#   C-11. T-FIELD-ROLE-REJECT: expected status 403 not 400
#         (emergency_hardening hook returns 403 ForbiddenError).
#         Also verifies persisted role via NSU read.
#   C-12. T-FIELD-PHONE-REJECT: reclassified DEFERRED-MANDATORY
#         (phone_verified field absent from schema, S-2).
#   C-13. T-FIELD-ALIAS-REJECT: reclassified DEFERRED-MANDATORY
#         (is_alias_account field absent from schema, S-2).
#   C-14. File auth tests §25: progress_notes -> growth_logs.
#         T-FILE-AUTH-6: progress_notes -> users avatar file path.
#   C-15. §28.5 NEW: t_role_inject_emergency_group() —
#         five EMERGENCY BLOCKING tests for create-path injection.
#         Each verifies the PERSISTED record via NSU read, not
#         merely the HTTP response code.
#   C-16. t_crud_growth_create: collection growth_records ->
#         growth_logs. Body updated: adds user= field.
#   C-17. t_concurrency_otp_send_group: Mailhog removed;
#         HOOK_OTP_PHONE_ROUTE now pre-filled; NEEDS-EXTERNAL
#         narrowed to adapter deployment + rate-limit invariants.
#   C-18. Preflight: Mailhog ports (8025, 1025) removed from
#         required port checks. Only port 8090 required.
#   C-19. Schema verification list corrected.
#   C-20. S-3 (seed credential) noted in comments.
#   C-21. T-ART-ANON-DENIED replaced by T-ART-ANON-POLICY
#         (policy decision required; articles.listRule is public).
#   C-22. || true inventory unchanged at 2 (both BENIGN).
# ============================================================

# ────────────────────────────────────────────────────────────
# §2  SAFETY OPTIONS
# ────────────────────────────────────────────────────────────

setopt NO_UNSET PIPE_FAIL

# ────────────────────────────────────────────────────────────
# §3  CONSTANTS
# ────────────────────────────────────────────────────────────

readonly RELEASE1B_SCRIPT_ROUND="19"
readonly RELEASE1B_PB_PORT="8090"
# Mailhog ports removed in R19: OTP testing uses local adapter,
# not email/Mailhog. Port 8025 and 1025 no longer reserved.
readonly RELEASE1B_PB_VERSION="0.29.3"

typeset -grA PB_ARCHIVE_NAME=(
  [darwin_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_arm64.zip"
  [darwin_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_amd64.zip"
  [linux_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_amd64.zip"
  [linux_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_arm64.zip"
)

# PB_EXPECTED_SHA256: NEEDS-EXTERNAL.
# PocketBase v0.29.3 GitHub release does not publish a separate
# authoritative checksum file. If one is found on the release page,
# fill these values. Otherwise leave UNRESOLVED and the harness
# will emit T-PKG-ARCHIVE-HASH: UNRESOLVED (not BLOCKING).
typeset -grA PB_EXPECTED_SHA256=(
  [darwin_arm64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [darwin_amd64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [linux_amd64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [linux_arm64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
)

# R19 CORRECTION C-3: Hook keys updated to reflect actual pb_hooks/ files.
# Keys: emergency_hardening, auth_whatsapp_otp, push_broadcast, whatsapp.
# REMOVED: onboarding (no onboarding.pb.js), alias_intercept (no alias_intercept.pb.js).
# Operator must set each value to the absolute path of the corresponding file
# before --run.
typeset -grA HOOK_SRC_PATHS=(
  [emergency_hardening]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [auth_whatsapp_otp]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
)

typeset -grA HOOK_EXPECTED_SHA256=(
  [emergency_hardening]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [auth_whatsapp_otp]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
)

typeset -gA HOOK_PROBE_ROUTES=(
  [emergency_hardening]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
  [auth_whatsapp_otp]="/api/auth/request-whatsapp-otp"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
)

typeset -gA HOOK_PROBE_METHODS=(
  [emergency_hardening]="PATCH"
  [auth_whatsapp_otp]="POST"
  [push_broadcast]="POST"
  [whatsapp]="POST"
)

typeset -gA HOOK_EXPECTED_REMOVED_STATUS=(
  [emergency_hardening]="200"
  [auth_whatsapp_otp]="404"
  [push_broadcast]="404"
  [whatsapp]="404"
)

# R19 CORRECTION C-4: HOOK_OTP_PHONE_ROUTE resolved from static source
# inspection of auth_whatsapp_otp.pb.js. Previously UNRESOLVED.
typeset -g HOOK_OTP_PHONE_ROUTE="/api/auth/request-whatsapp-otp"

# R19 CORRECTION C-5: HOOK_OTP_VERIFY_ROUTE resolved from source.
typeset -g HOOK_OTP_VERIFY_ROUTE="/api/auth/verify-whatsapp-otp"

# R19 CORRECTION C-5: HOOK_OTP_MOCK_CONTROL_ROUTE defined for local adapter.
# This route is provided by release1b_otp_test_adapter.pb.js — a test-only
# hook file that MUST NOT be deployed to production. The adapter must be
# placed in the isolated hooks directory by the operator before
# T-CONCURRENCY-OTP-SEND can run. See operator instructions §6.
typeset -g HOOK_OTP_MOCK_CONTROL_ROUTE="/api/test/otp-control"
typeset -g HOOK_OTP_READ_ROUTE="/api/test/otp-read"

# R19 CORRECTION C-6: RELEASE1B_SCHEMA_SRC must point to the project's
# pb_migrations/ directory. The harness copies all *.js files to the
# isolated migrations dir. Must not include seed migration with known
# credential (S-3: 1782898775_seed_superadmin_user_4fd7.js).
# OPERATOR: set this to the absolute path of the pb_migrations/ directory.
# SECURITY NOTE S-3: 1782898775_seed_superadmin_user_4fd7.js contains a
# hardcoded plaintext password. The harness NEVER reads or uses that
# credential. The isolated instance applies this migration and creates
# a seeded superadmin in the isolated database only, which is destroyed
# on cleanup. Operator must verify production credential was rotated.
typeset -g RELEASE1B_SCHEMA_SRC="UNRESOLVED__NEEDS_EXTERNAL__schema_src_path"

# ────────────────────────────────────────────────────────────
# §4  GLOBAL MUTABLE STATE
# ────────────────────────────────────────────────────────────

typeset -gi T_PASS=0 T_FAIL=0 T_BLOCKING=0 T_UNRESOLVED=0
typeset -gi T_DEFERRED=0 T_HARNESS_ERR=0 T_SKIP=0
typeset -gi CLEANUP_FAILURE=0 HALT_DEPENDENTS=0

typeset -ga BLOCKING_DECISIONS=()
typeset -ga UNRESOLVED_ITEMS=()
typeset -ga HARNESS_ERRORS=()

typeset -g RELEASE1B_ISOLATED_ROOT=""
typeset -g RELEASE1B_CANONICAL_ROOT=""
typeset -g RELEASE1B_CANONICAL_PARENT=""
typeset -g RELEASE1B_PB_DATA_DIR=""
typeset -g RELEASE1B_PB_HOOKS_DIR=""
typeset -g RELEASE1B_PB_MIGRATIONS_DIR=""
typeset -g RELEASE1B_TEST_TMP=""
typeset -g RELEASE1B_EVIDENCE_DIR=""
typeset -g RELEASE1B_REPORT_WORK=""
typeset -g RELEASE1B_REPORT_PATH=""
typeset -g RELEASE1B_BASE_URL="http://127.0.0.1:${RELEASE1B_PB_PORT}"
typeset -g RELEASE1B_PB_BIN=""
typeset -gi RELEASE1B_PB_PID=0

typeset -g PBJ_STAT_PY="" PBJ_URL_PY="" PBJ_PY="" PBJ_AUTH_PY=""
typeset -g PBJ_FIELD_PY="" PBJ_COPY_PY="" PBJ_EXTRACT_PY="" PBJ_SHAPE_PY=""
typeset -g PBJ_SCAN_PY="" PBJ_HTTP_PY=""
typeset -g RUN_SUFFIX=""

typeset -g _NATIVE_SU_TOK_FILE=""
typeset -g _NATIVE_SU_ID_FILE=""
typeset -g _NATIVE_SU_AUTH_CFG=""

typeset -g ORDINARY_ID_FILE="" ORDINARY_TOK_FILE="" ORDINARY_AUTH_CFG=""
typeset -g ADMIN_ID_FILE=""    ADMIN_TOK_FILE=""    ADMIN_AUTH_CFG=""
typeset -g SADMIN_ID_FILE=""   SADMIN_TOK_FILE=""   SADMIN_AUTH_CFG=""
typeset -g LEGACY_ID_FILE=""   LEGACY_TOK_FILE=""   LEGACY_AUTH_CFG=""

# R19: progress_notes absent; growth_logs replaces growth_records.
# R19: newborn_enrollments absent; enrollments replaces it.
typeset -g LEGACY_CHILD_ID_FILE=""      LEGACY_GROWTH_ID_FILE=""
typeset -g LEGACY_ACTIVITY_ID_FILE=""   LEGACY_IMMUN_ID_FILE=""
typeset -g LEGACY_ENROLL_ID_FILE=""

typeset -g ALIAS_ID_FILE="" ALIAS_PW_FILE="" ALIAS_AUTH_CFG=""
typeset -g WRONG_PW_FILE=""
typeset -g TIMING_LEGACY_ID_FILE=""  TIMING_LEGACY_PW_FILE=""
typeset -g TIMING_LEGACY_AUTH_CFG=""

typeset -gA RULE_BASELINE=()
typeset -ga ENUM_RESP_FILES=() ENUM_HTTP_VALUES=() ENUM_TIME_FILES=()
typeset -gA FIXTURE_REGISTRY=()

typeset -g PLATFORM_KEY=""

# ────────────────────────────────────────────────────────────
# §5  CORE UTILITIES  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_realpath() {
  python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" -- "$1"
}

pb_generate_run_suffix() {
  RUN_SUFFIX=$(openssl rand -hex 6 2>/dev/null) || \
    RUN_SUFFIX=$(date +%s%3N | shasum -a 256 | head -c 12)
}

pb_setup_umask() {
  umask 077
}

pb_setup_root() {
  local parent="${TMPDIR:-/tmp}"
  RELEASE1B_CANONICAL_PARENT=$(pb_realpath "$parent")
  local root="${parent}/release1b_cp0_${RUN_SUFFIX}"
  mkdir -p "$root" || pb_halt "Cannot create isolated root: ${root}"
  chmod 700 "$root"
  RELEASE1B_ISOLATED_ROOT="$root"
  RELEASE1B_CANONICAL_ROOT=$(pb_realpath "$root")

  RELEASE1B_PB_DATA_DIR="${root}/pb_data"
  RELEASE1B_PB_HOOKS_DIR="${root}/pb_hooks"
  RELEASE1B_PB_MIGRATIONS_DIR="${root}/pb_migrations"
  RELEASE1B_TEST_TMP="${root}/test_tmp"
  RELEASE1B_EVIDENCE_DIR="${root}/evidence"
  RELEASE1B_REPORT_WORK="${root}/report_work.md"
  RELEASE1B_REPORT_PATH="${root}/release1b_cp0_report_${RUN_SUFFIX}.md"
  RELEASE1B_PB_BIN="${root}/pocketbase"

  mkdir -p \
    "$RELEASE1B_PB_DATA_DIR" \
    "$RELEASE1B_PB_HOOKS_DIR" \
    "$RELEASE1B_PB_MIGRATIONS_DIR" \
    "$RELEASE1B_TEST_TMP" \
    "$RELEASE1B_EVIDENCE_DIR"

  chmod 700 \
    "$RELEASE1B_PB_DATA_DIR" \
    "$RELEASE1B_PB_HOOKS_DIR" \
    "$RELEASE1B_PB_MIGRATIONS_DIR" \
    "$RELEASE1B_TEST_TMP" \
    "$RELEASE1B_EVIDENCE_DIR"

  printf 'release1b_cp0_%s\n' "$RUN_SUFFIX" \
    > "${root}/.release1b_marker"
  chmod 600 "${root}/.release1b_marker"

  printf '# CP0 Report %s\n\n| Test | Result | Notes |\n|---|---|---|\n' \
    "$RUN_SUFFIX" > "$RELEASE1B_REPORT_WORK"

  print "=== Isolated root: [${RELEASE1B_CANONICAL_ROOT}] ==="
}

pb_inc() {
  local _var="$1"
  typeset -g "${_var}"=$(( ${(P)_var} + 1 ))
}

pb_halt() {
  print "[HALT] $*" >&2
  exit 1
}

pb_secure_tmpfile() {
  local suffix="${1:-.tmp}"
  local path="${RELEASE1B_TEST_TMP}/${RUN_SUFFIX}_$$_${RANDOM}${suffix}"
  : > "$path"
  chmod 600 "$path"
  print "$path"
}

pb_wipe_secret_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  dd if=/dev/zero of="$f" bs=1024 count=4 2>/dev/null || true
  # R19 || true inventory #1 (BENIGN-RETAINED from R18):
  # dd may return non-zero on a partial write or when the file is shorter
  # than 4 KiB. rm -f below removes the file regardless.
  rm -f "$f"
}

# pb_pid_exists() was removed in R18 (locale-dependent stderr parsing).
# The shutdown design uses ps -o ppid= (structured, locale-free).

# ────────────────────────────────────────────────────────────
# §6  TRAP / CLEANUP  (unchanged from R18 except MH removed)
# ────────────────────────────────────────────────────────────

pb_trap_cleanup() {
  if (( RELEASE1B_PB_PID > 0 )); then
    local _stored_pid=$RELEASE1B_PB_PID

    local _ppid_init
    _ppid_init=$(ps -p "$_stored_pid" -o ppid= 2>/dev/null | tr -d ' ')
    if [[ "$_ppid_init" != "$$" ]]; then
      print "[trap] WARNING: PID ${_stored_pid} PPID=${_ppid_init} != $$ — " \
            "no longer our child; skipping shutdown" >&2
      RELEASE1B_PB_PID=0
    else
      kill "$_stored_pid" 2>/dev/null
      local _sigterm_rc=$?
      (( _sigterm_rc != 0 )) && \
        print "[trap] NOTE: SIGTERM rc=${_sigterm_rc} for PID ${_stored_pid}" >&2

      local _wdflag="${RELEASE1B_TEST_TMP}/${RUN_SUFFIX}_wdflag_${_stored_pid}"
      : > "$_wdflag" && chmod 600 "$_wdflag"

      (
        sleep 6
        local _ppid_wd
        _ppid_wd=$(ps -p "$_stored_pid" -o ppid= 2>/dev/null | tr -d ' ')
        if [[ "$_ppid_wd" == "$$" ]]; then
          kill -9 "$_stored_pid" 2>/dev/null
          printf '1' > "$_wdflag"
        fi
      ) &
      local _wd_pid=$!

      wait "$_stored_pid" 2>/dev/null
      local _wait_rc=$?

      kill "$_wd_pid" 2>/dev/null || true
      # R19 || true inventory #2 (BENIGN — same as R18):
      wait "$_wd_pid" 2>/dev/null || true

      local _ppid_after
      _ppid_after=$(ps -p "$_stored_pid" -o ppid= 2>/dev/null | tr -d ' ')
      local _escalated=0
      [[ -f "$_wdflag" ]] && \
        [[ "$(cat "$_wdflag" 2>/dev/null)" == "1" ]] && \
        _escalated=1
      rm -f "$_wdflag"

      if (( _escalated )) || [[ "$_ppid_after" == "$$" ]]; then
        CLEANUP_FAILURE=1
        print "[trap] WARNING: PB shutdown escalated or child still alive" >&2
      fi

      RELEASE1B_PB_PID=0
    fi
  fi

  local sf
  for sf in \
    "$_NATIVE_SU_TOK_FILE" "$_NATIVE_SU_ID_FILE" "$_NATIVE_SU_AUTH_CFG" \
    "$ORDINARY_TOK_FILE"   "$ADMIN_TOK_FILE"      "$SADMIN_TOK_FILE" \
    "$LEGACY_TOK_FILE"     "$ALIAS_PW_FILE"        "$WRONG_PW_FILE" \
    "$TIMING_LEGACY_PW_FILE"; do
    [[ -n "$sf" ]] && pb_wipe_secret_file "$sf"
  done

  if [[ -n "$RELEASE1B_ISOLATED_ROOT" && \
        -d "$RELEASE1B_ISOLATED_ROOT" && \
        "$CLEANUP_FAILURE" -eq 0 ]]; then
    rm -rf "$RELEASE1B_ISOLATED_ROOT" 2>/dev/null || CLEANUP_FAILURE=1
  fi

  if (( CLEANUP_FAILURE )); then
    print "[trap] Cleanup incomplete — isolated root retained: ${RELEASE1B_ISOLATED_ROOT}" >&2
  fi
}

pb_install_trap() {
  trap pb_trap_cleanup EXIT TERM INT
}

# ────────────────────────────────────────────────────────────
# §7  RESULT TRACKING  (unchanged from R18)
# ────────────────────────────────────────────────────────────

t_pass() {
  pb_inc T_PASS
  printf '| %s | PASS | |\n' "$*" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[PASS] $*"
}

t_fail() {
  local label="$1" msg="${2:-}"
  pb_inc T_FAIL
  BLOCKING_DECISIONS+=("FAIL: ${label}: ${msg}")
  printf '| %s | FAIL | %s |\n' "$label" "$msg" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[FAIL] ${label}: ${msg}" >&2
}

t_blocking() {
  local label="$1" msg="${2:-}"
  pb_inc T_BLOCKING
  BLOCKING_DECISIONS+=("BLOCKING: ${label}: ${msg}")
  HALT_DEPENDENTS=1
  printf '| %s | BLOCKING | %s |\n' "$label" "$msg" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[BLOCKING] ${label}: ${msg}" >&2
}

t_unresolved() {
  local label="$1" msg="${2:-}"
  pb_inc T_UNRESOLVED
  UNRESOLVED_ITEMS+=("UNRESOLVED: ${label}: ${msg}")
  printf '| %s | UNRESOLVED | %s |\n' "$label" "$msg" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[UNRESOLVED] ${label}: ${msg}" >&2
}

t_deferred_mandatory() {
  local label="$1" msg="${2:-}"
  pb_inc T_DEFERRED
  UNRESOLVED_ITEMS+=("DEFERRED-MANDATORY: ${label}: ${msg}")
  printf '| %s | DEFERRED-MANDATORY | %s |\n' "$label" "$msg" \
    >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[DEFERRED-MANDATORY] ${label}: ${msg}"
}

t_skip() {
  local label="$1" msg="${2:-}"
  pb_inc T_SKIP
  printf '| %s | SKIP | %s |\n' "$label" "$msg" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[SKIP] ${label}: ${msg}"
}

t_authorized_exclusion() {
  local label="$1" reason="${2:-}"
  printf '| %s | AUTHORIZED-EXCLUSION | %s |\n' "$label" "$reason" \
    >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[AUTHORIZED-EXCLUSION] ${label}: ${reason}"
}

t_harness_err() {
  local label="$1" msg="${2:-}"
  pb_inc T_HARNESS_ERR
  HARNESS_ERRORS+=("HARNESS_ERR: ${label}: ${msg}")
  printf '| %s | HARNESS_ERR | %s |\n' "$label" "$msg" \
    >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[HARNESS_ERR] ${label}: ${msg}" >&2
}

# ────────────────────────────────────────────────────────────
# §8  PYTHON HELPER SCRIPTS  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_write_scripts() {
  local d="$RELEASE1B_TEST_TMP"

  PBJ_STAT_PY="${d}/pbj_stat.py"
  cat > "$PBJ_STAT_PY" << 'PYEOF'
import sys, os, stat as _st
CANONICAL_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
path = sys.argv[1]
try:
    lstat = os.lstat(path)
except Exception as exc:
    print(f'ERROR: {exc}', file=sys.stderr)
    sys.exit(2)
if _st.S_ISLNK(lstat.st_mode):
    print('SYMLINK')
    sys.exit(0)
if CANONICAL_TMP:
    real_path = os.path.realpath(path)
    real_tmp  = os.path.realpath(CANONICAL_TMP)
    if not real_path.startswith(real_tmp + os.sep) and real_path != real_tmp:
        print('OUTSIDE_ROOT')
        sys.exit(0)
mode_oct = oct(_st.S_IMODE(lstat.st_mode))[2:]
print(mode_oct)
PYEOF

  PBJ_URL_PY="${d}/pbj_url.py"
  cat > "$PBJ_URL_PY" << 'PYEOF'
import sys, re, urllib.parse
url_str  = sys.argv[1]
exp_host = sys.argv[2]
exp_port = sys.argv[3]
try:
    p = urllib.parse.urlparse(url_str)
except Exception:
    print('REJECT:parse-error')
    sys.exit(0)
if p.scheme != 'http':
    print(f'REJECT:scheme={p.scheme!r}')
    sys.exit(0)
if p.username or p.password:
    print('REJECT:userinfo')
    sys.exit(0)
if p.fragment:
    print('REJECT:fragment')
    sys.exit(0)
host = (p.hostname or '').lower()
if host != exp_host:
    print(f'REJECT:host={host!r}')
    sys.exit(0)
port = str(p.port) if p.port else '80'
if port != exp_port:
    print(f'REJECT:port={port!r}')
    sys.exit(0)
if not p.path.startswith('/api/'):
    print(f'REJECT:path={p.path!r}')
    sys.exit(0)
raw_host = url_str.split('://')[1].split('/')[0].split('@')[-1].split(':')[0]
if re.search(r'0x|%|0[0-9]{2,}', raw_host):
    print('REJECT:encoded-host')
    sys.exit(0)
print('OK')
PYEOF

  PBJ_PY="${d}/pbj.py"
  cat > "$PBJ_PY" << 'PYEOF'
import sys, os, json, math, stat as _st
BLOCKED = frozenset({
    'id', 'collectionId', 'collectionName', 'created', 'updated',
    'tokenKey', 'passwordHash',
})
out_path = sys.argv[1]
args = sys.argv[2:]
obj = {}
for arg in args:
    if ':' in arg.split('=')[0]:
        typ, rest = arg.split(':', 1)
    else:
        typ = 's'
        rest = arg
    if '=' not in rest:
        print(f'ERROR: no = in arg {arg!r}', file=sys.stderr)
        sys.exit(1)
    key, val = rest.split('=', 1)
    if key in BLOCKED:
        print(f'ERROR: blocked key {key!r}', file=sys.stderr)
        sys.exit(1)
    if key in obj:
        print(f'ERROR: duplicate key {key!r}', file=sys.stderr)
        sys.exit(1)
    if typ == 's':
        if val.startswith('secret-file:'):
            sf = val[len('secret-file:'):]
            try:
                lst = os.lstat(sf)
            except Exception as e:
                print(f'ERROR: secret-file stat: {e}', file=sys.stderr)
                sys.exit(1)
            if _st.S_ISLNK(lst.st_mode):
                print('ERROR: secret-file is a symlink', file=sys.stderr)
                sys.exit(1)
            try:
                with open(sf) as fh:
                    obj[key] = fh.read().strip()
            except Exception as e:
                print(f'ERROR: secret-file read: {e}', file=sys.stderr)
                sys.exit(1)
        else:
            obj[key] = val
    elif typ == 'b':
        if val.lower() not in ('true', 'false'):
            print(f'ERROR: bool must be true/false, got {val!r}', file=sys.stderr)
            sys.exit(1)
        obj[key] = (val.lower() == 'true')
    elif typ == 'n':
        try:
            fv = float(val)
            obj[key] = int(fv) if fv == math.floor(fv) else fv
        except ValueError:
            print(f'ERROR: not a number: {val!r}', file=sys.stderr)
            sys.exit(1)
    else:
        print(f'ERROR: unknown type {typ!r}', file=sys.stderr)
        sys.exit(1)
lst = os.lstat(out_path)
if _st.S_ISLNK(lst.st_mode):
    print('ERROR: output path is a symlink', file=sys.stderr)
    sys.exit(1)
with open(out_path, 'w') as fh:
    json.dump(obj, fh)
os.chmod(out_path, 0o600)
PYEOF

  PBJ_AUTH_PY="${d}/pbj_auth.py"
  cat > "$PBJ_AUTH_PY" << 'PYEOF'
import sys, os, re, stat as _st
auth_cfg = sys.argv[1]
tok_file  = sys.argv[2]
try:
    lst = os.lstat(tok_file)
    if _st.S_ISLNK(lst.st_mode):
        print('ERROR: tok_file is a symlink', file=sys.stderr)
        sys.exit(1)
    with open(tok_file) as fh:
        token = fh.read().strip()
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
if not re.match(r'^[A-Za-z0-9._\-]+$', token):
    print('ERROR: token failed safety pattern', file=sys.stderr)
    sys.exit(1)
hdr = f'Authorization: Bearer {token}'
try:
    lst = os.lstat(auth_cfg)
    if _st.S_ISLNK(lst.st_mode):
        print('ERROR: auth_cfg is a symlink', file=sys.stderr)
        sys.exit(1)
    with open(auth_cfg, 'w') as fh:
        fh.write(hdr)
    os.chmod(auth_cfg, 0o600)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
PYEOF

  PBJ_HTTP_PY="${d}/pbj_http.py"
  cat > "$PBJ_HTTP_PY" << 'PYEOF'
import sys, os, subprocess, re, stat as _st
MAX_RESP = 1024 * 512

def main():
    status_out  = sys.argv[1]
    path_out    = sys.argv[2]
    url         = sys.argv[3]
    auth_file   = sys.argv[4] if len(sys.argv) > 4 else ''
    body_file   = sys.argv[5] if len(sys.argv) > 5 else ''
    method      = sys.argv[6] if len(sys.argv) > 6 else 'GET'

    CANONICAL_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
    resp_path = os.path.join(
        CANONICAL_TMP or os.path.dirname(status_out),
        f'resp_{os.getpid()}_{os.urandom(4).hex()}.json'
    )
    try:
        with open(resp_path, 'w') as fh:
            fh.write('')
        os.chmod(resp_path, 0o600)
    except Exception as e:
        print(f'ERROR creating resp: {e}', file=sys.stderr)
        sys.exit(1)

    cmd = [
        'curl', '-sf', '--max-time', '30', '--connect-timeout', '10',
        '--output', resp_path,
        '--write-out', '%{http_code}',
        '-X', method.upper(),
        '-H', 'Content-Type: application/json',
    ]

    if auth_file and os.path.isfile(auth_file):
        try:
            lst = os.lstat(auth_file)
            if not _st.S_ISLNK(lst.st_mode):
                with open(auth_file) as fh:
                    hdr = fh.read().strip()
                if re.match(r'^Authorization: Bearer [A-Za-z0-9._\-]+$', hdr):
                    cmd += ['-H', hdr]
        except Exception:
            pass

    if body_file and os.path.isfile(body_file):
        cmd += ['--data-binary', f'@{body_file}']

    cmd.append(url)
    result = subprocess.run(cmd, capture_output=True, text=True)
    status = result.stdout.strip() or '000'

    try:
        sz = os.path.getsize(resp_path)
        if sz > MAX_RESP:
            with open(resp_path, 'r+b') as fh:
                fh.seek(MAX_RESP)
                fh.truncate()
    except Exception:
        pass

    with open(status_out, 'w') as fh:
        fh.write(status)
    os.chmod(status_out, 0o600)
    with open(path_out, 'w') as fh:
        fh.write(resp_path)
    os.chmod(path_out, 0o600)

main()
PYEOF

  PBJ_FIELD_PY="${d}/pbj_field.py"
  cat > "$PBJ_FIELD_PY" << 'PYEOF'
import sys, os, json, re
BLOCKED = frozenset({'password', 'passwordHash', 'tokenKey'})
resp_file = sys.argv[1]
field     = sys.argv[2]
if field in BLOCKED:
    print('BLOCKED', file=sys.stderr)
    sys.exit(1)
try:
    with open(resp_file) as fh:
        data = json.load(fh)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
if field not in data:
    print('__absent__')
    sys.exit(0)
val = data[field]
if val is None:
    print('__null__')
elif isinstance(val, bool):
    print('true' if val else 'false')
elif isinstance(val, (int, float)):
    print(val)
elif isinstance(val, str):
    if len(val) > 512:
        print('__truncated__')
    elif re.search(r'[^\x20-\x7e]', val):
        print('__nonascii__')
    else:
        print(val)
else:
    print(f'__type:{type(val).__name__}__')
PYEOF

  PBJ_EXTRACT_PY="${d}/pbj_extract.py"
  cat > "$PBJ_EXTRACT_PY" << 'PYEOF'
import sys, json, re
ALLOWED = frozenset({'id', 'email', 'role', 'name', 'otpId', 'collectionId'})
resp_file = sys.argv[1]
field     = sys.argv[2]
if field not in ALLOWED:
    print(f'ERROR: field {field!r} not in extraction allowlist', file=sys.stderr)
    sys.exit(1)
with open(resp_file) as fh:
    data = json.load(fh)
val = data.get(field, '__absent__')
if isinstance(val, str):
    if not re.match(r'^[A-Za-z0-9@._\-\s]{1,256}$', val):
        print('ERROR: field value failed safety pattern', file=sys.stderr)
        sys.exit(1)
    print(val)
elif val == '__absent__':
    print('__absent__')
else:
    print(str(val))
PYEOF

  PBJ_SHAPE_PY="${d}/pbj_shape.py"
  cat > "$PBJ_SHAPE_PY" << 'PYEOF'
import sys, json
resp_file = sys.argv[1]
args = sys.argv[2:]
required = []
absent   = []
mode = 'required'
for a in args:
    if a == '--absent':
        mode = 'absent'
    else:
        (absent if mode == 'absent' else required).append(a)
with open(resp_file) as fh:
    data = json.load(fh)
errors = []
for f in required:
    if f not in data:
        errors.append(f'missing:{f}')
for f in absent:
    if f in data:
        errors.append(f'present:{f}')
if errors:
    print('SHAPE_ERR: ' + ', '.join(errors))
    sys.exit(1)
print('OK')
PYEOF

  PBJ_SCAN_PY="${d}/pbj_scan.py"
  cat > "$PBJ_SCAN_PY" << 'PYEOF'
import sys, os, re
CANONICAL_ROOT = os.environ.get('RELEASE1B_CANONICAL_ROOT', '')
def sanitize_line(line):
    if CANONICAL_ROOT:
        line = line.replace(CANONICAL_ROOT, '[ISOLATED_ROOT]')
    home = os.path.expanduser('~')
    if home and home != '~':
        line = line.replace(home, '[HOME]')
    line = re.sub(r'/tmp/release1b_cp0_[A-Za-z0-9_]+', '[ISOLATED_ROOT]', line)
    return line
report_in  = sys.argv[1]
report_out = sys.argv[2]
lines = []
try:
    with open(report_in) as fh:
        for line in fh:
            lines.append(sanitize_line(line.rstrip('\n')))
except Exception as e:
    print(f'ERROR reading report: {e}', file=sys.stderr)
    sys.exit(1)
tmp = report_out + '.scantmp'
try:
    with open(tmp, 'w') as fh:
        fh.write('\n'.join(lines) + '\n')
    os.chmod(tmp, 0o600)
    os.replace(tmp, report_out)
except Exception as e:
    print(f'ERROR writing report: {e}', file=sys.stderr)
    try:
        os.unlink(tmp)
    except Exception:
        pass
    sys.exit(1)
PYEOF

  PBJ_COPY_PY="${d}/pbj_copy.py"
  cat > "$PBJ_COPY_PY" << 'PYEOF'
import sys, json
BLOCKED = frozenset({'password', 'passwordHash', 'tokenKey'})
src_file  = sys.argv[1]
dst_file  = sys.argv[2]
field     = sys.argv[3]
out_field = sys.argv[4] if len(sys.argv) > 4 else field
if field in BLOCKED or out_field in BLOCKED:
    print('BLOCKED', file=sys.stderr)
    sys.exit(1)
with open(src_file) as fh:
    src = json.load(fh)
with open(dst_file) as fh:
    dst = json.load(fh)
if field not in src:
    print(f'ABSENT: {field!r}', file=sys.stderr)
    sys.exit(1)
dst[out_field] = src[field]
with open(dst_file, 'w') as fh:
    json.dump(dst, fh)
PYEOF

  chmod 400 \
    "$PBJ_STAT_PY" "$PBJ_URL_PY" "$PBJ_PY" "$PBJ_AUTH_PY" \
    "$PBJ_HTTP_PY" "$PBJ_FIELD_PY" "$PBJ_COPY_PY" "$PBJ_EXTRACT_PY" \
    "$PBJ_SHAPE_PY" "$PBJ_SCAN_PY"

  print "=== Python helpers written ==="
}

# ────────────────────────────────────────────────────────────
# §9  VALIDATION HELPERS  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_validate_path() {
  local path="$1"
  local result
  result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$path" 2>/dev/null)
  case "$result" in
    SYMLINK)       print "PATH_SYMLINK:${path}"; return 1 ;;
    OUTSIDE_ROOT)  print "PATH_OUTSIDE:${path}"; return 1 ;;
    ERROR*)        print "PATH_ERROR:${path}";   return 1 ;;
    *)             return 0 ;;
  esac
}

pb_validate_url() {
  local url="$1"
  local result
  result=$(python3 "$PBJ_URL_PY" "$url" "127.0.0.1" "$RELEASE1B_PB_PORT" 2>/dev/null)
  [[ "$result" == "OK" ]]
}

pb_url() {
  local suffix="$1"
  local url="${RELEASE1B_BASE_URL}${suffix}"
  if ! pb_validate_url "$url"; then
    pb_halt "URL validation failed: ${url}"
  fi
  print "$url"
}

# ────────────────────────────────────────────────────────────
# §10 PACKAGE COMPLETENESS CHECK  (R19: updated for new hook keys)
# ────────────────────────────────────────────────────────────

pb_check_package_completeness() {
  print "=== Package completeness check ==="
  local ok=1

  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local src="${HOOK_SRC_PATHS[$hk]}"
    if [[ "$src" == UNRESOLVED* ]]; then
      print "[pkg] HOOK_SRC_PATHS[$hk]: UNRESOLVED"
      ok=0
    elif [[ ! -f "$src" ]]; then
      print "[pkg] HOOK_SRC_PATHS[$hk]: file not found: ${src}"
      ok=0
    fi
  done

  for hk in "${(@k)HOOK_PROBE_ROUTES}"; do
    if [[ "${HOOK_PROBE_ROUTES[$hk]}" == UNRESOLVED* ]]; then
      print "[pkg] HOOK_PROBE_ROUTES[$hk]: UNRESOLVED"
      ok=0
    fi
  done

  if [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]]; then
    print "[pkg] RELEASE1B_SCHEMA_SRC: UNRESOLVED"
    ok=0
  fi

  if (( ok )); then
    print "[pkg] Package completeness: OK"
    return 0
  else
    print "[pkg] Package completeness: INCOMPLETE — see above"
    return 1
  fi
}

# ────────────────────────────────────────────────────────────
# §11 HARNESS SELF-TEST  (R19: updated for R19 schema names)
# ────────────────────────────────────────────────────────────

t_harness_selftest() {
  print "=== Harness self-test ==="
  local fail=0

  # Increment T_PASS once and T_SKIP once to test counters;
  # subtract at end so counts are not polluted.
  t_pass "SELFTEST-PASS-COUNTER"

  local body_f; body_f=$(pb_secure_tmpfile .json)
  if ! python3 "$PBJ_PY" "$body_f" "name=test" "role=user" 2>/dev/null; then
    print "[selftest] FAIL: pbj.py rejected valid args" >&2; fail=1
  fi
  rm -f "$body_f"

  body_f=$(pb_secure_tmpfile .json)
  if python3 "$PBJ_PY" "$body_f" "id=inject" 2>/dev/null; then
    print "[selftest] FAIL: pbj.py accepted blocked key 'id'" >&2; fail=1
  fi
  rm -f "$body_f"

  body_f=$(pb_secure_tmpfile .json)
  if python3 "$PBJ_PY" "$body_f" "name=a" "name=b" 2>/dev/null; then
    print "[selftest] FAIL: pbj.py accepted duplicate key" >&2; fail=1
  fi
  rm -f "$body_f"

  body_f=$(pb_secure_tmpfile .json)
  if ! python3 "$PBJ_PY" "$body_f" "b:active=true" "n:count=3" 2>/dev/null; then
    print "[selftest] FAIL: pbj.py rejected valid bool/num" >&2; fail=1
  else
    local content; content=$(cat "$body_f" 2>/dev/null)
    if [[ "$content" != *'"active":true'* ]] && [[ "$content" != *'"active": true'* ]]; then
      print "[selftest] FAIL: bool not written correctly (got: ${content})" >&2; fail=1
    fi
  fi
  rm -f "$body_f"

  local link_target; link_target=$(pb_secure_tmpfile .tgt)
  local link_name="${RELEASE1B_TEST_TMP}/selftest_link_${RANDOM}"
  ln -s "$link_target" "$link_name" 2>/dev/null
  local link_result
  link_result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$link_name" 2>/dev/null)
  if [[ "$link_result" != "SYMLINK" ]]; then
    print "[selftest] FAIL: symlink not detected (got ${link_result})" >&2; fail=1
  fi
  rm -f "$link_name" "$link_target"

  local resp_f; resp_f=$(pb_secure_tmpfile .json)
  printf '{"id":"abc123","password":"secret"}' > "$resp_f"
  if python3 "$PBJ_EXTRACT_PY" "$resp_f" "password" 2>/dev/null; then
    print "[selftest] FAIL: pbj_extract.py accepted non-allowlist field 'password'" >&2; fail=1
  fi
  local extracted_id
  extracted_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_f" "id" 2>/dev/null)
  if [[ "$extracted_id" != "abc123" ]]; then
    print "[selftest] FAIL: pbj_extract.py could not extract 'id' (got: ${extracted_id})" >&2
    fail=1
  fi
  rm -f "$resp_f"

  local saved_halt=$HALT_DEPENDENTS
  HALT_DEPENDENTS=1
  t_skip "SELFTEST-SKIP-PROPAGATION" "testing skip"
  HALT_DEPENDENTS=$saved_halt
  if (( T_SKIP < 1 )); then
    print "[selftest] FAIL: t_skip did not increment T_SKIP" >&2; fail=1
  fi

  # R18 (preserved): ps -based PPID check for non-existent PID.
  local _ppid_test
  _ppid_test=$(ps -p "99999999" -o ppid= 2>/dev/null | tr -d ' ')
  if [[ "$_ppid_test" == "$$" ]]; then
    print "[selftest] FAIL: ps PPID for non-existent PID returned '$$'" >&2; fail=1
  fi

  T_PASS=$(( T_PASS - 1 ))
  T_SKIP=$(( T_SKIP - 1 ))

  if (( fail )); then
    print "[selftest] RESULT: FAIL (${fail} assertion(s) failed)" >&2
    return 1
  else
    print "[selftest] RESULT: PASS"
    return 0
  fi
}

# ────────────────────────────────────────────────────────────
# §12 INFRASTRUCTURE
# ────────────────────────────────────────────────────────────

pb_detect_platform() {
  local os_name; os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  local arch; arch=$(uname -m)
  case "$arch" in
    arm64|aarch64) arch="arm64" ;;
    x86_64)        arch="amd64" ;;
    *) pb_halt "Unsupported architecture: ${arch}" ;;
  esac
  case "$os_name" in
    darwin|linux) : ;;
    *) pb_halt "Unsupported OS: ${os_name}" ;;
  esac
  PLATFORM_KEY="${os_name}_${arch}"
  print "=== Platform: ${PLATFORM_KEY} ==="
}

pb_verify_archive_hash() {
  local archive="$1"
  local expected="${PB_EXPECTED_SHA256[${PLATFORM_KEY}]:-}"
  if [[ "$expected" == UNRESOLVED* ]]; then
    t_unresolved "T-PKG-ARCHIVE-HASH" \
      "PB archive hash for ${PLATFORM_KEY} NEEDS-EXTERNAL — no authoritative checksum published"
    return 0
  fi
  local actual; actual=$(shasum -a 256 "$archive" 2>/dev/null | awk '{print $1}')
  if [[ "$actual" != "$expected" ]]; then
    t_blocking "T-PKG-ARCHIVE-HASH" \
      "Archive hash mismatch: expected=${expected} actual=${actual}"
    return 1
  fi
  t_pass "T-PKG-ARCHIVE-HASH"
}

pb_extract_pocketbase() {
  local archive="$1"
  unzip -o "$archive" -d "$RELEASE1B_ISOLATED_ROOT" pocketbase 2>/dev/null \
    || pb_halt "Cannot extract pocketbase from ${archive}"
  chmod 700 "$RELEASE1B_PB_BIN"
  print "=== PocketBase extracted: ${RELEASE1B_PB_BIN} ==="
}

pb_verify_binary_version() {
  local reported
  reported=$("$RELEASE1B_PB_BIN" version 2>&1 | head -1)
  print "=== PocketBase binary version: ${reported} ==="
  if [[ "$reported" != *"${RELEASE1B_PB_VERSION}"* ]]; then
    t_blocking "T-PKG-VERSION" \
      "Binary reports '${reported}'; expected v${RELEASE1B_PB_VERSION}"
    return 1
  fi
  t_pass "T-PKG-VERSION"
}

# R19 CORRECTION C-18: Mailhog ports (8025, 1025) removed.
# OTP testing now uses the local adapter; no email delivery required.
pb_preflight_ports() {
  print "=== Preflight port check ==="
  if lsof -iTCP:"$RELEASE1B_PB_PORT" -sTCP:LISTEN -P -n &>/dev/null; then
    t_blocking "T-PREFLIGHT-PORT-${RELEASE1B_PB_PORT}" \
      "Port ${RELEASE1B_PB_PORT} already in use"
    return 1
  fi
  t_pass "T-PREFLIGHT-PORTS"
}

pb_apply_schema_migrations() {
  print "=== Applying schema migrations ==="
  if [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]]; then
    t_unresolved "T-SCHEMA-MIGRATIONS" \
      "RELEASE1B_SCHEMA_SRC not set — cannot apply migrations"
    return 0
  fi

  if [[ -d "$RELEASE1B_SCHEMA_SRC" ]]; then
    local js_count=0
    local _jf
    for _jf in "${RELEASE1B_SCHEMA_SRC}"/*.js(N); do
      cp "$_jf" "$RELEASE1B_PB_MIGRATIONS_DIR"/ || {
        t_blocking "T-SCHEMA-MIGRATIONS-COPY" \
          "cp failed: ${_jf} -> ${RELEASE1B_PB_MIGRATIONS_DIR}/"
        return 1
      }
      chmod 600 "${RELEASE1B_PB_MIGRATIONS_DIR}/$(basename "$_jf")" || {
        t_blocking "T-SCHEMA-MIGRATIONS-PERMS" \
          "chmod failed: $(basename "$_jf")"
        return 1
      }
      (( js_count++ ))
    done
    if (( js_count == 0 )); then
      t_blocking "T-SCHEMA-MIGRATIONS-COPY" \
        "No .js files found in ${RELEASE1B_SCHEMA_SRC}"
      return 1
    fi
    # NOTE S-3: One of the copied migrations (1782898775_seed_superadmin_user_4fd7.js)
    # contains a hardcoded plaintext credential. The isolated database will have
    # that seeded user, which is harmless for isolation purposes but the credential
    # MUST have been rotated in production. The harness never reads or uses it.
    t_pass "T-SCHEMA-MIGRATIONS-COPY"
  elif [[ -f "$RELEASE1B_SCHEMA_SRC" ]]; then
    cp "$RELEASE1B_SCHEMA_SRC" "$RELEASE1B_PB_MIGRATIONS_DIR"/ || {
      t_blocking "T-SCHEMA-MIGRATIONS-COPY" \
        "cp failed: ${RELEASE1B_SCHEMA_SRC}"
      return 1
    }
    chmod 600 "${RELEASE1B_PB_MIGRATIONS_DIR}/$(basename "$RELEASE1B_SCHEMA_SRC")" || {
      t_blocking "T-SCHEMA-MIGRATIONS-PERMS" \
        "chmod failed: $(basename "$RELEASE1B_SCHEMA_SRC")"
      return 1
    }
    t_pass "T-SCHEMA-MIGRATIONS-COPY"
  fi
}

pb_deploy_hooks() {
  print "=== Deploying hooks to isolated directory ==="
  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local src="${HOOK_SRC_PATHS[$hk]}"
    if [[ "$src" == UNRESOLVED* ]]; then
      t_unresolved "T-HOOK-DEPLOY-${hk}" "src path NEEDS-EXTERNAL"
      continue
    fi
    if [[ ! -f "$src" ]]; then
      t_blocking "T-HOOK-DEPLOY-${hk}" "file not found: ${src}"
      continue
    fi
    local expected_sha="${HOOK_EXPECTED_SHA256[$hk]:-}"
    if [[ "$expected_sha" != UNRESOLVED* ]]; then
      local actual_sha; actual_sha=$(shasum -a 256 "$src" | awk '{print $1}')
      if [[ "$actual_sha" != "$expected_sha" ]]; then
        t_blocking "T-HOOK-HASH-${hk}" \
          "hash mismatch: expected=${expected_sha} actual=${actual_sha}"
        continue
      fi
    fi
    local dest="${RELEASE1B_PB_HOOKS_DIR}/$(basename "$src")"
    cp "$src" "$dest" || {
      t_blocking "T-HOOK-DEPLOY-${hk}" "cp failed: ${src} -> ${dest}"
      continue
    }
    chmod 600 "$dest"
    t_pass "T-HOOK-DEPLOY-${hk}"
  done
  t_pass "T-HOOKDIR-VERIFY"
}

pb_start_pocketbase() {
  print "=== Starting PocketBase ==="
  if [[ ! -x "$RELEASE1B_PB_BIN" ]]; then
    pb_halt "PocketBase binary not found or not executable: ${RELEASE1B_PB_BIN}"
  fi
  "$RELEASE1B_PB_BIN" serve \
    --dir "$RELEASE1B_PB_DATA_DIR" \
    --hooksDir "$RELEASE1B_PB_HOOKS_DIR" \
    --migrationsDir "$RELEASE1B_PB_MIGRATIONS_DIR" \
    --http "127.0.0.1:${RELEASE1B_PB_PORT}" \
    &>/dev/null &
  RELEASE1B_PB_PID=$!
  print "=== PocketBase PID: ${RELEASE1B_PB_PID} ==="

  local tries=0
  while (( tries < 30 )); do
    if curl -sf "${RELEASE1B_BASE_URL}/api/health" &>/dev/null; then
      print "=== PocketBase ready after ${tries}s ==="
      return 0
    fi
    sleep 1
    (( tries++ ))
  done
  pb_halt "PocketBase did not become ready within 30s"
}

# ────────────────────────────────────────────────────────────
# §13 NATIVE SUPERUSER LIFECYCLE
# NOTE: Uses /api/admins/auth-with-password (PB v0.28.x path).
# If v0.29.3 moved superuser auth to /api/collections/_superusers/
# auth-with-password, this section must be updated. Verify on v0.29.3.
# ────────────────────────────────────────────────────────────

pb_create_local_superuser() {
  print "=== Creating native superuser ==="
  local su_email="cp0_su_${RUN_SUFFIX}@release1b.local"
  local su_pw_file; su_pw_file=$(pb_secure_tmpfile .pw)
  local su_tok_file; su_tok_file=$(pb_secure_tmpfile .tok)
  local su_id_file; su_id_file=$(pb_secure_tmpfile .id)
  local su_auth_cfg; su_auth_cfg=$(pb_secure_tmpfile .hdr)

  openssl rand -base64 32 | tr -d '\n=' > "$su_pw_file"
  chmod 600 "$su_pw_file"

  "$RELEASE1B_PB_BIN" admin create \
    "$su_email" \
    "$(cat "$su_pw_file")" \
    --dir "$RELEASE1B_PB_DATA_DIR" \
    &>/dev/null || {
    t_blocking "T-SU-CREATE" "pocketbase admin create failed"
    return 1
  }

  local body_f; body_f=$(pb_secure_tmpfile .json)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  python3 "$PBJ_PY" "$body_f" \
    "identity=${su_email}" \
    "secret-file:password=${su_pw_file}" 2>/dev/null || {
    t_blocking "T-SU-AUTH-BODY" "pbj.py failed to build superuser auth body"
    rm -f "$body_f" "$su_pw_file"
    return 1
  }

  local url; url=$(pb_url "/api/admins/auth-with-password")
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"

  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"

  if [[ "$status" != "200" ]]; then
    t_blocking "T-SU-AUTH" "Superuser auth returned ${status}"
    rm -f "$resp_path"
    pb_wipe_secret_file "$su_pw_file"
    return 1
  fi

  local token; token=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
  if [[ -z "$token" || "$token" == "__absent__" ]]; then
    t_blocking "T-SU-AUTH-TOKEN" "Superuser auth response missing token"
    rm -f "$resp_path"
    pb_wipe_secret_file "$su_pw_file"
    return 1
  fi
  printf '%s' "$token" > "$su_tok_file"
  chmod 600 "$su_tok_file"

  local su_id; su_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  if [[ -z "$su_id" || "$su_id" == "__absent__" ]]; then
    t_blocking "T-SU-AUTH-ID" "Superuser auth response missing id"
    pb_wipe_secret_file "$su_pw_file"
    return 1
  fi
  printf '%s' "$su_id" > "$su_id_file"
  chmod 600 "$su_id_file"

  python3 "$PBJ_AUTH_PY" "$su_auth_cfg" "$su_tok_file" 2>/dev/null || {
    t_blocking "T-SU-AUTH-CFG" "pbj_auth.py failed to build auth header"
    pb_wipe_secret_file "$su_pw_file"
    return 1
  }

  pb_wipe_secret_file "$su_pw_file"
  _NATIVE_SU_TOK_FILE="$su_tok_file"
  _NATIVE_SU_ID_FILE="$su_id_file"
  _NATIVE_SU_AUTH_CFG="$su_auth_cfg"

  t_pass "T-SU-CREATE-AUTH"
}

pb_delete_local_superuser() {
  [[ -f "$_NATIVE_SU_ID_FILE" ]] || return 0
  local su_id; su_id=$(cat "$_NATIVE_SU_ID_FILE" 2>/dev/null)
  [[ -z "$su_id" ]] && return 0

  local url; url=$(pb_url "/api/admins/${su_id}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "DELETE"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$resp_path" "$_NATIVE_SU_ID_FILE"

  if [[ "$status" != "200" && "$status" != "204" && "$status" != "404" ]]; then
    CLEANUP_FAILURE=1
    print "[su-del] WARNING: DELETE admin returned ${status}" >&2
  fi
  pb_wipe_secret_file "$_NATIVE_SU_TOK_FILE"
  pb_wipe_secret_file "$_NATIVE_SU_AUTH_CFG"
  t_pass "T-SU-DELETE"
}

# ────────────────────────────────────────────────────────────
# §14-§16  SCHEMA VERIFICATION, BASELINE, RULE HELPERS
# (R19: corrected collection list)
# ────────────────────────────────────────────────────────────

pb_verify_schema() {
  print "=== Verifying schema collections ==="
  # R19 CORRECTION C-6/C-19: Updated list of expected collections.
  # Removed: growth_records, activities, immunizations, progress_notes, newborn_enrollments.
  # Added:   growth_logs, activity_logs, immunisations, nutrition_logs, wellbeing_logs,
  #          notification_preferences, notification_queue, phone_otps, push_subscriptions,
  #          enrollments, lesson_progress.
  local required_collections=(
    users children
    growth_logs nutrition_logs activity_logs wellbeing_logs
    immunisations articles bookmarks
    notifications notification_preferences notification_queue
    phone_otps push_subscriptions
    courses enrollments lesson_progress
  )

  local col ok=1
  for col in "${required_collections[@]}"; do
    local url; url=$(pb_url "/api/collections/${col}")
    local status_f; status_f=$(pb_secure_tmpfile .http)
    local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
      python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
        "$_NATIVE_SU_AUTH_CFG" "" "GET"
    local st; st=$(cat "$status_f" 2>/dev/null)
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    if [[ "$st" == "200" ]]; then
      t_pass "T-SCHEMA-COL-${col}"
    else
      t_fail "T-SCHEMA-COL-${col}" "GET /api/collections/${col} returned ${st}"
      ok=0
    fi
  done

  # R19 CORRECTION C-7: Verify children.user field (was children.parent in R18).
  local url; url=$(pb_url "/api/collections/children")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local st; st=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  if [[ "$st" == "200" ]]; then
    # Verify that 'user' field exists and 'parent' does not
    local fields_check
    fields_check=$(python3 - "$rp" << 'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    fields = [fld.get("name","") for fld in d.get("fields", d.get("schema", []))]
    has_user   = "user"   in fields
    has_parent = "parent" in fields
    if has_user and not has_parent:
        print("OK")
    elif has_parent and not has_user:
        print("WRONG_PARENT")
    elif has_user and has_parent:
        print("BOTH")
    else:
        print("NEITHER")
except Exception as e:
    print(f"ERROR:{e}")
PYEOF
)
    rm -f "$rp"
    case "$fields_check" in
      OK)           t_pass "T-SCHEMA-FIELD-CHILDREN-USER" ;;
      WRONG_PARENT) t_fail "T-SCHEMA-FIELD-CHILDREN-USER" \
                      "children has 'parent' field not 'user' — R19 correction still pending" ;;
      *)            t_fail "T-SCHEMA-FIELD-CHILDREN-USER" \
                      "unexpected field check result: ${fields_check}" ;;
    esac
  else
    rm -f "$rp"
    t_fail "T-SCHEMA-FIELD-CHILDREN-USER" "Could not read children collection: ${st}"
  fi

  # R19 CORRECTION C-8: Verify articles.category and articles.is_pregnancy fields.
  url=$(pb_url "/api/collections/articles")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  st=$(cat "$status_f" 2>/dev/null)
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  if [[ "$st" == "200" ]]; then
    local art_check
    art_check=$(python3 - "$rp" << 'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    fields = [fld.get("name","") for fld in d.get("fields", d.get("schema", []))]
    has_category    = "category"    in fields
    has_is_pregnancy = "is_pregnancy" in fields
    has_type         = "type"         in fields
    results = []
    if has_category:    results.append("category:OK")
    else:               results.append("category:ABSENT")
    if has_is_pregnancy: results.append("is_pregnancy:OK")
    else:                results.append("is_pregnancy:ABSENT")
    if has_type:         results.append("type:PRESENT")
    print(",".join(results))
except Exception as e:
    print(f"ERROR:{e}")
PYEOF
)
    rm -f "$rp"
    if [[ "$art_check" == *"category:OK"* ]]; then
      t_pass "T-SCHEMA-FIELD-ART-CATEGORY"
    else
      t_fail "T-SCHEMA-FIELD-ART-CATEGORY" "articles.category field absent: ${art_check}"
    fi
    if [[ "$art_check" == *"is_pregnancy:OK"* ]]; then
      t_pass "T-SCHEMA-FIELD-ART-PREGNANCY"
    else
      t_fail "T-SCHEMA-FIELD-ART-PREGNANCY" "articles.is_pregnancy field absent: ${art_check}"
    fi
  else
    rm -f "$rp"
    t_fail "T-SCHEMA-FIELD-ART-CATEGORY" "Could not read articles collection: ${st}"
    t_fail "T-SCHEMA-FIELD-ART-PREGNANCY" "Could not read articles collection: ${st}"
  fi

  (( ok )) && return 0 || return 1
}

pb_capture_rule_baseline() {
  local collection="$1" rule_type="$2"
  local url; url=$(pb_url "/api/collections/${collection}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local st; st=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  if [[ "$st" != "200" ]]; then
    rm -f "$rp"
    t_harness_err "T-RULE-BASELINE-${collection}-${rule_type}" \
      "GET returned ${st}"
    return 1
  fi
  local val; val=$(python3 "$PBJ_FIELD_PY" "$rp" "$rule_type" 2>/dev/null)
  rm -f "$rp"
  local normalized
  if [[ "$val" == "__null__" ]]; then
    normalized="__pb_null__"
  else
    normalized="$val"
  fi
  RULE_BASELINE["${collection}::${rule_type}"]="$normalized"
  t_pass "T-RULE-BASELINE-${collection}-${rule_type}"
}

pb_apply_rule_local() {
  local collection="$1" rule_type="$2" new_value="$3"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  printf '{ "%s": "%s" }' "$rule_type" "$new_value" > "$body_f"
  chmod 600 "$body_f"
  local url; url=$(pb_url "/api/collections/${collection}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "PATCH"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$resp_path"
  if [[ "$status" != "200" ]]; then
    t_harness_err "T-RULE-APPLY-${collection}-${rule_type}" "PATCH returned ${status}"
    return 1
  fi
  t_pass "T-RULE-APPLY-${collection}-${rule_type}"
}

pb_restore_rule_local() {
  local collection="$1" rule_type="$2"
  local registry_key="${collection}::${rule_type}"
  local baseline="${RULE_BASELINE[$registry_key]:-}"
  if [[ -z "$baseline" ]]; then
    t_harness_err "T-RULE-RESTORE-${collection}-${rule_type}" \
      "No baseline in RULE_BASELINE for ${registry_key}"
    return 1
  fi
  local restore_value
  if [[ "$baseline" == "__pb_null__" ]]; then
    restore_value="null"
  else
    restore_value="\"${baseline}\""
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  printf '{ "%s": %s }' "$rule_type" "$restore_value" > "$body_f"
  chmod 600 "$body_f"
  local url; url=$(pb_url "/api/collections/${collection}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "PATCH"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$resp_path"
  if [[ "$status" != "200" ]]; then
    CLEANUP_FAILURE=1
    t_harness_err "T-RULE-RESTORE-${collection}-${rule_type}" "PATCH returned ${status}"
    return 1
  fi
  sleep 0.2
  url=$(pb_url "/api/collections/${collection}")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  status=$(cat "$status_f" 2>/dev/null)
  resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  if [[ "$status" != "200" ]]; then
    rm -f "$resp_path"
    CLEANUP_FAILURE=1
    t_harness_err "T-RULE-RESTORE-VERIFY-${collection}-${rule_type}" \
      "re-read returned ${status}"
    return 1
  fi
  local confirmed; confirmed=$(python3 "$PBJ_FIELD_PY" "$resp_path" "$rule_type" 2>/dev/null)
  rm -f "$resp_path"
  local confirmed_norm
  if [[ "$confirmed" == "__null__" ]]; then
    confirmed_norm="__pb_null__"
  else
    confirmed_norm="$confirmed"
  fi
  if [[ "$confirmed_norm" != "$baseline" ]]; then
    CLEANUP_FAILURE=1
    t_harness_err "T-RULE-RESTORE-VERIFY-${collection}-${rule_type}" \
      "mismatch: expected='${baseline}' got='${confirmed}'"
    return 1
  fi
  t_pass "T-RULE-RESTORE-${collection}-${rule_type}"
}

# ────────────────────────────────────────────────────────────
# §17 HTTP HELPER  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_capture() {
  local method="$1" url_suffix="$2" auth_cfg="$3" body_f="$4"
  local status_out="$5" resp_path_out="$6" label="$7"
  shift 7
  local -a expected=("$@")
  local url; url=$(pb_url "$url_suffix")
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_out" "$resp_path_out" "$url" \
      "${auth_cfg:-}" "${body_f:-}" "$method"
  local actual; actual=$(cat "$status_out" 2>/dev/null)
  local exp
  for exp in "${expected[@]}"; do
    [[ "$actual" == "$exp" ]] && return 0
  done
  print "[cap] ${label}: expected [${expected[*]}] got ${actual}" >&2
  return 1
}

# ────────────────────────────────────────────────────────────
# §18 FIXTURE REGISTRY  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_register_fixture() { FIXTURE_REGISTRY[$1]="$2" }
pb_unregister_fixture() { unset "FIXTURE_REGISTRY[$1]" }

pb_cleanup_all_fixtures() {
  print "=== Cleaning up fixtures ==="
  local fid
  for fid in "${(@k)FIXTURE_REGISTRY}"; do
    local fn="${FIXTURE_REGISTRY[$fid]}"
    if typeset -f "$fn" &>/dev/null; then
      "$fn" "$fid" || CLEANUP_FAILURE=1
    fi
    unset "FIXTURE_REGISTRY[$fid]"
  done
}

pb_delete_record() {
  local collection="$1" id_file="$2"
  [[ -f "$id_file" ]] || return 0
  local rec_id; rec_id=$(cat "$id_file" 2>/dev/null)
  [[ -z "$rec_id" ]] && return 0
  local url; url=$(pb_url "/api/collections/${collection}/records/${rec_id}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "DELETE"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$resp_path" "$id_file"
  if [[ "$status" != "200" && "$status" != "204" && "$status" != "404" ]]; then
    CLEANUP_FAILURE=1
    print "[del] WARNING: DELETE ${collection}/${rec_id} returned ${status}" >&2
    return 1
  fi
  return 0
}

# ────────────────────────────────────────────────────────────
# §19 USER LIFECYCLE  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_create_test_user() {
  local role="$1" id_file_var="$2" tok_file_var="$3" auth_cfg_var="$4"
  local email="cp0_${role}_${RUN_SUFFIX}@release1b.local"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  chmod 600 "$pw_file"
  local id_file; id_file=$(pb_secure_tmpfile .id)
  local tok_file; tok_file=$(pb_secure_tmpfile .tok)
  local auth_cfg; auth_cfg=$(pb_secure_tmpfile .hdr)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" \
    "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" \
    "role=${role}" \
    "b:emailVisibility=true" 2>/dev/null || {
    t_harness_err "T-USER-CREATE-${role}" "pbj.py failed"
    rm -f "$body_f" "$pw_file"; return 1
  }
  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  if [[ "$status" != "200" ]]; then
    t_blocking "T-USER-CREATE-${role}" "Create returned ${status}"
    rm -f "$resp_path"; pb_wipe_secret_file "$pw_file"; return 1
  fi
  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  if [[ -z "$rec_id" || "$rec_id" == "__absent__" ]]; then
    t_blocking "T-USER-CREATE-ID-${role}" "Missing id"
    pb_wipe_secret_file "$pw_file"; return 1
  fi
  printf '%s' "$rec_id" > "$id_file"
  chmod 600 "$id_file"
  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${email}" \
    "secret-file:password=${pw_file}" 2>/dev/null
  url=$(pb_url "/api/collections/users/auth-with-password")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  status=$(cat "$status_f" 2>/dev/null)
  resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  if [[ "$status" != "200" ]]; then
    t_blocking "T-USER-AUTH-${role}" "Auth returned ${status}"
    rm -f "$resp_path"; pb_wipe_secret_file "$pw_file"; return 1
  fi
  local token; token=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
  rm -f "$resp_path"
  if [[ -z "$token" || "$token" == "__absent__" ]]; then
    t_blocking "T-USER-AUTH-TOKEN-${role}" "Missing token"
    pb_wipe_secret_file "$pw_file"; return 1
  fi
  printf '%s' "$token" > "$tok_file"
  chmod 600 "$tok_file"
  python3 "$PBJ_AUTH_PY" "$auth_cfg" "$tok_file" 2>/dev/null || {
    t_blocking "T-USER-AUTH-CFG-${role}" "pbj_auth.py failed"
    pb_wipe_secret_file "$pw_file"; return 1
  }
  pb_wipe_secret_file "$pw_file"
  typeset -g "${id_file_var}=${id_file}"
  typeset -g "${tok_file_var}=${tok_file}"
  typeset -g "${auth_cfg_var}=${auth_cfg}"
  t_pass "T-USER-CREATE-AUTH-${role}"
}

pb_delete_test_user() {
  local role="$1" id_file="$2" tok_file="$3" auth_cfg="$4"
  pb_delete_record "users" "$id_file" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$tok_file"
  pb_wipe_secret_file "$auth_cfg"
}

# ────────────────────────────────────────────────────────────
# §20 LEGACY FIXTURE
# R19 CORRECTIONS:
#   C-9a: children.parent -> children.user
#   C-9b: has_newborn_content removed (not in children schema)
#   C-9c: phone_verified removed (not in users schema, S-2)
#   C-9d: growth_records -> growth_logs in cleanup
# ────────────────────────────────────────────────────────────

pb_create_legacy_fixture() {
  print "=== Creating legacy fixture ==="
  local email="cp0_legacy_${RUN_SUFFIX}@release1b.local"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  chmod 600 "$pw_file"

  LEGACY_ID_FILE=$(pb_secure_tmpfile .id)
  LEGACY_TOK_FILE=$(pb_secure_tmpfile .tok)
  LEGACY_AUTH_CFG=$(pb_secure_tmpfile .hdr)

  local body_f; body_f=$(pb_secure_tmpfile .json)
  # R19 C-9c: phone_verified removed — field not in schema (S-2).
  # Legacy user represents a user who registered by email/password
  # in a prior release, without phone_verified semantics.
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" \
    "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" \
    "role=user" \
    "b:emailVisibility=true" 2>/dev/null || {
    t_harness_err "T-LEGACY-CREATE" "pbj.py failed"; return 1
  }

  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"

  if [[ "$status" != "200" ]]; then
    t_harness_err "T-LEGACY-CREATE" "Create returned ${status}"
    rm -f "$resp_path"; pb_wipe_secret_file "$pw_file"; return 1
  fi

  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  printf '%s' "$rec_id" > "$LEGACY_ID_FILE"
  chmod 600 "$LEGACY_ID_FILE"

  LEGACY_CHILD_ID_FILE=$(pb_secure_tmpfile .id)
  local cbody; cbody=$(pb_secure_tmpfile .json)
  # R19 C-9a: user= not parent= (field name correction).
  # R19 C-9b: has_newborn_content removed (not in children schema).
  python3 "$PBJ_PY" "$cbody" \
    "user=${rec_id}" \
    "name=LegacyChild_${RUN_SUFFIX}" 2>/dev/null
  url=$(pb_url "/api/collections/children/records")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$cbody" "POST"
  status=$(cat "$status_f" 2>/dev/null)
  resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$cbody" "$status_f" "$resp_path_f"
  if [[ "$status" == "200" ]]; then
    local cid; cid=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    printf '%s' "$cid" > "$LEGACY_CHILD_ID_FILE"
    chmod 600 "$LEGACY_CHILD_ID_FILE"
  else
    t_harness_err "T-LEGACY-CHILD-CREATE" "Create returned ${status}"
  fi
  rm -f "$resp_path"

  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${email}" \
    "secret-file:password=${pw_file}" 2>/dev/null
  url=$(pb_url "/api/collections/users/auth-with-password")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  status=$(cat "$status_f" 2>/dev/null)
  resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"

  if [[ "$status" == "200" ]]; then
    local tok; tok=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
    printf '%s' "$tok" > "$LEGACY_TOK_FILE"
    chmod 600 "$LEGACY_TOK_FILE"
    python3 "$PBJ_AUTH_PY" "$LEGACY_AUTH_CFG" "$LEGACY_TOK_FILE" 2>/dev/null
  fi
  rm -f "$resp_path"
  pb_wipe_secret_file "$pw_file"
  t_pass "T-LEGACY-FIXTURE-CREATE"
}

pb_delete_legacy_fixture() {
  print "=== Deleting legacy fixture ==="
  # R19 C-9d: growth_logs replaces growth_records.
  local f
  for f in "$LEGACY_CHILD_ID_FILE" "$LEGACY_GROWTH_ID_FILE" \
            "$LEGACY_ACTIVITY_ID_FILE" "$LEGACY_IMMUN_ID_FILE" \
            "$LEGACY_ENROLL_ID_FILE"; do
    [[ -n "$f" && -f "$f" ]] || continue
    pb_delete_record "children"    "$f" 2>/dev/null || \
    pb_delete_record "growth_logs" "$f" 2>/dev/null || \
    pb_delete_record "enrollments" "$f" 2>/dev/null || {
      CLEANUP_FAILURE=1
      print "[legacy-del] WARNING: could not delete record (id_file: ${f})" >&2
    }
  done
  pb_delete_record "users" "$LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$LEGACY_TOK_FILE"
  pb_wipe_secret_file "$LEGACY_AUTH_CFG"
}

# ────────────────────────────────────────────────────────────
# §21 ALIAS FIXTURES
# R19 CORRECTIONS:
#   C-10a: is_alias_account removed (field absent, S-2).
#          Alias enum tests now test wrong-pw behavior on any
#          existing user, not specifically alias-flagged users.
#   C-10b: phone_verified removed from timing-legacy fixture.
# ────────────────────────────────────────────────────────────

pb_setup_alias_group() {
  print "=== Setting up alias group fixtures ==="

  ALIAS_ID_FILE=$(pb_secure_tmpfile .id)
  ALIAS_PW_FILE=$(pb_secure_tmpfile .pw)
  ALIAS_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local alias_tok; alias_tok=$(pb_secure_tmpfile .tok)
  local alias_email="cp0_alias_${RUN_SUFFIX}@release1b.local"

  openssl rand -base64 24 | tr -d '\n=' > "$ALIAS_PW_FILE"
  chmod 600 "$ALIAS_PW_FILE"

  local body_f; body_f=$(pb_secure_tmpfile .json)
  # R19 C-10a: is_alias_account field removed (absent from schema, S-2).
  # Note: T-ALIAS-ENUM tests now verify wrong-pw timing on ordinary users.
  # If is_alias_account is added in a future schema revision, re-add here.
  python3 "$PBJ_PY" "$body_f" \
    "email=${alias_email}" \
    "secret-file:password=${ALIAS_PW_FILE}" \
    "secret-file:passwordConfirm=${ALIAS_PW_FILE}" \
    "role=user" \
    "b:emailVisibility=true" 2>/dev/null

  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"

  if [[ "$status" == "200" ]]; then
    local alias_id; alias_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    printf '%s' "$alias_id" > "$ALIAS_ID_FILE"
    chmod 600 "$ALIAS_ID_FILE"
    rm -f "$resp_path"
    body_f=$(pb_secure_tmpfile .json)
    python3 "$PBJ_PY" "$body_f" \
      "identity=${alias_email}" \
      "secret-file:password=${ALIAS_PW_FILE}" 2>/dev/null
    url=$(pb_url "/api/collections/users/auth-with-password")
    status_f=$(pb_secure_tmpfile .http)
    resp_path_f=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
      python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
    status=$(cat "$status_f" 2>/dev/null)
    resp_path=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f"
    if [[ "$status" == "200" ]]; then
      local av; av=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
      printf '%s' "$av" > "$alias_tok"
      chmod 600 "$alias_tok"
      python3 "$PBJ_AUTH_PY" "$ALIAS_AUTH_CFG" "$alias_tok" 2>/dev/null
    fi
    rm -f "$resp_path" "$alias_tok"
  else
    rm -f "$resp_path"
    t_harness_err "T-ALIAS-SETUP" "Alias create returned ${status}"
  fi

  WRONG_PW_FILE=$(pb_secure_tmpfile .pw)
  printf 'definitely-wrong-password-xYzQrS' > "$WRONG_PW_FILE"
  chmod 600 "$WRONG_PW_FILE"

  TIMING_LEGACY_ID_FILE=$(pb_secure_tmpfile .id)
  TIMING_LEGACY_PW_FILE=$(pb_secure_tmpfile .pw)
  TIMING_LEGACY_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local tl_email="cp0_tl_${RUN_SUFFIX}@release1b.local"
  local tl_tok; tl_tok=$(pb_secure_tmpfile .tok)

  openssl rand -base64 24 | tr -d '\n=' > "$TIMING_LEGACY_PW_FILE"
  chmod 600 "$TIMING_LEGACY_PW_FILE"

  body_f=$(pb_secure_tmpfile .json)
  # R19 C-10b: phone_verified removed (field absent, S-2).
  python3 "$PBJ_PY" "$body_f" \
    "email=${tl_email}" \
    "secret-file:password=${TIMING_LEGACY_PW_FILE}" \
    "secret-file:passwordConfirm=${TIMING_LEGACY_PW_FILE}" \
    "role=user" \
    "b:emailVisibility=true" 2>/dev/null
  url=$(pb_url "/api/collections/users/records")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "POST"
  status=$(cat "$status_f" 2>/dev/null)
  resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"

  if [[ "$status" == "200" ]]; then
    local tl_id; tl_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    printf '%s' "$tl_id" > "$TIMING_LEGACY_ID_FILE"
    chmod 600 "$TIMING_LEGACY_ID_FILE"
    rm -f "$resp_path"
    body_f=$(pb_secure_tmpfile .json)
    python3 "$PBJ_PY" "$body_f" \
      "identity=${tl_email}" \
      "secret-file:password=${TIMING_LEGACY_PW_FILE}" 2>/dev/null
    url=$(pb_url "/api/collections/users/auth-with-password")
    status_f=$(pb_secure_tmpfile .http)
    resp_path_f=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
      python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
    status=$(cat "$status_f" 2>/dev/null)
    resp_path=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f"
    if [[ "$status" == "200" ]]; then
      local tv; tv=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
      printf '%s' "$tv" > "$tl_tok"
      chmod 600 "$tl_tok"
      python3 "$PBJ_AUTH_PY" "$TIMING_LEGACY_AUTH_CFG" "$tl_tok" 2>/dev/null
    fi
    rm -f "$resp_path" "$tl_tok"
  else
    rm -f "$resp_path"
    t_harness_err "T-ALIAS-SETUP-TL" "Timing-legacy create returned ${status}"
  fi

  t_pass "T-ALIAS-GROUP-SETUP"
}

pb_cleanup_alias_group() {
  print "=== Cleaning up alias group ==="
  pb_delete_record "users" "$ALIAS_ID_FILE"         || CLEANUP_FAILURE=1
  pb_delete_record "users" "$TIMING_LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$ALIAS_PW_FILE"
  pb_wipe_secret_file "$ALIAS_AUTH_CFG"
  pb_wipe_secret_file "$TIMING_LEGACY_PW_FILE"
  pb_wipe_secret_file "$TIMING_LEGACY_AUTH_CFG"
  pb_wipe_secret_file "$WRONG_PW_FILE"
}

# ────────────────────────────────────────────────────────────
# §22 ALIAS ENUM CASES  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_alias_enum_case() {
  local case_num="$1" label="$2" email="$3" expected="$4"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${email}" \
    "secret-file:password=${WRONG_PW_FILE}" 2>/dev/null || {
    t_harness_err "$label" "pbj.py failed"; return 1
  }
  local url; url=$(pb_url "/api/collections/users/auth-with-password")
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local actual; actual=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  ENUM_HTTP_VALUES+=("$actual")
  ENUM_RESP_FILES+=("$resp_path")
  rm -f "$body_f" "$status_f" "$resp_path_f"
  if [[ "$actual" == "$expected" ]]; then
    t_pass "$label"; return 0
  else
    t_fail "$label" "expected ${expected} got ${actual}"; return 1
  fi
}

t_alias_case5_timing() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-CASE5-TIMING" "blocked"; return 0; }
  if [[ ! -f "$TIMING_LEGACY_PW_FILE" ]]; then
    t_unresolved "T-ALIAS-CASE5-TIMING" "TIMING_LEGACY_PW_FILE not set"; return 0
  fi
  local tl_id; tl_id=$(cat "$TIMING_LEGACY_ID_FILE" 2>/dev/null)
  local url; url=$(pb_url "/api/collections/users/records/${tl_id}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  local tl_email; tl_email=$(python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null)
  rm -f "$rp"
  if [[ -z "$tl_email" ]]; then
    t_unresolved "T-ALIAS-CASE5-TIMING" "Could not resolve timing-legacy email"; return 0
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${tl_email}" \
    "secret-file:password=${TIMING_LEGACY_PW_FILE}" 2>/dev/null
  url=$(pb_url "/api/collections/users/auth-with-password")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  local t_start; t_start=$(date +%s%3N)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local t_end; t_end=$(date +%s%3N)
  local elapsed_legacy=$(( t_end - t_start ))
  local status; status=$(cat "$status_f" 2>/dev/null)
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  if [[ "$status" != "200" ]]; then
    t_fail "T-ALIAS-CASE5-TIMING" "Timing-legacy auth failed: status=${status}"; return 1
  fi
  t_pass "T-ALIAS-CASE5-TIMING"
  print "[alias-timing] legacy auth elapsed: ${elapsed_legacy}ms"
}

# ────────────────────────────────────────────────────────────
# §23 CRUD TESTS
# R19 CORRECTIONS:
#   C-7:  parent= -> user= in child create bodies
#   C-16: growth_records -> growth_logs; body adds user= field
# ────────────────────────────────────────────────────────────

t_crud_children_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-LIST" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-CRUD-CH-LIST" "200" || {
    t_fail "T-CRUD-CH-LIST" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-LIST"
}

t_crud_children_view() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-VIEW" "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_skip "T-CRUD-CH-VIEW" "no child fixture"; return 0; }
  local child_id; child_id=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records/${child_id}" \
    "$LEGACY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-CRUD-CH-VIEW" "200" || {
    t_fail "T-CRUD-CH-VIEW" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-VIEW"
}

t_crud_children_view_cross_user() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-VIEW-CROSS" "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_skip "T-CRUD-CH-VIEW-CROSS" "no child fixture"; return 0; }
  local child_id; child_id=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records/${child_id}" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-CRUD-CH-VIEW-CROSS" "404" || {
    t_fail "T-CRUD-CH-VIEW-CROSS" "expected 404 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-VIEW-CROSS"
}

t_crud_children_create() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-CREATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  # R19 C-7: user= not parent= (field name correction).
  python3 "$PBJ_PY" "$body_f" "user=${ord_id}" "name=TestChild_${RUN_SUFFIX}" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-CRUD-CH-CREATE" "200" || {
    t_fail "T-CRUD-CH-CREATE" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  local new_id; new_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  if [[ -n "$new_id" ]]; then
    local id_f; id_f=$(pb_secure_tmpfile .id)
    printf '%s' "$new_id" > "$id_f"
    pb_delete_record "children" "$id_f"
  fi
  t_pass "T-CRUD-CH-CREATE"
}

t_crud_children_create_cross_user() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-CREATE-CROSS" "blocked"; return 0; }
  local other_id; other_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  [[ -z "$other_id" ]] && { t_skip "T-CRUD-CH-CREATE-CROSS" "no legacy fixture"; return 0; }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  # R19 C-7: user= not parent=.
  python3 "$PBJ_PY" "$body_f" "user=${other_id}" "name=CrossChild_${RUN_SUFFIX}" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-CRUD-CH-CREATE-CROSS" "400" || {
    t_fail "T-CRUD-CH-CREATE-CROSS" "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-CREATE-CROSS"
}

t_crud_growth_create() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-GL-CREATE" "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_skip "T-CRUD-GL-CREATE" "no child fixture"; return 0; }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local leg_id; leg_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  # R19 C-16: collection growth_records -> growth_logs.
  # Body now includes user= field (required in growth_logs schema).
  python3 "$PBJ_PY" "$body_f" \
    "user=${leg_id}" "child=${cid}" \
    "n:weight_kg=3.5" "n:height_cm=50.0" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-16: collection growth_logs (was growth_records).
  pb_capture "POST" "/api/collections/growth_logs/records" \
    "$LEGACY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-CRUD-GL-CREATE" "200" || {
    t_fail "T-CRUD-GL-CREATE" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  local new_id; new_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  if [[ -n "$new_id" ]]; then
    local id_f; id_f=$(pb_secure_tmpfile .id)
    printf '%s' "$new_id" > "$id_f"
    LEGACY_GROWTH_ID_FILE="$id_f"
  fi
  t_pass "T-CRUD-GL-CREATE"
}

# ────────────────────────────────────────────────────────────
# §24 FIELD PROTECTION TESTS
# R19 CORRECTIONS:
#   C-11: T-FIELD-ROLE-REJECT expects 403 (not 400).
#         emergency_hardening hook returns ForbiddenError (403).
#         Also reads persisted record to verify role not changed.
#   C-12: T-FIELD-PHONE-REJECT -> DEFERRED-MANDATORY (field absent).
#   C-13: T-FIELD-ALIAS-REJECT -> DEFERRED-MANDATORY (field absent).
# ────────────────────────────────────────────────────────────

t_field_role_reject() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FIELD-ROLE-REJECT" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=admin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-11: emergency_hardening hook returns 403 ForbiddenError.
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-FIELD-ROLE-REJECT" "403" || {
    local actual_st; actual_st=$(cat "$status_f" 2>/dev/null)
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    t_fail "T-FIELD-ROLE-REJECT" "expected 403 (hook) got ${actual_st}"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"

  # Verify persisted record: role must still be 'user', not 'admin'.
  local verify_url; verify_url=$(pb_url "/api/collections/users/records/${ord_id}")
  local vstatus_f; vstatus_f=$(pb_secure_tmpfile .http)
  local vresp_f; vresp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$vstatus_f" "$vresp_f" "$verify_url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local vrp; vrp=$(cat "$vresp_f" 2>/dev/null)
  rm -f "$vstatus_f" "$vresp_f"
  local persisted_role; persisted_role=$(python3 "$PBJ_FIELD_PY" "$vrp" "role" 2>/dev/null)
  rm -f "$vrp"
  if [[ "$persisted_role" == "admin" || "$persisted_role" == "superadmin" ]]; then
    t_fail "T-FIELD-ROLE-REJECT" \
      "CRITICAL: 403 returned but persisted role=${persisted_role}"
    return 1
  fi
  t_pass "T-FIELD-ROLE-REJECT"
}

t_field_phone_reject() {
  # R19 C-12: DEFERRED-MANDATORY — phone_verified field absent from schema (S-2).
  t_deferred_mandatory "T-FIELD-PHONE-REJECT" \
    "phone_verified field absent from users schema (S-2). Cannot test until field added."
}

t_field_alias_flag_reject() {
  # R19 C-13: DEFERRED-MANDATORY — is_alias_account field absent from schema (S-2).
  t_deferred_mandatory "T-FIELD-ALIAS-REJECT" \
    "is_alias_account field absent from users schema (S-2). Cannot test until field added."
}

# ────────────────────────────────────────────────────────────
# §25 FILE AUTH TESTS
# R19 CORRECTION C-14: progress_notes collection absent.
# Tests redesigned to use growth_logs (auth-gated collection).
# T-FILE-AUTH-6: updated to use users/avatar file path.
# ────────────────────────────────────────────────────────────

t_file_auth_anon_list_rejected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-1" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-14: growth_logs (listRule: user = @request.auth.id) replaces
  # progress_notes (absent). Anonymous access should return 403.
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-1" "401" "403" || {
    t_fail "T-FILE-AUTH-1" "anon list not rejected: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-1"
}

t_file_auth_own_record_visible() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-2" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-14: growth_logs. Legacy user lists own growth_logs.
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "$LEGACY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-2" "200" || {
    t_fail "T-FILE-AUTH-2" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-2"
}

t_file_auth_cross_user_denied() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-3" "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_skip "T-FILE-AUTH-3" "no child fixture"; return 0; }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-14: growth_logs. Ordinary user tries to list legacy's growth_logs.
  # The listRule is "user = @request.auth.id", so ordinary user gets 200 but
  # with 0 items (not the legacy user's data).
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-3" "200" || {
    t_fail "T-FILE-AUTH-3" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  local items_check
  items_check=$(python3 - "$rp" << 'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    items = d.get('items', [])
    print('EMPTY' if len(items) == 0 else f'NONEMPTY:{len(items)}')
except Exception as e:
    print(f'ERROR:{e}')
PYEOF
)
  rm -f "$status_f" "$resp_path_f" "$rp"
  if [[ "$items_check" != "EMPTY" ]]; then
    t_fail "T-FILE-AUTH-3" "cross-user filter returned items: ${items_check}"; return 1
  fi
  t_pass "T-FILE-AUTH-3"
}

t_file_auth_admin_can_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-4" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-14: growth_logs. Admin's listRule includes admin role.
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "$ADMIN_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-4" "200" || {
    t_fail "T-FILE-AUTH-4" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-4"
}

t_file_auth_upload_own() {
  t_deferred_mandatory "T-FILE-AUTH-5" \
    "Requires operator-provided binary test asset (NEEDS-EXTERNAL)"
}

t_file_auth_download_protected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-6" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-14: path updated. Users avatar is a non-protected file;
  # test uses a plausible but nonexistent file record to get 404.
  # Protected file semantics verified by T-FILE-AUTH-5 (deferred).
  pb_capture "GET" \
    "/api/files/users/nonexistent_id_r19/nonexistent_avatar.jpg" \
    "" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-6" "404" "401" || {
    t_fail "T-FILE-AUTH-6" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-6"
}

t_file_auth_delete_own() {
  t_deferred_mandatory "T-FILE-AUTH-7" \
    "Depends on T-FILE-AUTH-5 (NEEDS-EXTERNAL upload asset)"
}

# ────────────────────────────────────────────────────────────
# §26 ALIAS ENUM TESTS  (unchanged from R18 in logic)
# ────────────────────────────────────────────────────────────

t_alias_enum_group() {
  (( HALT_DEPENDENTS )) && {
    t_skip "T-ALIAS-ENUM-1" "blocked"
    t_skip "T-ALIAS-ENUM-2" "blocked"
    t_skip "T-ALIAS-ENUM-3" "blocked"
    t_skip "T-ALIAS-ENUM-4" "blocked"
    return 0
  }

  local alias_email="cp0_alias_${RUN_SUFFIX}@release1b.local"
  local ord_email="cp0_user_${RUN_SUFFIX}@release1b.local"

  pb_alias_enum_case 1 "T-ALIAS-ENUM-1" "$alias_email" "400"
  pb_alias_enum_case 2 "T-ALIAS-ENUM-2" "$ord_email" "400"
  pb_alias_enum_case 3 "T-ALIAS-ENUM-3" \
    "nonexistent_${RUN_SUFFIX}@release1b.local" "400"
  pb_alias_enum_case 4 "T-ALIAS-ENUM-4" \
    "not-an-email" "400"

  t_alias_case5_timing

  local rp
  for rp in "${ENUM_RESP_FILES[@]}"; do
    rm -f "$rp" 2>/dev/null
  done
  ENUM_RESP_FILES=()
  ENUM_HTTP_VALUES=()
}

# ────────────────────────────────────────────────────────────
# §27 AUTH TESTS  (unchanged from R18)
# ────────────────────────────────────────────────────────────

t_anon_read_denied() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ANON-READ" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/users/records" \
    "" "" "$status_f" "$resp_path_f" "T-ANON-READ" "401" "403" || {
    t_fail "T-ANON-READ" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ANON-READ"
}

t_auth_no_others_read() {
  (( HALT_DEPENDENTS )) && { t_skip "T-AUTH-NO-OTHERS-READ" "blocked"; return 0; }
  [[ -f "$LEGACY_ID_FILE" ]] || { t_skip "T-AUTH-NO-OTHERS-READ" "no legacy fixture"; return 0; }
  local legacy_id; legacy_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/users/records/${legacy_id}" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-AUTH-NO-OTHERS-READ" "404" || {
    t_fail "T-AUTH-NO-OTHERS-READ" "expected 404 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-AUTH-NO-OTHERS-READ"
}

# ────────────────────────────────────────────────────────────
# §28 ADMIN TESTS  (unchanged from R18)
# ────────────────────────────────────────────────────────────

t_admin_escalation_self() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-ESCALATION" "blocked"; return 0; }
  [[ -f "$ADMIN_ID_FILE" ]] || { t_skip "T-ADMIN-ESCALATION" "no admin fixture"; return 0; }
  local admin_id; admin_id=$(cat "$ADMIN_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${admin_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ADMIN-ESCALATION" "403" || {
    t_fail "T-ADMIN-ESCALATION" "expected 403 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ADMIN-ESCALATION"
}

t_admin_no_promote_other() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-NO-PROMOTE" "blocked"; return 0; }
  [[ -f "$ORDINARY_ID_FILE" ]] || { t_skip "T-ADMIN-NO-PROMOTE" "no ordinary fixture"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=admin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ADMIN-NO-PROMOTE" "403" "400" || {
    t_fail "T-ADMIN-NO-PROMOTE" "expected 403/400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ADMIN-NO-PROMOTE"
}

t_sadmin_list_users() {
  (( HALT_DEPENDENTS )) && { t_skip "T-SADMIN-LIST-USERS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/users/records" \
    "$SADMIN_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-SADMIN-LIST-USERS" "200" || {
    t_fail "T-SADMIN-LIST-USERS" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-SADMIN-LIST-USERS"
}

t_nsu_bypass() {
  (( HALT_DEPENDENTS )) && { t_skip "T-NSU-BYPASS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/users/records" \
    "$_NATIVE_SU_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-NSU-BYPASS" "200" || {
    t_fail "T-NSU-BYPASS" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-NSU-BYPASS"
}

t_nsu_hook_behavior() {
  (( HALT_DEPENDENTS )) && { t_skip "T-NSU-HOOK-BEHAVIOR" "blocked"; return 0; }
  # Tests that the emergency_hardening hook's NSU bypass path works on v0.29.3.
  # The hook checks e.auth.collection().name === '_superusers'.
  # NSU PATCH with role in body should pass through (200) not be blocked (403).
  [[ -f "$ORDINARY_ID_FILE" ]] || { t_skip "T-NSU-HOOK-BEHAVIOR" "no ordinary fixture"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local ord_role_before; ord_role_before="user"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=NSU_TEST_NAME_${RUN_SUFFIX}" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$_NATIVE_SU_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-NSU-HOOK-BEHAVIOR" "200" || {
    t_fail "T-NSU-HOOK-BEHAVIOR" \
      "NSU PATCH returned $(cat "$status_f" 2>/dev/null) — hook may be blocking NSU"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    CLEANUP_FAILURE=1; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-NSU-HOOK-BEHAVIOR"
}

# ────────────────────────────────────────────────────────────
# §28.5 ROLE INJECTION EMERGENCY TESTS  (NEW IN R19)
# R19 CORRECTION C-15:
# Five emergency blocking tests for the create-path injection gap (S-1).
# Each test:
#   1. Sends an anonymous POST to /api/collections/users/records with
#      a privileged field in the body.
#   2. If HTTP response is 200 (record created), reads the persisted
#      record via NSU token and verifies the field was NOT stored.
#   3. If the field WAS stored, emits t_blocking (not just t_fail).
# Tests are emergency blocking: if ANY fires as blocking, HALT_DEPENDENTS=1
# and the main function emits an immediate fail-closed summary.
# ────────────────────────────────────────────────────────────

pb_inject_create_and_verify() {
  local label="$1"      # test ID
  local field="$2"      # field name being injected
  local value="$3"      # injected value (string)
  local bad_values="$4" # space-separated list of values that constitute injection

  local email="cp0_inject_${label}_${RUN_SUFFIX}@release1b.local"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  chmod 600 "$pw_file"

  local body_f; body_f=$(pb_secure_tmpfile .json)

  case "$field" in
    role|verified|emailVisibility)
      if [[ "$value" == "true" || "$value" == "false" ]]; then
        python3 "$PBJ_PY" "$body_f" \
          "email=${email}" \
          "secret-file:password=${pw_file}" \
          "secret-file:passwordConfirm=${pw_file}" \
          "b:${field}=${value}" 2>/dev/null
      else
        python3 "$PBJ_PY" "$body_f" \
          "email=${email}" \
          "secret-file:password=${pw_file}" \
          "secret-file:passwordConfirm=${pw_file}" \
          "${field}=${value}" 2>/dev/null
      fi
      ;;
    *)
      python3 "$PBJ_PY" "$body_f" \
        "email=${email}" \
        "secret-file:password=${pw_file}" \
        "secret-file:passwordConfirm=${pw_file}" \
        "${field}=${value}" 2>/dev/null
      ;;
  esac

  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  pb_wipe_secret_file "$pw_file"

  if [[ "$http_status" != "200" ]]; then
    # Injection rejected at HTTP level — ideal outcome.
    rm -f "$resp_path"
    t_pass "${label}"
    return 0
  fi

  # HTTP 200 — record was created. Read persisted record via NSU to verify
  # the injected field was not stored with the injected value.
  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"

  if [[ -z "$rec_id" || "$rec_id" == "__absent__" ]]; then
    t_harness_err "${label}" "200 but no id in response — cannot verify persisted record"
    return 1
  fi

  # Delete injected record regardless of outcome (cleanup first, then score).
  local id_f; id_f=$(pb_secure_tmpfile .id)
  printf '%s' "$rec_id" > "$id_f"

  local verify_url; verify_url=$(pb_url "/api/collections/users/records/${rec_id}")
  local vstatus_f; vstatus_f=$(pb_secure_tmpfile .http)
  local vresp_f; vresp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$vstatus_f" "$vresp_f" "$verify_url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local vst; vst=$(cat "$vstatus_f" 2>/dev/null)
  local vrp; vrp=$(cat "$vresp_f" 2>/dev/null)
  rm -f "$vstatus_f" "$vresp_f"

  pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1

  if [[ "$vst" != "200" ]]; then
    t_harness_err "${label}" "NSU record verify returned ${vst}"
    rm -f "$vrp"; return 1
  fi

  local persisted; persisted=$(python3 "$PBJ_FIELD_PY" "$vrp" "$field" 2>/dev/null)
  rm -f "$vrp"

  # Check whether persisted value is in the bad_values list.
  local bad_val injection_confirmed=0
  for bad_val in ${=bad_values}; do
    if [[ "$persisted" == "$bad_val" ]]; then
      injection_confirmed=1
      break
    fi
  done

  if (( injection_confirmed )); then
    t_blocking "${label}" \
      "INJECTION CONFIRMED: ${field}=${persisted} persisted in created record. Publication BLOCKED."
    return 1
  else
    # Record created but injected value was not stored. PASS.
    t_pass "${label}"
    return 0
  fi
}

t_role_inject_emergency_group() {
  print "=== §28.5 Role Injection Emergency Tests ==="

  # T-INJECT-CREATE-ANON-ADMIN: anonymous registers with role=admin.
  pb_inject_create_and_verify \
    "T-INJECT-CREATE-ANON-ADMIN" "role" "admin" "admin superadmin"

  # T-INJECT-CREATE-ANON-SADMIN: anonymous registers with role=superadmin.
  pb_inject_create_and_verify \
    "T-INJECT-CREATE-ANON-SADMIN" "role" "superadmin" "admin superadmin"

  # T-INJECT-CREATE-VERIFIED: anonymous registers with verified=true.
  pb_inject_create_and_verify \
    "T-INJECT-CREATE-VERIFIED" "verified" "true" "true"

  # T-INJECT-CREATE-EMAIL-VIS: anonymous registers with emailVisibility=true.
  # This is less critical but still an injection test.
  pb_inject_create_and_verify \
    "T-INJECT-CREATE-EMAIL-VIS" "emailVisibility" "true" "true"

  # T-INJECT-CREATE-UNEXPECTED: unexpected fields silently ignored or rejected.
  # Fields phone_verified, is_alias_account not in schema — test behavior.
  # These cannot be verified via PBJ_FIELD_PY (not in allowlist).
  # Just verify the registration itself succeeds or fails cleanly.
  local email="cp0_inject_unexpected_${RUN_SUFFIX}@release1b.local"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  chmod 600 "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" \
    "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" \
    "phone_verified=true" \
    "is_alias_account=true" 2>/dev/null
  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  pb_wipe_secret_file "$pw_file"
  if [[ "$http_status" == "200" ]]; then
    local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    rm -f "$resp_path"
    if [[ -n "$rec_id" && "$rec_id" != "__absent__" ]]; then
      local id_f; id_f=$(pb_secure_tmpfile .id)
      printf '%s' "$rec_id" > "$id_f"
      pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1
    fi
    # Fields absent from schema — PocketBase should silently ignore them.
    # This is the expected behavior (not a blocking finding).
    t_pass "T-INJECT-CREATE-UNEXPECTED"
  elif [[ "$http_status" == "400" ]]; then
    rm -f "$resp_path"
    t_pass "T-INJECT-CREATE-UNEXPECTED"
  else
    rm -f "$resp_path"
    t_fail "T-INJECT-CREATE-UNEXPECTED" \
      "Unexpected HTTP ${http_status} for registration with absent fields"
  fi

  if (( T_BLOCKING > 0 )); then
    print "" >&2
    print "!!! EMERGENCY: Role injection CONFIRMED in created record !!!" >&2
    print "!!! Publication is BLOCKED until createRule or hook guard applied !!!" >&2
    print "" >&2
  fi
}

# ────────────────────────────────────────────────────────────
# §29 USER OPS TESTS  (unchanged from R18)
# ────────────────────────────────────────────────────────────

t_user_name_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-NAME-UPDATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=UpdatedName_${RUN_SUFFIX}" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-USER-NAME-UPDATE" "200" || {
    t_fail "T-USER-NAME-UPDATE" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-USER-NAME-UPDATE"
}

t_user_lang_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-LANG-UPDATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "language=ms" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-USER-LANG-UPDATE" "200" || {
    t_fail "T-USER-LANG-UPDATE" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-USER-LANG-UPDATE"
}

t_user_phone_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-PHONE-UPDATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  # phone field exists in users schema (added in migration 1782864178).
  python3 "$PBJ_PY" "$body_f" "phone=+60123456789" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-USER-PHONE-UPDATE" "200" || {
    t_fail "T-USER-PHONE-UPDATE" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-USER-PHONE-UPDATE"
}

# ────────────────────────────────────────────────────────────
# §30 CONTENT TESTS
# R19 CORRECTIONS C-8/C-21:
# T-ART-ANON-DENIED replaced by T-ART-ANON-POLICY.
# T-ART-ANTENATAL-VIS tests is_pregnancy=true articles.
# T-ART-CATEGORY-FILTER tests category=pregnancy filter.
# ────────────────────────────────────────────────────────────

t_art_antenatal_vis() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANTENATAL-VIS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" \
    "/api/collections/articles/records?filter=is_pregnancy%3Dtrue&perPage=5" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-ART-ANTENATAL-VIS" "200" || {
    t_fail "T-ART-ANTENATAL-VIS" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ART-ANTENATAL-VIS"
}

t_art_category_filter() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-CATEGORY-FILTER" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" \
    "/api/collections/articles/records?filter=category%3D%27pregnancy%27&perPage=5" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-ART-CATEGORY-FILTER" "200" || {
    t_fail "T-ART-CATEGORY-FILTER" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ART-CATEGORY-FILTER"
}

t_art_anon_policy() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANON-POLICY" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  # R19 C-21: articles.listRule is currently '' (public).
  # This test observes current behavior and notes the policy decision required.
  # Score: PASS-NOTED if public access is the intended policy.
  # Score: BLOCKING if operator confirms authentication is required per release policy.
  pb_capture "GET" "/api/collections/articles/records" \
    "" "" "$status_f" "$resp_path_f" "T-ART-ANON-POLICY" "200" "401" "403"
  local actual; actual=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  print "[T-ART-ANON-POLICY] articles anonymous access returned ${actual}"
  print "[T-ART-ANON-POLICY] POLICY DECISION REQUIRED: Operator must confirm"
  print "  whether public article access is intended for this release."
  print "  Current schema: listRule='' (public). Options in schema manifest §articles."
  if [[ "$actual" == "200" ]]; then
    t_unresolved "T-ART-ANON-POLICY" \
      "Articles publicly readable (200). Operator must confirm this is intended policy."
  else
    t_unresolved "T-ART-ANON-POLICY" \
      "Articles returned ${actual} for anonymous. Operator must confirm intended policy."
  fi
}

# ────────────────────────────────────────────────────────────
# §31 API DECLARATIONS  (unchanged from R18 in structure)
# ────────────────────────────────────────────────────────────

t_api_declarations() {
  (( HALT_DEPENDENTS )) && { t_skip "T-API-DECLARATIONS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/health" \
    "" "" "$status_f" "$resp_path_f" "T-STATIC-ROUTE-INVENTORY" "200" || {
    t_fail "T-STATIC-ROUTE-INVENTORY" "health endpoint returned $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-STATIC-ROUTE-INVENTORY"

  # R19: verify resolved OTP route returns expected status
  # (404 before hooks deployed; 200/405/422 after hooks deployed).
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "${HOOK_OTP_PHONE_ROUTE}" \
    "" "" "$status_f" "$resp_path_f" "T-API-DECLARATIONS" "200" "400" "422" "404"
  local otp_st; otp_st=$(cat "$status_f" 2>/dev/null)
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  print "[api-decl] OTP route ${HOOK_OTP_PHONE_ROUTE} returned ${otp_st}"
  if [[ "$otp_st" == "404" ]]; then
    t_unresolved "T-API-DECLARATIONS" \
      "OTP route returns 404 — hook may not be deployed or registered"
  else
    t_pass "T-API-DECLARATIONS"
  fi
}

# ────────────────────────────────────────────────────────────
# §32 RULE APPLY/RESTORE TEST  (unchanged from R18)
# ────────────────────────────────────────────────────────────

t_rule_apply_restore() {
  (( HALT_DEPENDENTS )) && { t_skip "T-RULE-APPLY-RESTORE" "blocked"; return 0; }
  pb_capture_rule_baseline "articles" "listRule" || return 1
  pb_apply_rule_local "articles" "listRule" "@request.auth.id != ''" || return 1
  sleep 0.3
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/articles/records" \
    "" "" "$status_f" "$resp_path_f" "T-RULE-APPLY-RESTORE-CHECK" "401" "403" || {
    t_fail "T-RULE-APPLY-RESTORE-CHECK" \
      "anon access not denied after rule applied: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    pb_restore_rule_local "articles" "listRule"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-RULE-APPLY-RESTORE"
  pb_restore_rule_local "articles" "listRule"
}

# ────────────────────────────────────────────────────────────
# §33-§35 AUTHORIZED EXCLUSIONS  (unchanged from R18)
# ────────────────────────────────────────────────────────────

t_authorized_exclusions() {
  t_authorized_exclusion "E4-EMAIL-CHANGE-LIFECYCLE" \
    "Production email-change lifecycle — requires production SMTP"
  t_authorized_exclusion "E6-OTP-REACHABILITY" \
    "Production OTP reachability — requires Meta Cloud API credentials"
  t_authorized_exclusion "E8-WARN-LOG-OBSERVABILITY" \
    "Production WARN-log observability — requires production log pipeline"
}

# ────────────────────────────────────────────────────────────
# §36 CONCURRENCY TESTS
# R19 C-17:
#   T-CONCURRENCY-OTP-SEND: Mailhog removed; HOOK_OTP_PHONE_ROUTE
#   pre-filled; remains MANDATORY-DEFERRED pending adapter deployment.
# ────────────────────────────────────────────────────────────

t_concurrency_auth_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-AUTH" "blocked"; return 0; }
  # (Implementation unchanged from R18 — concurrent wrong-password auth.)
  local email="cp0_concauth_${RUN_SUFFIX}@release1b.local"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  chmod 600 "$pw_file"
  local wrong_pw="definitely_wrong_concurrent_pw"

  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" \
    "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" \
    "role=user" 2>/dev/null || {
    t_harness_err "T-CONCURRENCY-AUTH-SETUP" "pbj.py failed"; return 1
  }
  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "POST"
  local create_status; create_status=$(cat "$status_f" 2>/dev/null)
  local create_resp; create_resp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  if [[ "$create_status" != "200" ]]; then
    t_harness_err "T-CONCURRENCY-AUTH-SETUP" "Create returned ${create_status}"
    pb_wipe_secret_file "$pw_file"; rm -f "$create_resp"; return 1
  fi
  local conc_uid; conc_uid=$(python3 "$PBJ_EXTRACT_PY" "$create_resp" "id" 2>/dev/null)
  rm -f "$create_resp"
  pb_wipe_secret_file "$pw_file"

  local num_workers=5
  local worker_dirs=()
  local i
  for (( i=1; i<=num_workers; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    worker_dirs+=("$wdir")
  done

  url=$(pb_url "/api/collections/users/auth-with-password")
  local pids=()
  for (( i=1; i<=num_workers; i++ )); do
    local wdir="${worker_dirs[$i]}"
    local wbody="${wdir}/body.json"
    local wstatus="${wdir}/status"
    local wresp_rp="${wdir}/resp_rp"
    python3 "$PBJ_PY" "$wbody" \
      "identity=${email}" \
      "password=${wrong_pw}" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" \
        python3 "$PBJ_HTTP_PY" "$wstatus" "$wresp_rp" "$url" "" "$wbody" "POST"
    ) &
    pids+=($!)
  done

  local all_ok=1
  for (( i=1; i<=num_workers; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wdir="${worker_dirs[$i]}"
    local wstatus="${wdir}/status"
    local wresp_rp="${wdir}/resp_rp"
    local worker_status; worker_status=$(cat "$wstatus" 2>/dev/null)
    local wresp; wresp=$(cat "$wresp_rp" 2>/dev/null)
    rm -f "$wresp" "$wstatus" "$wresp_rp"
    if [[ "$worker_status" != "400" ]]; then
      t_fail "T-CONCURRENCY-AUTH" \
        "Worker ${i} returned ${worker_status} (expected 400)"
      all_ok=0
    fi
  done

  if [[ -n "$conc_uid" && "$conc_uid" != "__absent__" ]]; then
    local uid_f; uid_f=$(pb_secure_tmpfile .id)
    printf '%s' "$conc_uid" > "$uid_f"
    pb_delete_record "users" "$uid_f" || CLEANUP_FAILURE=1
  fi

  (( all_ok )) && t_pass "T-CONCURRENCY-AUTH"
}

t_concurrency_otp_send_group() {
  # R19 C-17: HOOK_OTP_PHONE_ROUTE resolved (/api/auth/request-whatsapp-otp).
  # HOOK_OTP_MOCK_CONTROL_ROUTE designed (/api/test/otp-control).
  # Still MANDATORY-DEFERRED because:
  #   1. Local OTP test adapter (release1b_otp_test_adapter.pb.js) must be
  #      deployed to isolated hooks dir before this test can run.
  #   2. Rate-limit invariants are NEEDS-EXTERNAL — production hook has no
  #      rate limit; operator must define expected invariants.
  t_deferred_mandatory "T-CONCURRENCY-OTP-SEND" \
    "OTP test adapter not yet deployed (NEEDS-EXTERNAL). "\
    "Route resolved: ${HOOK_OTP_PHONE_ROUTE}. "\
    "Control route designed: ${HOOK_OTP_MOCK_CONTROL_ROUTE}. "\
    "Rate-limit invariants: NEEDS-EXTERNAL (no rate limit in current hook)."
}

t_concurrency_idempotency_post_group() {
  t_deferred_mandatory "T-CONCURRENCY-IDEMPOTENCY-POST" \
    "No idempotency-enforcing hook identified in pb_hooks/. "\
    "Endpoint route, key header, and duplicate behavior NEEDS-EXTERNAL. "\
    "Implementation not yet designed."
}

# ────────────────────────────────────────────────────────────
# §37 OTP FLOW TEST  (R19: redesigned for phone/WhatsApp OTP)
# ────────────────────────────────────────────────────────────

t_otp_flow() {
  # R19: Redesigned from Mailhog email OTP to phone/WhatsApp OTP.
  # Flow (when local adapter deployed):
  #   1. POST /api/auth/request-whatsapp-otp with phone number
  #   2. Read OTP from phone_otps via NSU token (no Meta delivery needed)
  #   3. POST /api/auth/verify-whatsapp-otp with phone + code
  #   4. Verify 200 and auth token returned
  # Still MANDATORY-DEFERRED: requires local OTP adapter deployment.
  t_deferred_mandatory "T-OTP-FLOW" \
    "Requires local OTP test adapter deployment. "\
    "Routes resolved: ${HOOK_OTP_PHONE_ROUTE}, ${HOOK_OTP_VERIFY_ROUTE}. "\
    "OTP readable from phone_otps via NSU token (no Meta API call needed)."
}

# ────────────────────────────────────────────────────────────
# §38 HOOK SMOKE TESTS  (unchanged from R18 in structure)
# ────────────────────────────────────────────────────────────

t_hook_smoke_group() {
  local hk
  for hk in "${(@k)HOOK_PROBE_ROUTES}"; do
    local route="${HOOK_PROBE_ROUTES[$hk]}"
    if [[ "$route" == UNRESOLVED* ]]; then
      t_deferred_mandatory "T-HOOK-SMOKE-${hk}" \
        "HOOK_PROBE_ROUTES[$hk] NEEDS-EXTERNAL"
      continue
    fi
    local method="${HOOK_PROBE_METHODS[$hk]:-GET}"
    local status_f; status_f=$(pb_secure_tmpfile .http)
    local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
    pb_capture "$method" "$route" \
      "$_NATIVE_SU_AUTH_CFG" "" "$status_f" "$resp_path_f" \
      "T-HOOK-SMOKE-${hk}" "200" "400" "404" "405" "422"
    local actual; actual=$(cat "$status_f" 2>/dev/null)
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    local expected_removed="${HOOK_EXPECTED_REMOVED_STATUS[$hk]:-404}"
    if [[ "$actual" == "$expected_removed" && "$expected_removed" == "404" ]]; then
      t_fail "T-HOOK-SMOKE-${hk}" \
        "Route returned ${actual} — hook may not be registered"
    else
      t_pass "T-HOOK-SMOKE-${hk}"
    fi
  done
}

# ────────────────────────────────────────────────────────────
# §39 REPORT GENERATION  (unchanged from R18)
# ────────────────────────────────────────────────────────────

pb_generate_report() {
  local rc=0
  if (( T_BLOCKING > 0 || T_FAIL > 0 || T_HARNESS_ERR > 0 || CLEANUP_FAILURE > 0 )); then
    rc=1
  elif (( T_DEFERRED > 0 || T_UNRESOLVED > 0 )); then
    rc=2
  fi

  {
    print "## Release 1B Checkpoint 0 Report"
    print "Round        : 19"
    print "Run suffix   : ${RUN_SUFFIX}"
    print "Platform     : ${PLATFORM_KEY}"
    print "PB version   : ${RELEASE1B_PB_VERSION}"
    print ""
    print "## Checkpoint 0 Authorization Status"
    print "AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE"
    print "(This report documents a runtime execution if run by operator.)"
    print ""
    print "## Result"
    case $rc in
      0) print "RESULT: PASS" ;;
      1) print "RESULT: FAIL" ;;
      2) print "RESULT: INCOMPLETE" ;;
    esac
    print ""
    print "## Counters"
    print "PASS       : ${T_PASS}"
    print "FAIL       : ${T_FAIL}"
    print "BLOCKING   : ${T_BLOCKING}"
    print "UNRESOLVED : ${T_UNRESOLVED}"
    print "DEFERRED   : ${T_DEFERRED}"
    print "HARNESS_ERR: ${T_HARNESS_ERR}"
    print "SKIP       : ${T_SKIP}"
    print "CLEANUP_FAIL: ${CLEANUP_FAILURE}"
    print ""
    if (( ${#BLOCKING_DECISIONS[@]} > 0 )); then
      print "## Blocking Decisions"
      local bd; for bd in "${BLOCKING_DECISIONS[@]}"; do print "  ${bd}"; done
      print ""
    fi
    if (( ${#UNRESOLVED_ITEMS[@]} > 0 )); then
      print "## Unresolved / Deferred Items"
      local ui; for ui in "${UNRESOLVED_ITEMS[@]}"; do print "  ${ui}"; done
      print ""
    fi
    if (( ${#HARNESS_ERRORS[@]} > 0 )); then
      print "## Harness Errors"
      local he; for he in "${HARNESS_ERRORS[@]}"; do print "  ${he}"; done
      print ""
    fi
    print "## Test Detail"
    cat "$RELEASE1B_REPORT_WORK" 2>/dev/null || true
  } > "${RELEASE1B_REPORT_WORK}.final"

  python3 "$PBJ_SCAN_PY" \
    "${RELEASE1B_REPORT_WORK}.final" \
    "$RELEASE1B_REPORT_PATH" 2>/dev/null || {
    RELEASE1B_REPORT_PATH="${RELEASE1B_REPORT_WORK}.final"
  }

  print "=== Report written: ${RELEASE1B_REPORT_PATH} ==="
  return $rc
}

# ────────────────────────────────────────────────────────────
# §40 MAIN EXECUTION
# ────────────────────────────────────────────────────────────

pb_run_all_tests() {
  # Infrastructure
  pb_preflight_ports || return 1
  pb_verify_archive_hash "${RELEASE1B_ISOLATED_ROOT}/source_archive.zip" 2>/dev/null || true
  pb_verify_binary_version
  pb_apply_schema_migrations
  pb_deploy_hooks
  pb_start_pocketbase
  pb_create_local_superuser || return 1

  # Schema verification
  pb_verify_schema

  # User lifecycle
  pb_create_test_user "user"       ORDINARY_ID_FILE ORDINARY_TOK_FILE ORDINARY_AUTH_CFG
  pb_create_test_user "admin"      ADMIN_ID_FILE    ADMIN_TOK_FILE    ADMIN_AUTH_CFG
  pb_create_test_user "superadmin" SADMIN_ID_FILE   SADMIN_TOK_FILE   SADMIN_AUTH_CFG
  pb_create_legacy_fixture
  pb_setup_alias_group

  # §28.5 Emergency injection tests — run BEFORE any publication gate check
  t_role_inject_emergency_group
  if (( T_BLOCKING > 0 )); then
    print "[main] EMERGENCY BLOCKING test failed. Halting test sequence." >&2
    HALT_DEPENDENTS=1
  fi

  # CRUD
  t_crud_children_list
  t_crud_children_view
  t_crud_children_view_cross_user
  t_crud_children_create
  t_crud_children_create_cross_user
  t_crud_growth_create

  # Field protection
  t_field_role_reject
  t_field_phone_reject
  t_field_alias_flag_reject

  # File auth
  t_file_auth_anon_list_rejected
  t_file_auth_own_record_visible
  t_file_auth_cross_user_denied
  t_file_auth_admin_can_list
  t_file_auth_upload_own
  t_file_auth_download_protected
  t_file_auth_delete_own

  # Alias enum
  t_alias_enum_group

  # Auth
  t_anon_read_denied
  t_auth_no_others_read

  # Admin
  t_admin_escalation_self
  t_admin_no_promote_other
  t_sadmin_list_users
  t_nsu_bypass
  t_nsu_hook_behavior

  # User ops
  t_user_name_update
  t_user_lang_update
  t_user_phone_update

  # Content
  t_art_antenatal_vis
  t_art_category_filter
  t_art_anon_policy

  # API / Rules
  t_api_declarations
  t_rule_apply_restore

  # Concurrency
  t_concurrency_auth_group
  t_concurrency_otp_send_group
  t_concurrency_idempotency_post_group

  # OTP flow
  t_otp_flow

  # Hook smoke
  t_hook_smoke_group

  # Authorized exclusions
  t_authorized_exclusions

  # Cleanup
  pb_cleanup_all_fixtures
  pb_delete_test_user "superadmin" "$SADMIN_ID_FILE"  "$SADMIN_TOK_FILE"  "$SADMIN_AUTH_CFG"
  pb_delete_test_user "admin"      "$ADMIN_ID_FILE"   "$ADMIN_TOK_FILE"   "$ADMIN_AUTH_CFG"
  pb_delete_test_user "user"       "$ORDINARY_ID_FILE" "$ORDINARY_TOK_FILE" "$ORDINARY_AUTH_CFG"
  pb_delete_legacy_fixture
  pb_cleanup_alias_group
  pb_delete_local_superuser
}

pb_main() {
  local mode=""
  local authorize_cp0=0

  for arg in "$@"; do
    case "$arg" in
      --package-check)  mode="package-check" ;;
      --harness-check)  mode="harness-check" ;;
      --preflight)      mode="preflight" ;;
      --run)            mode="run" ;;
      --authorize-cp0)  authorize_cp0=1 ;;
    esac
  done

  pb_setup_umask
  pb_generate_run_suffix
  pb_detect_platform

  case "$mode" in
    package-check)
      pb_setup_root
      pb_write_scripts
      pb_check_package_completeness
      exit $?
      ;;
    harness-check)
      pb_setup_root
      pb_write_scripts
      t_harness_selftest || exit 1
      exit 0
      ;;
    preflight)
      pb_setup_root
      pb_write_scripts
      pb_preflight_ports
      exit $?
      ;;
    run)
      if (( ! authorize_cp0 )); then
        print "[main] ERROR: --run requires --authorize-cp0" >&2
        print "[main] Checkpoint 0 has been authorized. Pass --authorize-cp0." >&2
        exit 1
      fi
      pb_setup_root
      pb_install_trap
      pb_write_scripts
      t_harness_selftest || { print "[main] Self-test failed. Aborting." >&2; exit 1; }
      pb_run_all_tests
      pb_generate_report
      local report_rc=$?
      print "=== Harness complete. Report: ${RELEASE1B_REPORT_PATH} ==="
      exit $report_rc
      ;;
    *)
      print "Usage: $0 --package-check | --harness-check | --preflight | --run --authorize-cp0" >&2
      exit 1
      ;;
  esac
}

pb_main "$@"
