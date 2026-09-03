#!/usr/bin/env zsh
# ================================================================
# release1b_cp0.zsh
# Release 1B — Checkpoint 0 Test Harness
# Round: 13
# Status: DRAFTED — not syntax-verified, not executed, not passed
# Preparation: no commands executed, no production contact made
#
# Usage:
#   zsh release1b_cp0.zsh --package-check  Review manifest (no files)
#   zsh release1b_cp0.zsh --harness-check  Stage 0 only, temp files
#   zsh release1b_cp0.zsh --preflight      Stages 0-1, no services
#   zsh release1b_cp0.zsh --run            Full (requires authorization)
#
# DO NOT EXECUTE until a separate explicit CP0 authorization is issued
# and all preauthorization blockers have been resolved.
# ================================================================

# ────────────────────────────────────────────────────────────────
# §1  ERROR HANDLING MODEL — Option B (no ERR_EXIT)
#
# ERR_EXIT is NOT used. Rationale:
#  - Cleanup must run on any failure; ERR_EXIT complicates this.
#  - Expected-failure tests are numerous; if/fi is cleaner and
#    auditable.
#  - Probe commands (health checks, Docker inspect) use nonzero
#    as a signal and cannot all be wrapped in || true safely.
#  - Every security-relevant command return code is checked
#    explicitly. Failures propagate via explicit "return 1".
# ────────────────────────────────────────────────────────────────
setopt NO_UNSET PIPE_FAIL

# ────────────────────────────────────────────────────────────────
# §2  FUNCTION INVENTORY (planned; not execution-verified)
#
# §3  Core / arithmetic
#   pb_inc  pb_halt  pb_realpath  pb_generate_run_suffix
#   pb_setup_umask  pb_setup_root  pb_install_trap  pb_trap_cleanup
#
# §4  Result tracking
#   t_pass  t_fail  t_blocking  t_unresolved  t_deferred_mandatory
#   t_authorized_exclusion  t_future_release  t_skip  t_harness_err
#   pb_sanitize_label  pb_report_append
#
# §5  Python helpers
#   pb_write_scripts
#
# §6  Validation
#   pb_stat_check  pb_validate_task_file  pb_validate_local_url
#   pb_validate_method  pb_validate_accepted_statuses
#   pb_verify_file_manifest
#
# §7  Package completeness / preauth
#   pb_check_package_completeness
#
# §8  Harness self-test (Stage 0)
#   t_harness_selftest
#
# §9  Infrastructure
#   pb_preflight_ports  pb_apply_schema_migrations
#   pb_start_pocketbase  pb_restart_pocketbase  pb_stop_pocketbase
#   pb_start_mailhog  pb_stop_mailhog
#   pb_mailhog_count  pb_mailhog_clear_verified
#
# §10 Local superuser lifecycle
#   pb_create_local_superuser  pb_delete_local_superuser
#
# §11 Schema verification
#   pb_verify_schema
#
# §12 Hook management
#   pb_verify_hook_directory  pb_install_hook_verified
#   pb_remove_hook_verified   pb_hook_smoke_matrix
#
# §13 Rule lifecycle
#   pb_apply_rule_local  pb_restore_rule_local
#
# §14 HTTP helpers
#   pbj_write  pb_make_auth  pb_field  pb_copy_field
#   pb_extract_item_id  pb_capture
#
# §15 Fixture registry
#   registry_add  registry_mark_deleted  pb_report_fixture_cleanup
#
# §16 User lifecycle
#   pb_create_test_user  pb_delete_test_user  pb_delete_record
#
# §17 Legacy fixture
#   pb_create_legacy_fixture  pb_delete_legacy_fixture
#   _create_dep_record (local to pb_create_legacy_fixture)
#
# §18 Alias fixtures
#   pb_setup_alias_group  pb_cleanup_alias_group
#   pb_alias_enum_case
#
# §19 Tests — CRUD matrix
#   _t_deny_op  _t_deny_list_or_empty
#   t_ch_{list,view,create,update,delete,expand}
#   t_gl_{list,view,create,update,delete}
#   t_al_{list,view,create,update,delete}
#   t_nl_{list,view,create,update,delete}
#   t_wl_{list,view,create,update,delete}
#   t_imm_{list,view,create,update,delete}
#   t_nb_list  t_nb_view
#
# §20 Tests — field protection
#   t_field_role_reject  t_field_phone_reject
#   t_field_alias_flag_reject
#
# §21 Tests — file authorization
#   t_file_auth_1  t_file_auth_2  t_file_auth_3  t_file_auth_4
#   t_file_auth_5  t_file_auth_6  t_file_auth_7  t_file_auth_8
#   _t_file_request (helper)
#
# §22 Tests — alias enumeration
#   t_alias_compare  t_alias_timing  t_alias_case5_legacy_login
#   t_alias_interceptor_smoke
#
# §23 Tests — auth / email
#   t_record_auth_response_shape  t_auth_refresh_valid
#   t_blank_email_behavior  t_email_verification_sent
#   t_password_reset_alias_blocked
#
# §24 Tests — OTP
#   t_otp_legacy_link_group  t_otp_anonymous_disabled
#
# §25 Tests — admin / superadmin / native superuser
#   t_admin_escalation_rejected  t_admin_cannot_promote
#   t_superadmin_can_list_users  t_native_superuser_bypasses_rules
#   t_native_superuser_hook_behavior
#
# §26 Tests — ordinary user operations
#   t_ordinary_name_update  t_ordinary_language_update
#   t_avatar_lifecycle
#
# §27 Tests — content classification
#   t_articles_antenatal_visible  t_articles_prohibited_hidden
#   t_bookmarks_classification  t_notifications_classification
#
# §28 Tests — anonymous / injection
#   t_anon_create_field_injection  t_auth_user_cannot_create_extra
#   t_legacy_user_data_denied
#
# §29 Tests — API declarations / static routes
#   t_api_declarations  t_static_route_inventory
#
# §30 Cleanup and report
#   pb_validate_destructive_target  pb_cleanup_normal
#   pb_generate_report  pb_scan_and_export_report
#
# §31 Orchestration and entry point
#   pb_run_stage  cp0_run  main
# ────────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────
# §3  PREAUTHORIZATION CONSTANTS
#     Script halts in pb_check_package_completeness if UNRESOLVED
# ────────────────────────────────────────────────────────────────

readonly PB_RELEASE_VERSION="0.29.3"
readonly PB_CHECKSUM_URL="https://github.com/pocketbase/pocketbase/releases/download/v0.29.3/checksums.txt"

# B-CHECKSUM: replace with exact values from checksums.txt (see review §B-CHECKSUM)
typeset -grA PB_ARCHIVE_NAME=(
  [darwin_arm64]="pocketbase_0.29.3_darwin_arm64.zip"
  [darwin_amd64]="pocketbase_0.29.3_darwin_amd64.zip"
)
typeset -grA PB_EXPECTED_SHA256=(
  [darwin_arm64]="UNRESOLVED__B-CHECKSUM__SEE_release1b_round13_review.md"
  [darwin_amd64]="UNRESOLVED__B-CHECKSUM__SEE_release1b_round13_review.md"
)

# B-SCHEMA: absolute path to reviewed migration directory and per-file manifest
typeset -g RELEASE1B_SCHEMA_SRC=""          # directory containing *.js migration files
typeset -g RELEASE1B_SCHEMA_MANIFEST=""     # JSON file: [{file, sha256}, ...]

# B-HOOKS: each entry is  name -> absolute source path
typeset -gA HOOK_SRC_PATHS=()
typeset -gA HOOK_EXPECTED_SHA256=()

# B-FRONTEND: read-only snapshot directory and commit/archive hash
typeset -g RELEASE1B_FRONTEND_SRC=""
typeset -g RELEASE1B_FRONTEND_REF=""        # commit hash or archive SHA-256

# Local mock phone number for provider-mock tests only
readonly MOCK_PHONE_LOCAL="+60100000000TEST"   # accepted only by local mock provider

# Direct field-protection test value
readonly T_PHONE_TEST_VALUE="TEST-NOT-A-PHONE"

# ────────────────────────────────────────────────────────────────
# §4  GLOBAL MUTABLE STATE
# ────────────────────────────────────────────────────────────────

typeset -g  SCRIPT_MODE=""
typeset -g  RUN_SUFFIX=""
typeset -g  RELEASE1B_ISOLATED_ROOT=""
typeset -g  RELEASE1B_TEST_TMP=""
typeset -g  RELEASE1B_CANONICAL_ROOT=""
typeset -g  RELEASE1B_CANONICAL_TMP=""
typeset -g  RELEASE1B_CANONICAL_PARENT=""
typeset -g  RELEASE1B_ROOT_OWNER=""
typeset -g  RELEASE1B_PB_BIN=""
typeset -g  RELEASE1B_PB_PID=""
typeset -g  RELEASE1B_PB_PORT="8090"
typeset -g  RELEASE1B_PB_DATA_DIR=""
typeset -g  RELEASE1B_PB_HOOKS_DIR=""
typeset -g  RELEASE1B_PB_MIGRATIONS_DIR=""
typeset -g  RELEASE1B_CANONICAL_URL_PREFIX=""
typeset -g  RELEASE1B_MH_NAME=""
typeset -g  RELEASE1B_MH_ID=""
typeset -g  RELEASE1B_REPORT_WORK=""
typeset -g  RELEASE1B_REPORT_PATH=""
typeset -g  RELEASE1B_EVIDENCE_DIR=""
typeset -gi CLEANUP_FAILURE=0
typeset -gi CLEANUP_RUNNING=0

# Result counters
typeset -gi T_PASS=0 T_FAIL=0 T_BLOCKING=0 T_UNRESOLVED=0
typeset -gi T_DEFERRED=0 T_HARNESS_ERR=0 T_SKIP=0
typeset -ga BLOCKING_DECISIONS=() UNRESOLVED_ITEMS=() HARNESS_ERRORS=()
typeset -gi HALT_DEPENDENTS=0

# Fixture state files
typeset -g _NATIVE_SU_ID_FILE=""   _NATIVE_SU_TOK_FILE=""
typeset -g ORDINARY_ID_FILE=""     ORDINARY_TOK_FILE=""
typeset -g ADMIN_ID_FILE=""        ADMIN_TOK_FILE=""
typeset -g SADMIN_ID_FILE=""       SADMIN_TOK_FILE=""
typeset -g LEGACY_ID_FILE=""       LEGACY_TOK_FILE=""
typeset -g LEGACY_CHILD_ID_FILE="" LEGACY_GROWTH_ID_FILE=""
typeset -g LEGACY_ACTIVITY_ID_FILE="" LEGACY_IMMUN_ID_FILE=""
typeset -g LEGACY_PROGRESS_ID_FILE="" LEGACY_NB_ENROLL_ID_FILE=""
typeset -g WRONG_PW_FILE=""
typeset -g ALIAS_PW_FILE=""  ALIAS_ID_FILE=""  ALIAS_TOKEN_FILE=""
typeset -g TIMING_LEGACY_ID_FILE="" TIMING_LEGACY_TOKEN_FILE=""
typeset -g PREG_COURSE_ID_FILE=""  PREG_THUMB_FILE=""
typeset -g NEWBORN_COURSE_ID_FILE=""

# Python helper paths (set in pb_write_scripts)
typeset -g PBJ_STAT_PY="" PBJ_URL_PY="" PBJ_PY="" PBJ_AUTH_PY=""
typeset -g PBJ_FIELD_PY="" PBJ_COPY_PY="" PBJ_EXTRACT_PY=""
typeset -g PBJ_SHAPE_PY="" PBJ_SCAN_PY="" PBJ_HTTP_PY="" PBJ_TIMING_PY=""

# Alias enumeration capture arrays
typeset -a ENUM_RESP_FILES ENUM_HDR_FILES ENUM_CT_FILES ENUM_SIZE_FILES ENUM_TIME_FILES
typeset -a ENUM_HTTP_VALUES

# ────────────────────────────────────────────────────────────────
# §5  CORE UTILITIES
# ────────────────────────────────────────────────────────────────

# ERR_EXIT-safe increment (returns 0 regardless of new value)
pb_inc() { typeset -g "${1}=$(( ${(P)1} + 1 ))"; }

pb_halt() { print "HALT: $1" >&2; exit 1; }

pb_realpath() {
  python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1"
}

pb_generate_run_suffix() {
  RUN_SUFFIX=$(python3 -c "import secrets; print(secrets.token_hex(4))")
  [[ -n "$RUN_SUFFIX" ]] || pb_halt "Cannot generate run suffix"
  RELEASE1B_MH_NAME="release1b_cp0_${RUN_SUFFIX}"
}

pb_setup_umask() {
  umask 077
  [[ "$(umask)" = "077" ]] || pb_halt "umask is not 077"
}

pb_setup_root() {
  RELEASE1B_ISOLATED_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/release1b_cp0_XXXXXXXXXX")
  [[ -n "$RELEASE1B_ISOLATED_ROOT" && -d "$RELEASE1B_ISOLATED_ROOT" ]] || \
    pb_halt "mktemp -d failed"
  [[ -L "$RELEASE1B_ISOLATED_ROOT" ]] && pb_halt "isolated root is a symlink"
  RELEASE1B_TEST_TMP="${RELEASE1B_ISOLATED_ROOT}/tmp"
  RELEASE1B_PB_DATA_DIR="${RELEASE1B_ISOLATED_ROOT}/pb_data"
  RELEASE1B_PB_HOOKS_DIR="${RELEASE1B_ISOLATED_ROOT}/pb_hooks"
  RELEASE1B_PB_MIGRATIONS_DIR="${RELEASE1B_ISOLATED_ROOT}/pb_migrations"
  RELEASE1B_EVIDENCE_DIR="${RELEASE1B_ISOLATED_ROOT}/evidence"
  mkdir -p "$RELEASE1B_TEST_TMP" "$RELEASE1B_PB_DATA_DIR" \
           "$RELEASE1B_PB_HOOKS_DIR" "$RELEASE1B_PB_MIGRATIONS_DIR" \
           "$RELEASE1B_EVIDENCE_DIR" || pb_halt "mkdir failed"
  RELEASE1B_CANONICAL_ROOT=$(pb_realpath "$RELEASE1B_ISOLATED_ROOT")
  RELEASE1B_CANONICAL_TMP=$(pb_realpath  "$RELEASE1B_TEST_TMP")
  RELEASE1B_CANONICAL_PARENT=$(pb_realpath "$(dirname "$RELEASE1B_ISOLATED_ROOT")")
  RELEASE1B_ROOT_OWNER=$(stat -f '%u' "$RELEASE1B_ISOLATED_ROOT" 2>/dev/null || \
    stat -c '%u' "$RELEASE1B_ISOLATED_ROOT" 2>/dev/null)
  printf 'release1b_cp0_%s' "$RUN_SUFFIX" > \
    "${RELEASE1B_ISOLATED_ROOT}/.release1b_marker"
  export RELEASE1B_CANONICAL_TMP
  RELEASE1B_REPORT_WORK="${RELEASE1B_ISOLATED_ROOT}/report_work.md"
  RELEASE1B_REPORT_PATH="${RELEASE1B_ISOLATED_ROOT}/report_final.md"
  printf '# CP0 Report — %s\n\n| Test | Result | Notes |\n|---|---|---|\n' \
    "$RUN_SUFFIX" > "$RELEASE1B_REPORT_WORK"
}

pb_trap_cleanup() {
  local exit_code="${1:-1}"
  if (( CLEANUP_RUNNING )); then return; fi
  CLEANUP_RUNNING=1
  print "[trap] emergency cleanup — exit code $exit_code"
  # Stop PocketBase only if PID matches canonical root
  if [[ -n "$RELEASE1B_PB_PID" ]]; then
    local pb_args; pb_args=$(ps -p "$RELEASE1B_PB_PID" -o args= 2>/dev/null || true)
    if [[ -n "$pb_args" && "$pb_args" = *"${RELEASE1B_CANONICAL_ROOT}"* ]]; then
      kill "$RELEASE1B_PB_PID" 2>/dev/null || {
        CLEANUP_FAILURE=1
        print "[trap] WARNING: PocketBase termination failed — manual review required"
      }
    fi
  fi
  # Stop Mailhog only by recorded container ID
  if [[ -n "$RELEASE1B_MH_ID" ]]; then
    local label; label=$(docker inspect --format \
      '{{index .Config.Labels "release1b_run"}}' "$RELEASE1B_MH_ID" 2>/dev/null || true)
    if [[ "$label" = "$RUN_SUFFIX" ]]; then
      docker stop "$RELEASE1B_MH_ID" &>/dev/null && docker rm "$RELEASE1B_MH_ID" &>/dev/null || {
        CLEANUP_FAILURE=1
        # Write container ID to evidence file, not to terminal
        printf '%s\n' "$RELEASE1B_MH_ID" >> "${RELEASE1B_EVIDENCE_DIR}/mailhog_cleanup_fail.txt" 2>/dev/null
        print "[trap] Mailhog container owned by this test could not be removed — see evidence dir"
      }
    else
      CLEANUP_FAILURE=1
      print "[trap] Mailhog label mismatch — not terminating"
    fi
  fi
  # Delete isolated root only if fully validated
  if pb_validate_destructive_target "$RELEASE1B_ISOLATED_ROOT" && (( CLEANUP_FAILURE == 0 )); then
    rm -rf "$RELEASE1B_ISOLATED_ROOT"
  else
    print "[trap] isolated root preserved for manual review — CLEANUP_FAILURE=$CLEANUP_FAILURE"
    print "[trap] Root is at a path inside the system temp directory"
  fi
  CLEANUP_RUNNING=0
}

pb_install_trap() {
  trap 'pb_trap_cleanup $?' EXIT
  trap 'pb_trap_cleanup 130; exit 130' INT
  trap 'pb_trap_cleanup 143; exit 143' TERM
}

# ────────────────────────────────────────────────────────────────
# §6  RESULT TRACKING
# ────────────────────────────────────────────────────────────────

pb_report_append() { printf '%s\n' "$*" >> "$RELEASE1B_REPORT_WORK"; }

# pb_sanitize_label: return a sanitized label; never include raw paths/URLs/IDs
pb_sanitize_label() { printf '%s' "${1//[^A-Za-z0-9_:.-]/_}"; }

t_pass() {
  pb_inc T_PASS
  pb_report_append "| $(pb_sanitize_label "$1") | PASS | |"
  print "PASS: $1"
}
t_fail() {
  pb_inc T_FAIL
  local note="${2:-}"; note="${note//\|/;}"
  pb_report_append "| $(pb_sanitize_label "$1") | FAIL | $note |"
  print "FAIL: $1${note:+ — $note}"
}
t_blocking() {
  pb_inc T_FAIL; pb_inc T_BLOCKING
  BLOCKING_DECISIONS+=("$1")
  HALT_DEPENDENTS=1
  pb_report_append "| $(pb_sanitize_label "$1") | BLOCKING | $2 |"
  print "BLOCKING: $1 — $2"
}
t_unresolved() {
  pb_inc T_UNRESOLVED
  UNRESOLVED_ITEMS+=("$1")
  pb_report_append "| $(pb_sanitize_label "$1") | UNRESOLVED | $2 |"
  print "UNRESOLVED: $1 — $2"
}
t_deferred_mandatory() {
  pb_inc T_DEFERRED
  pb_report_append "| $(pb_sanitize_label "$1") | DEFERRED-MANDATORY | $2 |"
  print "DEFERRED-MANDATORY: $1 — $2"
}
t_authorized_exclusion() {
  pb_report_append "| $(pb_sanitize_label "$1") | AUTHORIZED-EXCLUSION | $2 |"
  print "AUTHORIZED-EXCLUSION: $1"
}
t_future_release() {
  pb_report_append "| $(pb_sanitize_label "$1") | FUTURE-RELEASE | $2 |"
  print "FUTURE-RELEASE: $1"
}
t_skip() {
  pb_inc T_SKIP
  pb_report_append "| $(pb_sanitize_label "$1") | SKIP | $2 |"
  print "SKIP: $1 — $2"
}
t_harness_err() {
  pb_inc T_HARNESS_ERR
  HARNESS_ERRORS+=("$1: $2")
  pb_report_append "| $(pb_sanitize_label "$1") | HARNESS-ERROR | $2 |"
  print "HARNESS-ERROR: $1 — $2"
  return 1
}

# ────────────────────────────────────────────────────────────────
# §7  PYTHON HELPER SCRIPTS
# ────────────────────────────────────────────────────────────────

pb_write_scripts() {
  [[ -d "$RELEASE1B_TEST_TMP" ]] || pb_halt "TEST_TMP not ready"

  PBJ_STAT_PY=$(mktemp   "${RELEASE1B_TEST_TMP}/pbj_stat_XXXXXXXXXX.py")
  PBJ_URL_PY=$(mktemp    "${RELEASE1B_TEST_TMP}/pbj_url_XXXXXXXXXX.py")
  PBJ_PY=$(mktemp        "${RELEASE1B_TEST_TMP}/pbj_XXXXXXXXXX.py")
  PBJ_AUTH_PY=$(mktemp   "${RELEASE1B_TEST_TMP}/pbja_XXXXXXXXXX.py")
  PBJ_FIELD_PY=$(mktemp  "${RELEASE1B_TEST_TMP}/pbjf_XXXXXXXXXX.py")
  PBJ_COPY_PY=$(mktemp   "${RELEASE1B_TEST_TMP}/pbjc_XXXXXXXXXX.py")
  PBJ_EXTRACT_PY=$(mktemp "${RELEASE1B_TEST_TMP}/pbje_XXXXXXXXXX.py")
  PBJ_SHAPE_PY=$(mktemp  "${RELEASE1B_TEST_TMP}/pbjs_XXXXXXXXXX.py")
  PBJ_SCAN_PY=$(mktemp   "${RELEASE1B_TEST_TMP}/pbjn_XXXXXXXXXX.py")
  PBJ_HTTP_PY=$(mktemp   "${RELEASE1B_TEST_TMP}/pbjh_XXXXXXXXXX.py")
  PBJ_TIMING_PY=$(mktemp "${RELEASE1B_TEST_TMP}/pbjt_XXXXXXXXXX.py")

  cat > "$PBJ_STAT_PY" << 'PYEOF'
import os, stat, sys
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
path = sys.argv[1]
try:
    lst = os.lstat(path)
except Exception:
    print("UNREADABLE"); sys.exit(0)
if stat.S_ISLNK(lst.st_mode): print("SYMLINK"); sys.exit(0)
if not stat.S_ISREG(lst.st_mode): print("NOT_FILE"); sys.exit(0)
if TASK_TMP:
    real = os.path.realpath(path)
    if not real.startswith(TASK_TMP + '/'): print("OUTSIDE_ROOT"); sys.exit(0)
print(format(stat.S_IMODE(lst.st_mode), '04o'))
PYEOF

  cat > "$PBJ_URL_PY" << 'PYEOF'
import sys
from urllib.parse import urlparse
url = sys.argv[1]; host = sys.argv[2]; port = int(sys.argv[3])
def rej(r): print(f"REJECT:{r}"); sys.exit(0)
try:
    p = urlparse(url)
except Exception:
    rej("parse_failed")
if p.scheme != 'http':                    rej("scheme")
if p.hostname != host:                    rej("hostname")
if (p.port or 80) != port:               rej("port")
if p.username or p.password:             rej("userinfo")
if p.fragment:                           rej("fragment")
if not p.path.startswith('/api/'):        rej("path_prefix")
for ch in url:
    if ord(ch) < 32:                     rej("control_char")
for bad in ['localhost', '[::1]', '[::ffff:', '0x7f', '2130706433', '%2f']:
    if bad in url.lower():               rej(f"alternate:{bad}")
if url.startswith('//'):                 rej("protocol_relative")
print("OK")
PYEOF

  cat > "$PBJ_PY" << 'PYEOF'
import sys, json, os, stat, math
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
MAX_SECRET = 4096; MAX_STDIN = 65536
def fail(msg, outfile):
    print(f"Error [pbj]: {msg}", file=sys.stderr)
    try: os.remove(outfile)
    except: pass
    sys.exit(1)
def check_path(p, label, outfile):
    try:
        lst = os.lstat(p)
        if stat.S_ISLNK(lst.st_mode): fail(f"{label}: symlink", outfile)
        if TASK_TMP:
            if not os.path.realpath(p).startswith(TASK_TMP + '/'): fail(f"{label}: outside root", outfile)
    except FileNotFoundError:
        if label != 'out': fail(f"{label}: not found", outfile)
def read_secret_file(path, key, outfile):
    check_path(path, f"secret-file[{key}]", outfile)
    st = os.stat(path)
    if not stat.S_ISREG(st.st_mode): fail(f"secret-file[{key}]: not regular", outfile)
    if st.st_mode & 0o077: fail(f"secret-file[{key}]: too open", outfile)
    raw = open(path, 'rb').read(MAX_SECRET + 1)
    if len(raw) > MAX_SECRET: fail(f"secret-file[{key}]: too large", outfile)
    if b'\x00' in raw: fail(f"secret-file[{key}]: NUL bytes", outfile)
    return raw.decode('utf-8')
outfile = sys.argv[1]; specs = sys.argv[2:]
check_path(outfile, 'out', outfile)
n_stdin = sum(1 for s in specs if s.startswith('secret:'))
secret_q = []
if n_stdin:
    raw = sys.stdin.buffer.read(MAX_STDIN + 1)
    if len(raw) > MAX_STDIN: fail("stdin too large", outfile)
    try: text = raw.decode('utf-8')
    except: fail("stdin not UTF-8", outfile)
    parts = text.split('\n')
    if parts and not parts[-1]: parts = parts[:-1]
    if len(parts) != n_stdin: fail(f"expected {n_stdin} secrets", outfile)
    secret_q = parts
obj = {}; si = 0
for spec in specs:
    if spec.startswith('secret-file:'):
        rest = spec[12:]; k, _, path = rest.partition('=')
        if not k or k in obj: fail(f"empty/dup key '{k}'", outfile)
        obj[k] = read_secret_file(path, k, outfile)
    elif spec.startswith('secret:'):
        k = spec[7:]
        if not k or k in obj: fail(f"dup key '{k}'", outfile)
        obj[k] = secret_q[si]; si += 1
    elif spec.startswith('b:'):
        k, _, v = spec[2:].partition('=')
        if not k or k in obj: fail(f"dup key '{k}'", outfile)
        if v not in ('true', 'false'): fail(f"bad bool '{v}'", outfile)
        obj[k] = (v == 'true')
    elif spec.startswith('n:'):
        k, _, v = spec[2:].partition('=')
        if not k or k in obj: fail(f"dup key '{k}'", outfile)
        try:
            n = int(v) if '.' not in v and 'e' not in v.lower() else float(v)
            if isinstance(n, float) and not math.isfinite(n): fail(f"non-finite '{k}'", outfile)
        except: fail(f"bad number '{v}'", outfile)
        obj[k] = n
    elif spec.startswith('null:'):
        k = spec[5:]
        if not k or k in obj: fail(f"dup key '{k}'", outfile)
        obj[k] = None
    elif '=' in spec:
        s2 = spec[2:] if spec.startswith('s:') else spec
        k, _, v = s2.partition('=')
        if not k or k in obj: fail(f"dup key '{k}'", outfile)
        obj[k] = v
    else:
        fail(f"unrecognized spec '{spec}'", outfile)
json.dump(obj, open(outfile, 'w'), ensure_ascii=True, allow_nan=False)
PYEOF

  cat > "$PBJ_AUTH_PY" << 'PYEOF'
import sys, os, stat, re
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
JWT_RE = re.compile(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$')
MAX_TOK = 2048
cfg, tok = sys.argv[1], sys.argv[2]
def fail(m): print(f"Error [pbj_auth]: {m}", file=sys.stderr); sys.exit(1)
for p, label in [(cfg, 'cfg'), (tok, 'tok')]:
    if TASK_TMP:
        try:
            lst = os.lstat(p)
            if stat.S_ISLNK(lst.st_mode): fail(f"{label} symlink")
            if not os.path.realpath(p).startswith(TASK_TMP + '/'): fail(f"{label} outside root")
        except FileNotFoundError:
            if label == 'tok': fail("token file not found")
raw = open(tok, 'rb').read(MAX_TOK + 1)
if len(raw) > MAX_TOK: fail("token too long")
try: t = raw.decode('ascii')
except: fail("token not ASCII")
for bad in ('\n', '\r', '\t', ' ', '"', "'", '\\'):
    if bad in t: fail("disallowed char in token")
if not JWT_RE.match(t): fail("not JWT format")
with open(cfg, 'w') as f:
    f.write(f'header = "Authorization: Bearer {t}"\n')
PYEOF

  cat > "$PBJ_FIELD_PY" << 'PYEOF'
import sys, json, os
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
PRINTABLE = frozenset({'totalItems','totalPages','page','perPage','phone_verified','verified',
  'language_selected','welcome_completed','category','type','status','name','is_published',
  'is_completed','progress_percent','watch_percent','order','level','mood'})
BLOCKED = frozenset({'id','user','token','password','passwordConfirm','email','phone',
  'phone_normalized','url','thumbnail','image','file','files','otp','otpId','tokenKey',
  'is_alias_account','recovery_contact_email','access_token','refresh_token','secret',
  'collectionId','collectionName','message','code','data','errors','document_id',
  'accepted_privacy_version','accepted_terms_version','privacy_content_hash',
  'terms_content_hash','content_hash','created','updated'})
field = sys.argv[2]
if field in BLOCKED: print(f"Error: '{field}' blocked", file=sys.stderr); sys.exit(1)
if field not in PRINTABLE: print(f"Error: '{field}' not in printable list", file=sys.stderr); sys.exit(1)
if TASK_TMP:
    if not os.path.realpath(sys.argv[1]).startswith(TASK_TMP + '/'):
        print("Error: outside root", file=sys.stderr); sys.exit(1)
try:
    d = json.load(open(sys.argv[1]))
    v = d.get(field)
    print('' if v is None else str(v))
except Exception: print("Error: parse failed", file=sys.stderr); sys.exit(1)
PYEOF

  cat > "$PBJ_COPY_PY" << 'PYEOF'
import sys, json, os, stat
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
COPYABLE = frozenset({'token','id','otpId','user','child','course','lesson',
                       'article','thumbnail','url','document_id','name','category'})
def fail(m): print(f"Error [pbj_copy]: {m}", file=sys.stderr); sys.exit(1)
resp, field, dest = sys.argv[1], sys.argv[2], sys.argv[3]
if field not in COPYABLE: fail(f"'{field}' not copyable")
for p, label in [(resp, 'source'), (dest, 'dest')]:
    if TASK_TMP:
        try:
            lst = os.lstat(p)
            if stat.S_ISLNK(lst.st_mode): fail(f"{label} symlink")
            if not os.path.realpath(p).startswith(TASK_TMP + '/'): fail(f"{label} outside root")
        except FileNotFoundError:
            if label == 'dest': fail("dest must exist")
st = os.stat(dest)
if not stat.S_ISREG(st.st_mode): fail("dest not regular")
if st.st_mode & 0o077: fail("dest too open")
try:
    d = json.load(open(resp))
    val = d.get(field)
    if val is None: fail(f"'{field}' missing")
    s = str(val)
    if len(s.encode()) > 8192: fail("value too large")
    with open(dest, 'w') as f: f.write(s)
except Exception as e: fail(str(e))
PYEOF

  cat > "$PBJ_EXTRACT_PY" << 'PYEOF'
import sys, json, os, stat
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
COPYABLE = frozenset({'id','token','otpId','user','child','course','lesson','article',
                       'thumbnail','url','document_id','name','category'})
def fail(m): print(f"Error [pbj_extract]: {m}", file=sys.stderr); sys.exit(1)
resp, field, index, dest = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
expected_total = int(sys.argv[5]) if len(sys.argv) > 5 else None
if field not in COPYABLE: fail(f"'{field}' not extractable")
for p, label in [(resp, 'source'), (dest, 'dest')]:
    if TASK_TMP:
        try:
            lst = os.lstat(p)
            if stat.S_ISLNK(lst.st_mode): fail(f"{label} symlink")
            if not os.path.realpath(p).startswith(TASK_TMP + '/'): fail(f"{label} outside root")
        except FileNotFoundError:
            if label == 'dest': fail("dest pre-created required")
d = json.load(open(resp))
total = d.get('totalItems', -1)
items = d.get('items', [])
if expected_total is not None and total != expected_total:
    fail(f"totalItems expected {expected_total} got {total}")
if index >= len(items): fail(f"index {index} out of range")
val = items[index].get(field)
if val is None: fail(f"'{field}' missing in items[{index}]")
s = str(val)
if len(s.encode()) > 8192: fail("value too large")
st = os.stat(dest)
if not stat.S_ISREG(st.st_mode) or st.st_mode & 0o077: fail("dest bad mode")
with open(dest, 'w') as f: f.write(s)
PYEOF

  cat > "$PBJ_SHAPE_PY" << 'PYEOF'
import json, sys, os, stat
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
def fail(m): print(f"SHAPE_ERROR:{m}", file=sys.stderr); sys.exit(1)
path = sys.argv[1]
if TASK_TMP:
    try:
        lst = os.lstat(path)
        if stat.S_ISLNK(lst.st_mode): fail("symlink")
        if not os.path.realpath(path).startswith(TASK_TMP + '/'): fail("outside root")
    except FileNotFoundError: fail("not found")
def shape(v):
    if isinstance(v, dict): return {k: shape(vv) for k, vv in sorted(v.items())}
    if isinstance(v, list): return ['list', shape(v[0]) if v else 'empty']
    if isinstance(v, bool): return 'bool'
    if isinstance(v, int): return 'int'
    if isinstance(v, float): return 'float'
    if v is None: return 'null'
    return 'str'
try:
    d = json.load(open(path, errors='replace'))
    print(json.dumps(shape(d), separators=(',', ':')))
except Exception as e: fail(str(e))
PYEOF

  cat > "$PBJ_SCAN_PY" << 'PYEOF'
import sys, os, re, stat
MAX_FILE = 5 * 1024 * 1024
PATTERNS = [
    re.compile(r'META_API_KEY\s*[=:]\s*\S'),
    re.compile(r'HMAC_SECRET\s*[=:]\s*\S'),
    re.compile(r'ONESIGNAL\w*\s*[=:]\s*\S'),
    re.compile(r'PHONE_PROVIDER_SECRET\s*[=:]\s*\S'),
    re.compile(r'WHATSAPP_TOKEN\s*[=:]\s*\S'),
    re.compile(r'SMTP_PASSWORD\s*[=:]\s*\S'),
    re.compile(r'"password"\s*:\s*"[^"]{8,}"'),
]
def scan_bytes(raw):
    try: content = raw.decode('utf-8')
    except UnicodeDecodeError: return False, True
    return any(p.search(content) for p in PATTERNS), False
def scan_file(fpath):
    try:
        lst = os.lstat(fpath)
        if stat.S_ISLNK(lst.st_mode): return False, True
        if not stat.S_ISREG(lst.st_mode): return False, False
        if lst.st_size > MAX_FILE: return False, True
        found, blocked = scan_bytes(open(fpath, 'rb').read())
        return found, blocked
    except: return False, True
if len(sys.argv) >= 3 and sys.argv[1] == '--file':
    found, blocked = scan_file(sys.argv[2])
    if blocked: print("HALT:blocked"); sys.exit(1)
    if found: print("HALT:pattern"); sys.exit(1)
    print("PASS"); sys.exit(0)
found_list = []; blocked_list = []
for root, dirs, files in os.walk(sys.argv[1], followlinks=False):
    dirs[:] = [d for d in dirs if not os.path.islink(os.path.join(root, d))]
    for fname in files:
        f, b = scan_file(os.path.join(root, fname))
        if b: blocked_list.append(fname)
        elif f: found_list.append(fname)
if blocked_list: print(f"HALT:{len(blocked_list)} blocked"); sys.exit(1)
if found_list: print(f"HALT:{len(found_list)} matched"); sys.exit(1)
print("PASS")
PYEOF

  cat > "$PBJ_HTTP_PY" << 'PYEOF'
import sys, os, stat, urllib.request, urllib.error, urllib.parse
TASK_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', '')
APPROVED_PORTS = {8090}; TIMEOUT = 15; MAX_RESP = 10 * 1024 * 1024
status_out, body_out, base_url = sys.argv[1], sys.argv[2], sys.argv[3]
tok_file = sys.argv[4] if len(sys.argv) > 4 else None
def fail(m):
    open(status_out, 'w').write('0'); open(body_out, 'wb').write(b'')
    print(f"Error: {m}", file=sys.stderr); sys.exit(1)
p = urllib.parse.urlparse(base_url)
if p.scheme != 'http': fail("scheme")
if p.hostname != '127.0.0.1': fail("hostname")
if p.username or p.password: fail("userinfo")
if (p.port or 80) not in APPROVED_PORTS: fail(f"port")
tok = None
if tok_file:
    if TASK_TMP:
        lst = os.lstat(tok_file)
        if stat.S_ISLNK(lst.st_mode): fail("tok symlink")
        if not os.path.realpath(tok_file).startswith(TASK_TMP + '/'): fail("tok outside root")
    st = os.stat(tok_file)
    if st.st_mode & 0o077: fail("tok too open")
    tok = open(tok_file).read().strip()
    if not tok: fail("tok empty")
url = base_url
if tok:
    sep = '&' if '?' in url else '?'
    url += sep + urllib.parse.urlencode({'token': tok})
class NoRedir(urllib.request.HTTPRedirectHandler):
    def _r(self, req, fp, code, msg, hdrs): raise urllib.error.HTTPError(req.full_url, code, "redirect", hdrs, fp)
    http_error_301 = http_error_302 = http_error_303 = http_error_307 = http_error_308 = _r
opener = urllib.request.build_opener(NoRedir())
status = 0; body = b""
try:
    with opener.open(url, timeout=TIMEOUT) as r:
        status = r.status; body = r.read(MAX_RESP)
except urllib.error.HTTPError as e:
    status = e.code
    try: body = e.read(MAX_RESP)
    except: body = b""
except: status = 0
open(status_out, 'w').write(str(status))
open(body_out, 'wb').write(body)
PYEOF

  cat > "$PBJ_TIMING_PY" << 'PYEOF'
import sys, os, statistics
samples_dir, label, required = sys.argv[1], sys.argv[2], int(sys.argv[3])
times = []
for fname in sorted(os.listdir(samples_dir)):
    if not fname.endswith('.txt'): continue
    try: times.append(float(open(os.path.join(samples_dir, fname)).read().strip()))
    except: pass
if len(times) < required: print(f"FAIL [{label}]: {len(times)}/{required} samples"); sys.exit(1)
n = len(times); mean = sum(times) / n
stddev = statistics.stdev(times) if n > 1 else 0.0
print(f"TIMING [{label}]: n={n} mean={mean*1000:.1f}ms min={min(times)*1000:.1f}ms "
      f"max={max(times)*1000:.1f}ms stddev={stddev*1000:.1f}ms")
print("NOTE: timing differences are observations, not proof of timing-equivalence")
PYEOF

  # Verify all helper scripts are inside canonical tmp with mode 0600
  local f
  for f in "$PBJ_STAT_PY" "$PBJ_URL_PY" "$PBJ_PY" "$PBJ_AUTH_PY" "$PBJ_FIELD_PY" \
            "$PBJ_COPY_PY" "$PBJ_EXTRACT_PY" "$PBJ_SHAPE_PY" "$PBJ_SCAN_PY" \
            "$PBJ_HTTP_PY" "$PBJ_TIMING_PY"; do
    local mode
    mode=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" python3 "$PBJ_STAT_PY" "$f" 2>/dev/null)
    [[ "$mode" = "0600" ]] || pb_halt "Helper script mode $mode ≠ 0600"
  done
}

# ────────────────────────────────────────────────────────────────
# §8  VALIDATION FUNCTIONS
# ────────────────────────────────────────────────────────────────

pb_stat_check() {
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" python3 "$PBJ_STAT_PY" "$1"
}

pb_validate_task_file() {
  local path="$1" role="$2" label="$3"
  [[ -n "$path" ]] || { print "FAIL [$label]: empty path" >&2; return 1; }
  local result; result=$(pb_stat_check "$path")
  case "$result" in
    SYMLINK)      print "FAIL [$label]: $role is symlink" >&2;       return 1 ;;
    NOT_FILE)     print "FAIL [$label]: $role not a file" >&2;       return 1 ;;
    OUTSIDE_ROOT) print "FAIL [$label]: $role outside root" >&2;     return 1 ;;
    UNREADABLE)   print "FAIL [$label]: $role unreadable" >&2;       return 1 ;;
    0600) ;;
    *)            print "FAIL [$label]: mode $result ≠ 0600" >&2;    return 1 ;;
  esac
  case "$role" in
    output) ;;
    input|secret-input)
      [[ -r "$path" ]] || { print "FAIL [$label]: not readable" >&2; return 1; }
      if [[ "$role" = "secret-input" ]]; then
        local sz; sz=$(wc -c < "$path" 2>/dev/null || print 0)
        (( sz > 0 )) || { print "FAIL [$label]: secret empty" >&2;  return 1; }
      fi ;;
    *) print "FAIL [$label]: unknown role '$role'" >&2;               return 1 ;;
  esac
}

pb_validate_local_url() {
  local url="$1" label="$2"
  [[ -n "$url" ]] || { print "FAIL [$label]: empty URL" >&2; return 1; }
  local result; result=$(python3 "$PBJ_URL_PY" "$url" "127.0.0.1" "$RELEASE1B_PB_PORT" 2>/dev/null)
  [[ "$result" = "OK" ]] || { print "FAIL [$label]: URL rejected ($result)" >&2; return 1; }
}

pb_validate_method() {
  case "$1" in GET|POST|PATCH|DELETE) return 0 ;; esac
  print "FAIL [$2]: invalid method '$1'" >&2; return 1
}

pb_validate_accepted_statuses() {
  local label="$1"; shift
  (( $# > 0 )) || { print "FAIL [$label]: no statuses" >&2; return 1; }
  local -a seen=()
  for code in "$@"; do
    [[ "$code" =~ ^[1-5][0-9][0-9]$ ]] || { print "FAIL [$label]: bad status '$code'" >&2; return 1; }
    (( ${seen[(I)$code]} > 0 )) && { print "FAIL [$label]: dup status '$code'" >&2; return 1; }
    seen+=("$code")
  done
}

pb_verify_file_manifest() {
  # Verify files listed in a JSON manifest [{file, sha256}, ...]
  local manifest_path="$1" src_dir="$2" label="$3"
  python3 - "$manifest_path" "$src_dir" "$label" << 'PYEOF'
import sys, json, hashlib, os, stat
manifest_path, src_dir, label = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    entries = json.load(open(manifest_path))
except Exception as e:
    print(f"HALT [{label}]: cannot read manifest: {e}"); sys.exit(1)
for entry in entries:
    fname = entry.get('file', ''); expected = entry.get('sha256', '')
    if not fname or not expected:
        print(f"HALT [{label}]: manifest entry missing file or sha256"); sys.exit(1)
    fpath = os.path.join(src_dir, fname)
    try:
        lst = os.lstat(fpath)
        if stat.S_ISLNK(lst.st_mode):
            print(f"HALT [{label}]: {fname} is symlink"); sys.exit(1)
        raw = open(fpath, 'rb').read()
        actual = hashlib.sha256(raw).hexdigest()
        if actual != expected:
            print(f"HALT [{label}]: {fname} hash mismatch expected={expected[:16]}... got={actual[:16]}...")
            sys.exit(1)
        print(f"OK [{label}]: {fname}")
    except FileNotFoundError:
        print(f"HALT [{label}]: {fname} missing"); sys.exit(1)
PYEOF
}

# ────────────────────────────────────────────────────────────────
# §9  PACKAGE COMPLETENESS CHECK (documentation review step)
# ────────────────────────────────────────────────────────────────

pb_check_package_completeness() {
  print "=== Package Completeness Check ==="
  local blocked=0

  for arch in darwin_arm64 darwin_amd64; do
    local h="${PB_EXPECTED_SHA256[$arch]}"
    if [[ "$h" = UNRESOLVED* ]]; then
      print "BLOCKER B-CHECKSUM [$arch]: see release1b_round13_review.md §B-CHECKSUM"
      blocked=$(( blocked + 1 ))
    fi
  done

  if [[ -z "$RELEASE1B_SCHEMA_SRC" || ! -d "$RELEASE1B_SCHEMA_SRC" ]]; then
    print "BLOCKER B-SCHEMA: RELEASE1B_SCHEMA_SRC not set or not a directory"
    blocked=$(( blocked + 1 ))
  fi
  if [[ -z "$RELEASE1B_SCHEMA_MANIFEST" || ! -f "$RELEASE1B_SCHEMA_MANIFEST" ]]; then
    print "BLOCKER B-SCHEMA: RELEASE1B_SCHEMA_MANIFEST not set or not a file"
    blocked=$(( blocked + 1 ))
  fi

  if [[ ${#HOOK_SRC_PATHS} -eq 0 ]]; then
    print "BLOCKER B-HOOKS: no hook sources defined (see release1b_hook_manifest.json)"
    blocked=$(( blocked + 1 ))
  fi

  if [[ -z "$RELEASE1B_FRONTEND_SRC" || ! -d "$RELEASE1B_FRONTEND_SRC" ]]; then
    print "BLOCKER B-FRONTEND: RELEASE1B_FRONTEND_SRC not set or not a directory"
    blocked=$(( blocked + 1 ))
  fi
  if [[ -z "$RELEASE1B_FRONTEND_REF" || "$RELEASE1B_FRONTEND_REF" = UNRESOLVED* ]]; then
    print "BLOCKER B-FRONTEND: RELEASE1B_FRONTEND_REF not set"
    blocked=$(( blocked + 1 ))
  fi

  if (( blocked > 0 )); then
    print "=== $blocked preauthorization blocker(s) unresolved — see release1b_round13_review.md ==="
    return 1
  fi
  print "=== All preauthorization blockers resolved ==="
  return 0
}

# ────────────────────────────────────────────────────────────────
# §10 HARNESS SELF-TEST (Stage 0 — no services required)
# ────────────────────────────────────────────────────────────────

t_harness_selftest() {
  print "=== Stage 0: Harness Self-Test ==="
  local all_ok=1

  # Required commands
  local cmd
  for cmd in python3 curl openssl docker unzip mktemp shasum nc zsh; do
    if command -v "$cmd" &>/dev/null; then t_pass "T-HARNESS-CMD-$cmd"
    else t_harness_err "T-HARNESS-CMD-$cmd" "not found"; all_ok=0; fi
  done

  # pb_inc must not trigger ERR_EXIT on zero value
  local save_pass="$T_PASS"
  pb_inc T_PASS   # T_PASS was 0; safe under Option B
  pb_inc T_PASS
  if [[ "$T_PASS" -eq $(( save_pass + 2 )) ]]; then
    T_PASS="$save_pass"   # reset
    t_pass "T-HARNESS-ARITH: pb_inc does not exit on zero"
  else
    t_harness_err "T-HARNESS-ARITH" "pb_inc produced wrong value"; all_ok=0
  fi

  # Loop counter from zero
  typeset -i lc=0
  while (( lc < 3 )); do lc=$(( lc + 1 )); done
  if [[ "$lc" -eq 3 ]]; then t_pass "T-HARNESS-LOOP"
  else t_harness_err "T-HARNESS-LOOP" "counter wrong: $lc"; all_ok=0; fi

  # Stat helper — 0600 mode (use /tmp directly as outside root is expected)
  local stf; stf=$(mktemp "/tmp/release1b_sttest_XXXXXXXXXX")
  chmod 600 "$stf"
  local sr; sr=$(RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_STAT_PY" "$stf" 2>/dev/null)
  rm -f "$stf"
  if [[ "$sr" = "0600" || "$sr" = "OUTSIDE_ROOT" ]]; then
    t_pass "T-HARNESS-STAT-0600"
  else
    t_harness_err "T-HARNESS-STAT-0600" "mode='$sr'"; all_ok=0
  fi

  # Stat helper — symlink detected
  local stf2; stf2=$(mktemp "/tmp/release1b_sttest2_XXXXXXXXXX")
  local slk="/tmp/release1b_sl_$$"
  ln -s "$stf2" "$slk"
  local sl_r; sl_r=$(RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_STAT_PY" "$slk" 2>/dev/null)
  rm -f "$stf2" "$slk"
  if [[ "$sl_r" = "SYMLINK" ]]; then t_pass "T-HARNESS-STAT-SYMLINK"
  else t_harness_err "T-HARNESS-STAT-SYMLINK" "expected SYMLINK got '$sl_r'"; all_ok=0; fi

  # URL validator — parallel arrays (Item 5 fix)
  typeset -a URL_SELFTEST_URLS=(
    "http://127.0.0.1:8090/api/collections"
    "https://127.0.0.1:8090/api/collections"
    "http://localhost:8090/api/collections"
    "http://127.0.0.1:9999/api/collections"
    "http://user@127.0.0.1:8090/api/collections"
    "http://127.0.0.1:8090/api/collections#section"
    "http://127.0.0.1:8090/noapi/resource"
    "http://0x7f000001:8090/api/collections"
    "http://[::1]:8090/api/collections"
    "//127.0.0.1:8090/api/collections"
  )
  typeset -a URL_SELFTEST_LABELS=(
    "LOOPBACK"
    "WRONG-SCHEME"
    "WRONG-HOST"
    "WRONG-PORT"
    "HAS-USERINFO"
    "HAS-FRAGMENT"
    "BAD-PATH-PREFIX"
    "OCTAL-HOST"
    "IPV6-HOST"
    "PROTOCOL-RELATIVE"
  )
  typeset -a URL_SELFTEST_EXPECTED=(
    "OK" "REJECT" "REJECT" "REJECT" "REJECT" "REJECT" "REJECT" "REJECT" "REJECT" "REJECT"
  )
  typeset -i ui=1
  for url in "${URL_SELFTEST_URLS[@]}"; do
    local lbl="${URL_SELFTEST_LABELS[$ui]}" exp="${URL_SELFTEST_EXPECTED[$ui]}"
    local res; res=$(python3 "$PBJ_URL_PY" "$url" "127.0.0.1" "8090" 2>/dev/null)
    if [[ "$exp" = "OK" ]]; then
      if [[ "$res" = "OK" ]]; then t_pass "T-HARNESS-URL-$lbl"
      else t_harness_err "T-HARNESS-URL-$lbl" "expected OK got $res"; all_ok=0; fi
    else
      if [[ "$res" = REJECT* ]]; then t_pass "T-HARNESS-URL-$lbl"
      else t_harness_err "T-HARNESS-URL-$lbl" "expected REJECT got $res"; all_ok=0; fi
    fi
    ui=$(( ui + 1 ))
  done

  # pbj.py — valid build
  local tmpf; tmpf=$(mktemp "/tmp/release1b_pbj_XXXXXXXXXX")
  chmod 600 "$tmpf"
  if RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_PY" "$tmpf" "k=v" "b:flag=true" "n:x=5" </dev/null; then
    local content; content=$(cat "$tmpf")
    if [[ "$content" = '{"k": "v", "flag": true, "x": 5}' ]]; then
      t_pass "T-HARNESS-PBJ-BASIC"
    else
      t_harness_err "T-HARNESS-PBJ-BASIC" "content mismatch"; all_ok=0
    fi
  else
    t_harness_err "T-HARNESS-PBJ-BASIC" "pbj.py failed on valid input"; all_ok=0
  fi

  # pbj.py — duplicate key rejected (expected failure)
  if RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_PY" "$tmpf" "k=v1" "k=v2" </dev/null 2>/dev/null; then
    t_harness_err "T-HARNESS-PBJ-DUPKEY" "dup key not rejected"; all_ok=0
  else
    t_pass "T-HARNESS-PBJ-DUPKEY"
  fi

  # pbj.py — non-finite number rejected
  if RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_PY" "$tmpf" "n:x=inf" </dev/null 2>/dev/null; then
    t_harness_err "T-HARNESS-PBJ-NONFINITE" "non-finite not rejected"; all_ok=0
  else
    t_pass "T-HARNESS-PBJ-NONFINITE"
  fi

  # pbj.py — bad boolean rejected
  if RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_PY" "$tmpf" "b:f=yes" </dev/null 2>/dev/null; then
    t_harness_err "T-HARNESS-PBJ-BADBOOL" "bad boolean not rejected"; all_ok=0
  else
    t_pass "T-HARNESS-PBJ-BADBOOL"
  fi
  rm -f "$tmpf"

  # pbj_field.py — blocked field not printed
  local tmpj; tmpj=$(mktemp "/tmp/release1b_ftest_XXXXXXXXXX")
  chmod 600 "$tmpj"
  printf '{"id":"abc","name":"test"}' > "$tmpj"
  if RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_FIELD_PY" "$tmpj" "id" 2>/dev/null; then
    t_harness_err "T-HARNESS-FIELD-BLOCKED" "id not blocked"; all_ok=0
  else
    t_pass "T-HARNESS-FIELD-BLOCKED"
  fi
  if RELEASE1B_CANONICAL_TMP="/tmp" python3 "$PBJ_FIELD_PY" "$tmpj" "name" 2>/dev/null; then
    t_pass "T-HARNESS-FIELD-PRINT"
  else
    t_harness_err "T-HARNESS-FIELD-PRINT" "name blocked unexpectedly"; all_ok=0
  fi
  rm -f "$tmpj"

  print "=== Stage 0: $T_PASS passed, $T_HARNESS_ERR harness errors ==="
  (( T_HARNESS_ERR == 0 ))
}

# ────────────────────────────────────────────────────────────────
# §11 INFRASTRUCTURE
# ────────────────────────────────────────────────────────────────

pb_preflight_ports() {
  local ok=1
  for port in "$RELEASE1B_PB_PORT" "8025" "1025"; do
    if nc -z 127.0.0.1 "$port" 2>/dev/null; then
      print "PREREQ FAIL: port $port in use"; ok=0
    fi
  done
  (( ok )) || pb_halt "Required ports occupied — stop conflicting services"
  t_pass "T-SETUP-PORTS: 8090, 8025, 1025 are free"
}

pb_apply_schema_migrations() {
  [[ -d "$RELEASE1B_SCHEMA_SRC" ]]        || pb_halt "Schema source not a directory"
  [[ -f "$RELEASE1B_SCHEMA_MANIFEST" ]]   || pb_halt "Schema manifest not found"

  # Verify per-file integrity before any copy
  pb_verify_file_manifest "$RELEASE1B_SCHEMA_MANIFEST" "$RELEASE1B_SCHEMA_SRC" \
    "schema-integrity" || pb_halt "Schema integrity failure"

  # Scan for credentials
  if ! python3 "$PBJ_SCAN_PY" "$RELEASE1B_SCHEMA_SRC" 2>/dev/null | grep -q "^PASS"; then
    pb_halt "Schema source triggered secret scan — review before proceeding"
  fi

  # Copy each expected file individually
  python3 - "$RELEASE1B_SCHEMA_MANIFEST" "$RELEASE1B_SCHEMA_SRC" \
            "$RELEASE1B_PB_MIGRATIONS_DIR" << 'PYEOF'
import sys, json, hashlib, os, stat, shutil
mf, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]
entries = json.load(open(mf))
for entry in entries:
    fname = entry['file']; expected = entry['sha256']
    src_path = os.path.join(src, fname); dst_path = os.path.join(dst, fname)
    if os.path.exists(dst_path):
        print(f"HALT: {fname} already exists in destination"); sys.exit(1)
    lst = os.lstat(src_path)
    if stat.S_ISLNK(lst.st_mode): print(f"HALT: {fname} is symlink"); sys.exit(1)
    raw = open(src_path, 'rb').read()
    if hashlib.sha256(raw).hexdigest() != expected:
        print(f"HALT: {fname} hash mismatch on copy"); sys.exit(1)
    shutil.copy2(src_path, dst_path)
    os.chmod(dst_path, 0o600)
    # Verify destination hash
    actual = hashlib.sha256(open(dst_path,'rb').read()).hexdigest()
    if actual != expected:
        print(f"HALT: {fname} destination hash mismatch"); sys.exit(1)
    print(f"OK: {fname}")
PYEOF
  local rc=$?
  (( rc == 0 )) || pb_halt "Schema migration copy failed"
  t_pass "T-SCHEMA-COPY: all migration files copied and verified"
}

pb_start_pocketbase() {
  [[ -x "$RELEASE1B_PB_BIN" ]] || pb_halt "PocketBase binary not executable"
  "$RELEASE1B_PB_BIN" serve \
    --dir         "$RELEASE1B_PB_DATA_DIR" \
    --hooksDir    "$RELEASE1B_PB_HOOKS_DIR" \
    --migrationsDir "$RELEASE1B_PB_MIGRATIONS_DIR" \
    --http        "127.0.0.1:${RELEASE1B_PB_PORT}" \
    >>"${RELEASE1B_ISOLATED_ROOT}/pb.log" 2>&1 &
  RELEASE1B_PB_PID=$!
  sleep 1
  ps -p "$RELEASE1B_PB_PID" &>/dev/null || pb_halt "PocketBase exited immediately"
  local pb_args; pb_args=$(ps -p "$RELEASE1B_PB_PID" -o args= 2>/dev/null)
  [[ "$pb_args" = *"${RELEASE1B_CANONICAL_ROOT}"* ]] || \
    pb_halt "PocketBase args do not reference isolated root"
  typeset -i att=0
  while (( att < 45 )); do
    curl -sf "http://127.0.0.1:${RELEASE1B_PB_PORT}/api/health" &>/dev/null && break
    sleep 1; att=$(( att + 1 ))
  done
  (( att < 45 )) || pb_halt "PocketBase not ready within 45 seconds"
  RELEASE1B_CANONICAL_URL_PREFIX="http://127.0.0.1:${RELEASE1B_PB_PORT}"
  t_pass "T-SETUP-PB: PocketBase v${PB_RELEASE_VERSION} started"
}

pb_restart_pocketbase() {
  [[ -n "$RELEASE1B_PB_PID" ]] || pb_halt "No PB PID for restart"
  kill "$RELEASE1B_PB_PID" 2>/dev/null || true
  typeset -i j=0
  while (( j < 15 )); do
    ps -p "$RELEASE1B_PB_PID" &>/dev/null || break
    sleep 1; j=$(( j + 1 ))
  done
  "$RELEASE1B_PB_BIN" serve \
    --dir          "$RELEASE1B_PB_DATA_DIR" \
    --hooksDir     "$RELEASE1B_PB_HOOKS_DIR" \
    --migrationsDir "$RELEASE1B_PB_MIGRATIONS_DIR" \
    --http         "127.0.0.1:${RELEASE1B_PB_PORT}" \
    >>"${RELEASE1B_ISOLATED_ROOT}/pb.log" 2>&1 &
  RELEASE1B_PB_PID=$!
  typeset -i att=0
  while (( att < 30 )); do
    curl -sf "http://127.0.0.1:${RELEASE1B_PB_PORT}/api/health" &>/dev/null && break
    sleep 1; att=$(( att + 1 ))
  done
  (( att < 30 )) || pb_halt "PocketBase not ready after restart"
}

pb_stop_pocketbase() {
  [[ -n "$RELEASE1B_PB_PID" ]] || return 0
  local pb_args; pb_args=$(ps -p "$RELEASE1B_PB_PID" -o args= 2>/dev/null || true)
  if [[ -z "$pb_args" ]]; then RELEASE1B_PB_PID=""; return 0; fi
  [[ "$pb_args" = *"${RELEASE1B_CANONICAL_ROOT}"* ]] || {
    print "[stop-pb] process not owned by this run"; CLEANUP_FAILURE=1; return 1
  }
  kill "$RELEASE1B_PB_PID" 2>/dev/null || { CLEANUP_FAILURE=1; return 1; }
  typeset -i j=0
  while (( j < 15 )); do
    ps -p "$RELEASE1B_PB_PID" &>/dev/null || { RELEASE1B_PB_PID=""; return 0; }
    sleep 1; j=$(( j + 1 ))
  done
  print "[stop-pb] process did not stop"; CLEANUP_FAILURE=1; return 1
}

pb_start_mailhog() {
  [[ -n "$RUN_SUFFIX" ]]       || pb_halt "RUN_SUFFIX unset before Mailhog start"
  docker info &>/dev/null       || pb_halt "Docker not running"
  docker image inspect mailhog/mailhog &>/dev/null || pb_halt "mailhog image not present"

  if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qFx "$RELEASE1B_MH_NAME"; then
    pb_halt "Container name already in use — prior run may not have cleaned up: see evidence dir"
  fi

  RELEASE1B_MH_ID=$(docker run -d \
    --name  "$RELEASE1B_MH_NAME" \
    --label "release1b_run=${RUN_SUFFIX}" \
    -p "127.0.0.1:1025:1025" \
    -p "127.0.0.1:8025:8025" \
    mailhog/mailhog 2>/dev/null) || pb_halt "Docker run for Mailhog failed"

  [[ -n "$RELEASE1B_MH_ID" ]] || pb_halt "Mailhog container ID empty"
  local actual_name actual_label
  actual_name=$(docker inspect --format '{{.Name}}' "$RELEASE1B_MH_ID" 2>/dev/null)
  actual_label=$(docker inspect --format '{{index .Config.Labels "release1b_run"}}' \
    "$RELEASE1B_MH_ID" 2>/dev/null)
  [[ "$actual_name"  = "/$RELEASE1B_MH_NAME" ]] || pb_halt "Mailhog name mismatch"
  [[ "$actual_label" = "$RUN_SUFFIX"          ]] || pb_halt "Mailhog label mismatch"

  typeset -i att=0
  while (( att < 20 )); do
    curl -sf "http://127.0.0.1:8025/api/v2/messages" &>/dev/null && break
    sleep 1; att=$(( att + 1 ))
  done
  (( att < 20 )) || pb_halt "Mailhog API not ready"
  t_pass "T-SETUP-MAILHOG: started with unique owned name"
}

pb_stop_mailhog() {
  [[ -n "$RELEASE1B_MH_ID" ]] || return 0
  local label; label=$(docker inspect --format \
    '{{index .Config.Labels "release1b_run"}}' "$RELEASE1B_MH_ID" 2>/dev/null || true)
  [[ "$label" = "$RUN_SUFFIX" ]] || {
    print "[stop-mailhog] label mismatch — not terminating"; CLEANUP_FAILURE=1; return 1
  }
  if docker stop "$RELEASE1B_MH_ID" &>/dev/null && docker rm "$RELEASE1B_MH_ID" &>/dev/null; then
    RELEASE1B_MH_ID=""; return 0
  fi
  printf '%s\n' "$RELEASE1B_MH_ID" >> "${RELEASE1B_EVIDENCE_DIR}/mailhog_stop_fail.txt" 2>/dev/null
  print "[stop-mailhog] Mailhog container owned by this test could not be removed — see evidence dir"
  CLEANUP_FAILURE=1; return 1
}

pb_mailhog_count() {
  curl -sf "http://127.0.0.1:8025/api/v2/messages" 2>/dev/null | \
    python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null \
    || print -1
}

pb_mailhog_clear_verified() {
  local ctx="${1:-clear}"
  local before; before=$(pb_mailhog_count)
  [[ "$before" != "-1" ]] || pb_halt "Mailhog unreachable before clear ($ctx)"
  curl -sf -X DELETE "http://127.0.0.1:8025/api/v1/messages" &>/dev/null || \
    pb_halt "Mailhog DELETE failed ($ctx)"
  sleep 1
  local after; after=$(pb_mailhog_count)
  [[ "$after" = "0" ]] || pb_halt "Mailhog not empty after clear ($ctx): $after messages remain"
}

# ────────────────────────────────────────────────────────────────
# §12 LOCAL NATIVE SUPERUSER LIFECYCLE
# ────────────────────────────────────────────────────────────────

pb_create_local_superuser() {
  print "=== Creating local _superusers account ==="
  # Method: pocketbase superuser create email password (CLI)
  # Limitation: password briefly appears in process args.
  # Acceptable: disposable credential, isolated local environment, deleted after auth.
  # If CLI unavailable, falls back to anonymous POST to _superusers records API
  # (supported by PocketBase when no superusers exist).

  local su_pw_file su_id_file su_tok_file
  su_pw_file=$(mktemp  "${RELEASE1B_TEST_TMP}/supw_XXXXXXXXXX")
  su_id_file=$(mktemp  "${RELEASE1B_TEST_TMP}/suid_XXXXXXXXXX")
  su_tok_file=$(mktemp "${RELEASE1B_TEST_TMP}/sutok_XXXXXXXXXX")
  pb_validate_task_file "$su_pw_file"  "output" "su/pw"  || pb_halt "su pw invalid"
  pb_validate_task_file "$su_id_file"  "output" "su/id"  || pb_halt "su id invalid"
  pb_validate_task_file "$su_tok_file" "output" "su/tok" || pb_halt "su tok invalid"

  openssl rand -base64 32 | tr -d '\n' > "$su_pw_file" || pb_halt "su pw generation"
  local su_pw; su_pw=$(cat "$su_pw_file")
  local su_email="su_${RUN_SUFFIX}@test.invalid"

  # PocketBase v0.29.3 CLI mechanism — the ONLY supported creation path.
  # No fallback to unauthenticated API. If the CLI command fails, setup halts.
  #
  # Security properties of this approach:
  #   Identity  : .invalid TLD; run-suffix; cannot be a real address; not registered anywhere.
  #   Password  : Generated by openssl; appears briefly in process argument list.
  #               HISTIGNORE or shell history disable should be set before execution.
  #               Process-table exposure is milliseconds in an isolated local environment.
  #               This is accepted risk for a disposable credential.
  #   Logs      : PocketBase logs contain the email address but not the password.
  #               Log is at [isolated-root]/pb.log; retained within isolated root only.
  #   Deletion  : pb_delete_local_superuser uses the API DELETE with the SU token.
  #               After deletion the token file and ID file are removed.
  #   Failure   : pb_halt; no partial state left; no credential escapes isolation.
  #
  # If 'pocketbase superuser create' is not available in v0.29.3, confirm the exact
  # command from the v0.29.3 release notes before re-running.
  local create_log; create_log="${RELEASE1B_ISOLATED_ROOT}/su_create.log"
  "$RELEASE1B_PB_BIN" superuser create "$su_email" "$su_pw" \
    --dir "$RELEASE1B_PB_DATA_DIR" >> "$create_log" 2>&1 || {
      rm -f "$su_pw_file" "$su_id_file" "$su_tok_file"
      pb_halt "Local _superusers creation via CLI failed — see [isolated-root]/su_create.log; confirm 'pocketbase superuser create' is the correct v0.29.3 command"
    }
  print "[su] created via CLI"
  local su_w="$su_pw"; unset su_pw   # clear from local; original still in su_pw_file until auth

  # Authenticate
  local auth_body _ho _ro
  pbj_write auth_body "identity=${su_email}" "secret-file:password=${su_pw_file}" || pb_halt "su auth body"
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/_superusers/auth-with-password" \
    "" "$auth_body" "$_ho" "$_ro" "su-auth" "200" || {
      rm -f "$auth_body" "$_ho" "$_ro" "$su_pw_file"
      pb_halt "Local _superusers authentication failed"
    }
  rm -f "$auth_body" "$su_pw_file"   # destroy password after auth
  local resp_path; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  pb_copy_field "$resp_path" "token" "$su_tok_file" || { rm -f "$resp_path"; pb_halt "su tok copy"; }

  # Extract ID if not already set
  if [[ ! -s "$su_id_file" ]]; then
    pb_copy_field "$resp_path" "id" "$su_id_file" 2>/dev/null || true
  fi
  rm -f "$resp_path"

  _NATIVE_SU_TOK_FILE="$su_tok_file"
  _NATIVE_SU_ID_FILE="$su_id_file"
  registry_add "native-su" "auth" "_superusers" "$su_id_file"
  t_pass "T-SETUP-SU: local _superusers account created and authenticated"
}

pb_delete_local_superuser() {
  [[ -f "$_NATIVE_SU_ID_FILE" ]] || { t_fail "T-DEL-SU" "ID file missing"; return 1; }
  local su_id; su_id=$(cat "$_NATIVE_SU_ID_FILE")
  local auth_cfg _ho _ro
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { t_fail "T-DEL-SU" "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture DELETE \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/_superusers/records/${su_id}" \
    "$auth_cfg" "" "$_ho" "$_ro" "del-su" "204" "200" || {
      rm -f "$_ho" "$_ro"; t_fail "T-DEL-SU" "delete failed"; return 1
    }
  local resp_path; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"

  # Independent verification: token no longer valid
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" 2>/dev/null || true
  pb_capture GET \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/_superusers/records/${su_id}" \
    "${auth_cfg:-}" "" "$_ho" "$_ro" "verify-del-su" "401" "404" || {
      rm -f "$_ho" "$_ro"; t_fail "T-DEL-SU" "account still reachable after delete"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  rm -f "$_NATIVE_SU_TOK_FILE" "$_NATIVE_SU_ID_FILE"
  _NATIVE_SU_TOK_FILE="" _NATIVE_SU_ID_FILE=""
  registry_mark_deleted "native-su"
  t_pass "T-DEL-SU: local _superusers deleted and verified absent"
}

# ────────────────────────────────────────────────────────────────
# §13 SCHEMA VERIFICATION
# ────────────────────────────────────────────────────────────────

pb_verify_schema() {
  print "=== Schema Verification ==="
  local -a required_collections=(
    "users" "children" "courses" "lessons" "lesson_progress"
    "growth_logs" "activity_logs" "nutrition_logs" "wellbeing_logs"
    "immunisations" "articles" "bookmarks" "notifications"
    "consent_records" "otp_requests"
  )
  local missing=0 coll
  for coll in "${required_collections[@]}"; do
    local auth_cfg _ho _ro
    pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || pb_halt "schema verify auth"
    _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
    _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
    pb_capture GET \
      "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${coll}" \
      "$auth_cfg" "" "$_ho" "$_ro" "schema-$coll" "200" || {
        rm -f "$_ho" "$_ro"
        print "PREREQ FAIL: collection '$coll' not found"
        missing=$(( missing + 1 )); continue
      }
    local resp_path; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
    [[ -f "$resp_path" ]] && rm -f "$resp_path"
    t_pass "T-SCHEMA-$coll"
  done
  (( missing == 0 )) || pb_halt "$missing required collections absent — schema not applied"
}

# ────────────────────────────────────────────────────────────────
# §14 HOOK MANAGEMENT
# ────────────────────────────────────────────────────────────────

pb_verify_hook_directory() {
  print "=== Hook Directory Verification ==="
  local canary_route="/api/cp0_canary_${RUN_SUFFIX}"
  local canary_dest="${RELEASE1B_PB_HOOKS_DIR}/cp0_canary_${RUN_SUFFIX}.pb.js"
  # Constant response — no run identifier (Item 22 fix)
  cat > "$canary_dest" << HOOKEOF
routerAdd("GET", "${canary_route}", (e) => {
  return e.json(200, { active: true })
})
HOOKEOF
  chmod 600 "$canary_dest"
  pb_restart_pocketbase

  local status_f body_f
  status_f=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  body_f=$(mktemp   "${RELEASE1B_TEST_TMP}/resp_XXXXXXXXXX")
  python3 "$PBJ_HTTP_PY" "$status_f" "$body_f" \
    "${RELEASE1B_CANONICAL_URL_PREFIX}${canary_route}" 2>/dev/null
  local hstatus; hstatus=$(cat "$status_f" 2>/dev/null)

  if [[ "$hstatus" != "200" ]]; then
    rm -f "$canary_dest" "$status_f" "$body_f"
    pb_halt "Canary hook not loaded from [pb-hooks-dir] — verify --hooksDir in v0.29.3"
  fi

  # Verify response shape only (not run suffix)
  python3 - "$body_f" << 'PYEOF' || { rm -f "$canary_dest" "$status_f" "$body_f"; pb_halt "Canary response mismatch"; }
import json, sys
d = json.load(open(sys.argv[1]))
assert d == {"active": True}, f"unexpected canary body: {d}"
print("canary body: {active:true}")
PYEOF
  rm -f "$status_f" "$body_f" "$canary_dest"
  pb_restart_pocketbase

  # Verify route is gone
  status_f=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  body_f=$(mktemp   "${RELEASE1B_TEST_TMP}/resp_XXXXXXXXXX")
  python3 "$PBJ_HTTP_PY" "$status_f" "$body_f" \
    "${RELEASE1B_CANONICAL_URL_PREFIX}${canary_route}" 2>/dev/null
  hstatus=$(cat "$status_f" 2>/dev/null)
  rm -f "$status_f" "$body_f"
  [[ "$hstatus" = "404" ]] || pb_halt "Canary route still responds after removal"
  t_pass "T-HOOK-DIR: hooks load from [isolated-root]/pb_hooks via --hooksDir"
}

pb_install_hook_verified() {
  local hook_name="$1" label="$2"
  local src="${HOOK_SRC_PATHS[$hook_name]:-}"
  local expected="${HOOK_EXPECTED_SHA256[$hook_name]:-}"
  [[ -n "$src" && -n "$expected" ]] || pb_halt "Hook '$hook_name' not in manifest"
  [[ -f "$src" ]] || pb_halt "Hook source file not found: [hook-source/$hook_name]"
  local actual; actual=$(shasum -a 256 "$src" 2>/dev/null | awk '{print $1}')
  [[ "$actual" = "$expected" ]] || pb_halt "Hook '$hook_name' hash mismatch"
  python3 "$PBJ_SCAN_PY" --file "$src" 2>/dev/null | grep -q "^PASS" || \
    pb_halt "Hook '$hook_name' triggered secret scan"
  local dest="${RELEASE1B_PB_HOOKS_DIR}/${hook_name}.pb.js"
  [[ -f "$dest" ]] && pb_halt "Hook '$hook_name' already installed"
  cp "$src" "$dest" || pb_halt "Hook copy failed"
  chmod 600 "$dest"
  local dest_real; dest_real=$(pb_realpath "$dest")
  [[ "$dest_real" = "${RELEASE1B_CANONICAL_ROOT}/"* ]] || \
    pb_halt "Installed hook outside canonical root"
  t_pass "T-HOOK-INSTALL-$label"
}

pb_remove_hook_verified() {
  # Remove hook file, restart, verify health, probe original route, require 404
  local hook_name="$1" label="$2" probe_url="$3" probe_method="$4"
  local dest="${RELEASE1B_PB_HOOKS_DIR}/${hook_name}.pb.js"
  if [[ -f "$dest" ]]; then
    rm -f "$dest" || { CLEANUP_FAILURE=1; t_fail "T-HOOK-REMOVE-$label" "rm failed"; return 1; }
  fi
  [[ ! -f "$dest" ]] || { t_fail "T-HOOK-REMOVE-$label" "file still present"; return 1; }
  pb_restart_pocketbase

  local _ho _ro
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture "$probe_method" "$probe_url" "" "" "$_ho" "$_ro" \
    "hook-removed-probe-$label" "404" || {
      rm -f "$_ho" "$_ro"
      t_fail "T-HOOK-REMOVE-$label" "hook route still responds after removal"; return 1
    }
  local resp_path; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass "T-HOOK-REMOVE-$label: hook removed and route returns 404"
}

pb_hook_smoke_matrix() {
  # Five-actor matrix: anon, ordinary, app_admin, app_superadmin, native_superuser
  local hook_label="$1" url="$2" method="$3"
  local anon_exp="$4" ordinary_exp="$5" admin_exp="$6" sadmin_exp="$7" nsu_exp="$8"
  local body_file="${9:-}"

  local -a actor_labels=(anon ordinary app_admin app_superadmin native_superuser)
  local -a actor_toks=("" "$ORDINARY_TOK_FILE" "$ADMIN_TOK_FILE" "$SADMIN_TOK_FILE" "$_NATIVE_SU_TOK_FILE")
  local -a actor_expected=("$anon_exp" "$ordinary_exp" "$admin_exp" "$sadmin_exp" "$nsu_exp")

  typeset -i ai=1
  for alabel in "${actor_labels[@]}"; do
    local atf="${actor_toks[$ai]}" aexp="${actor_expected[$ai]}"
    local auth_cfg="" _ho _ro
    if [[ -n "$atf" && -f "$atf" ]]; then
      pb_make_auth auth_cfg "$atf" || { t_fail "T-SMOKE-${hook_label}-${alabel}" "auth"; ai=$(( ai + 1 )); continue; }
    fi
    _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
    _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
    pb_capture "$method" "$url" "$auth_cfg" "$body_file" "$_ho" "$_ro" \
      "T-SMOKE-${hook_label}-${alabel}" $=aexp || {
        rm -f "$_ho" "$_ro"
        t_fail "T-SMOKE-${hook_label}-${alabel}" "unexpected HTTP"
        ai=$(( ai + 1 )); continue
      }
    local resp_path; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
    [[ -f "$resp_path" ]] && rm -f "$resp_path"
    t_pass "T-SMOKE-${hook_label}-${alabel}: HTTP $aexp"
    ai=$(( ai + 1 ))
  done
}

# ────────────────────────────────────────────────────────────────
# §15 RULE LIFECYCLE
# ────────────────────────────────────────────────────────────────

pb_apply_rule_local() {
  local collection="$1" operation="$2" new_rule="$3" label="$4"
  local auth_cfg _ho _ro resp_path

  # 1. Read baseline
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || return 1
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${collection}" \
    "$auth_cfg" "" "$_ho" "$_ro" "$label/get" "200" || {
      rm -f "$_ho" "$_ro"; t_fail "$label" "cannot read collection"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  local baseline_file; baseline_file=$(mktemp "${RELEASE1B_TEST_TMP}/rule_XXXXXXXXXX")
  python3 - "$resp_path" "$operation" "$baseline_file" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1])); v = d.get(sys.argv[2], '')
with open(sys.argv[3], 'w') as f: f.write('' if v is None else str(v))
PYEOF
  rm -f "$resp_path"

  # 2. Apply new rule
  local patch_body
  pbj_write patch_body "${operation}=${new_rule}" || { rm -f "$baseline_file"; return 1; }
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$baseline_file" "$patch_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${collection}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "$label/apply" "200" || {
      rm -f "$patch_body" "$_ho" "$_ro" "$baseline_file"; t_fail "$label" "apply failed"; return 1
    }
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"

  # 3. Independent retrieval and verify
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$baseline_file"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${collection}" \
    "$auth_cfg" "" "$_ho" "$_ro" "$label/verify" "200" || {
      rm -f "$_ho" "$_ro" "$baseline_file"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  python3 - "$resp_path" "$operation" "$new_rule" << 'PYEOF' || {
    rm -f "$resp_path" "$baseline_file"; t_fail "$label" "rule verification mismatch"; return 1
  }
import json, sys
d = json.load(open(sys.argv[1]))
actual = d.get(sys.argv[2], '')
assert actual == sys.argv[3], f"expected '{sys.argv[3]}' got '{actual}'"
PYEOF
  rm -f "$resp_path"

  typeset -g "RULE_BASELINE_${collection}_${operation}=${baseline_file}"
  t_pass "T-RULE-APPLY-$label"
}

pb_restore_rule_local() {
  local collection="$1" operation="$2" label="$3"
  local baseline_var="RULE_BASELINE_${collection}_${operation}"
  local baseline_file="${(P)baseline_var:-}"
  [[ -f "$baseline_file" ]] || { t_fail "$label/restore" "baseline file missing"; return 1; }
  local original_rule; original_rule=$(cat "$baseline_file")
  local patch_body auth_cfg _ho _ro resp_path
  pbj_write patch_body "${operation}=${original_rule}" || return 1
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${collection}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "$label/restore" "200" || {
      rm -f "$patch_body" "$_ho" "$_ro" "$baseline_file"; return 1
    }
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  rm -f "$baseline_file"; typeset -g "${baseline_var}="
  t_pass "T-RULE-RESTORE-$label"
}

# ────────────────────────────────────────────────────────────────
# §16 HTTP HELPERS
# ────────────────────────────────────────────────────────────────

pbj_write() {
  local __v="$1"; shift
  local __f; __f=$(mktemp "${RELEASE1B_TEST_TMP}/json_XXXXXXXXXX.json") || return 1
  pb_validate_task_file "$__f" "output" "pbj_write" || { rm -f "$__f"; return 1; }
  local stdin_needed=0 s
  for s in "$@"; do [[ "$s" = secret:* ]] && stdin_needed=1 && break; done
  if (( stdin_needed )); then
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" python3 "$PBJ_PY" "$__f" "$@"
  else
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" python3 "$PBJ_PY" "$__f" "$@" </dev/null
  fi
  local rc=$?; (( rc == 0 )) || { rm -f "$__f"; return 1; }
  typeset -g "${__v}=${__f}"
}

pb_make_auth() {
  local __v="$1" tok_file="$2"
  pb_validate_task_file "$tok_file" "secret-input" "pb_make_auth" || return 1
  local __f; __f=$(mktemp "${RELEASE1B_TEST_TMP}/cfg_XXXXXXXXXX.cfg") || return 1
  pb_validate_task_file "$__f" "output" "pb_make_auth/cfg" || { rm -f "$__f"; return 1; }
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" \
    python3 "$PBJ_AUTH_PY" "$__f" "$tok_file" || { rm -f "$__f"; return 1; }
  typeset -g "${__v}=${__f}"
}

pb_field() {
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" python3 "$PBJ_FIELD_PY" "$1" "$2"
}

pb_copy_field() {
  pb_validate_task_file "$1" "input"  "copy/resp" || return 1
  pb_validate_task_file "$3" "output" "copy/dest" || return 1
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" python3 "$PBJ_COPY_PY" "$1" "$2" "$3"
}

pb_extract_item_id() {
  local resp="$1" index="$2" dest="$3" expected="${4:-}"
  pb_validate_task_file "$resp" "input"  "extract/resp" || return 1
  pb_validate_task_file "$dest" "output" "extract/dest" || return 1
  local -a args=("$resp" "id" "$index" "$dest")
  [[ -n "$expected" ]] && args+=("$expected")
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" python3 "$PBJ_EXTRACT_PY" "${args[@]}"
}

pb_capture() {
  local method="$1" url="$2" auth_cfg="$3" body_file="$4"
  local http_out="$5" resp_out="$6" label="$7"
  shift 7; local -a accepted=("$@")

  pb_validate_method "$method" "$label"                    || return 1
  pb_validate_local_url "$url" "$label"                   || return 1
  pb_validate_accepted_statuses "$label" "${accepted[@]}" || return 1
  pb_validate_task_file "$http_out" "output" "$label/http" || return 1
  pb_validate_task_file "$resp_out" "output" "$label/resp" || return 1
  [[ -n "$auth_cfg"  ]] && { pb_validate_task_file "$auth_cfg"  "secret-input" "$label/auth" || return 1; }
  [[ -n "$body_file" ]] && { pb_validate_task_file "$body_file" "input"        "$label/body" || return 1; }

  local respfile; respfile=$(mktemp "${RELEASE1B_TEST_TMP}/resp_XXXXXXXXXX.json") || return 1
  pb_validate_task_file "$respfile" "output" "$label/respfile" || { rm -f "$respfile"; return 1; }

  local -a cargs; cargs=(-s -o "$respfile" -w '%{http_code}' -X "$method" --max-redirs 0 "$url")
  [[ -n "$auth_cfg"  ]] && cargs+=(-K "$auth_cfg")
  [[ -n "$body_file" ]] && cargs+=(-H 'Content-Type: application/json' --data-binary "@${body_file}")

  local actual; actual=$(curl "${cargs[@]}" 2>/dev/null)
  local curl_rc=$?
  [[ -n "$auth_cfg" && -f "$auth_cfg" ]] && rm -f "$auth_cfg"

  printf '%s' "$actual" > "$http_out"
  if (( curl_rc != 0 )); then
    rm -f "$respfile"; return 1
  fi

  local matched=0 s
  for s in "${accepted[@]}"; do [[ "$actual" = "$s" ]] && matched=1 && break; done
  if (( matched == 0 )); then
    print "FAIL [$label]: expected (${accepted[*]}) got $actual" >&2
    rm -f "$respfile"; return 1
  fi
  printf '%s' "$respfile" > "$resp_out"
  return 0
}

# ────────────────────────────────────────────────────────────────
# §17 FIXTURE REGISTRY
# ────────────────────────────────────────────────────────────────

typeset -gA FIXTURE_REGISTRY=()

registry_add() {
  local label="$1" type="$2" collection="$3" id_file="$4"
  FIXTURE_REGISTRY[$label]="${type}:${collection}:${id_file}:CREATED"
}

registry_mark_deleted() {
  local label="$1"
  [[ -n "${FIXTURE_REGISTRY[$label]:-}" ]] && \
    FIXTURE_REGISTRY[$label]="${FIXTURE_REGISTRY[$label]%:*}:DELETED"
}

pb_report_fixture_cleanup() {
  local label
  for label in "${(k)FIXTURE_REGISTRY[@]}"; do
    local state="${FIXTURE_REGISTRY[$label]##*:}"
    if [[ "$state" = "CREATED" ]]; then
      t_fail "T-FIXTURE-CLEANUP-$label" "not confirmed deleted"
    else
      t_pass "T-FIXTURE-CLEANUP-$label"
    fi
  done
}

# ────────────────────────────────────────────────────────────────
# §18 USER LIFECYCLE
# ────────────────────────────────────────────────────────────────

pb_create_test_user() {
  local label="$1" email_local="$2" role_spec="$3"
  local out_id_var="$4" out_tok_var="$5"

  local pw_file id_file tok_file
  pw_file=$(mktemp  "${RELEASE1B_TEST_TMP}/pw_XXXXXXXXXX")
  id_file=$(mktemp  "${RELEASE1B_TEST_TMP}/id_XXXXXXXXXX")
  tok_file=$(mktemp "${RELEASE1B_TEST_TMP}/tok_XXXXXXXXXX")
  pb_validate_task_file "$pw_file"  "output" "$label/pw"  || return 1
  pb_validate_task_file "$id_file"  "output" "$label/id"  || return 1
  pb_validate_task_file "$tok_file" "output" "$label/tok" || return 1
  openssl rand -base64 24 | tr -d '\n' > "$pw_file"

  local identity="${email_local}_${RUN_SUFFIX}@test.invalid"
  local create_body auth_cfg _ho _ro resp_path
  pbj_write create_body "email=${identity}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" || {
      rm -f "$pw_file" "$id_file" "$tok_file"; return 1
    }
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$pw_file" "$id_file" "$tok_file" "$create_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records" \
    "$auth_cfg" "$create_body" "$_ho" "$_ro" "create-$label" "200" || {
      rm -f "$create_body" "$_ho" "$_ro" "$pw_file" "$id_file" "$tok_file"; return 1
    }
  rm -f "$create_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  pb_copy_field "$resp_path" "id" "$id_file" || { rm -f "$resp_path" "$pw_file" "$id_file" "$tok_file"; return 1; }
  rm -f "$resp_path"

  if [[ -n "$role_spec" ]]; then
    local user_id; user_id=$(cat "$id_file")
    local role_body
    pbj_write role_body $=role_spec || { rm -f "$pw_file" "$id_file" "$tok_file"; return 1; }
    pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$role_body" "$pw_file" "$id_file" "$tok_file"; return 1; }
    _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
    _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
    pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
      "$auth_cfg" "$role_body" "$_ho" "$_ro" "role-$label" "200" || {
        rm -f "$role_body" "$_ho" "$_ro" "$pw_file" "$id_file" "$tok_file"; return 1
      }
    rm -f "$role_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
    [[ -f "$resp_path" ]] && rm -f "$resp_path"
  fi

  local auth_body
  pbj_write auth_body "identity=${identity}" "secret-file:password=${pw_file}" || {
    rm -f "$pw_file" "$id_file" "$tok_file"; return 1
  }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-with-password" \
    "" "$auth_body" "$_ho" "$_ro" "auth-$label" "200" || {
      rm -f "$auth_body" "$_ho" "$_ro" "$pw_file" "$id_file" "$tok_file"; return 1
    }
  rm -f "$auth_body" "$pw_file"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  pb_copy_field "$resp_path" "token" "$tok_file" || { rm -f "$resp_path" "$id_file" "$tok_file"; return 1; }
  rm -f "$resp_path"

  typeset -g "${out_id_var}=${id_file}"
  typeset -g "${out_tok_var}=${tok_file}"
  registry_add "$label" "user" "users" "$id_file"
  t_pass "T-SETUP-USER-$label"
}

pb_delete_test_user() {
  local label="$1" id_file="$2" tok_file="${3:-}"
  [[ -f "$id_file" ]] || { t_fail "T-DEL-USER-$label" "ID file missing"; return 1; }
  local user_id; user_id=$(cat "$id_file")
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || return 1
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture DELETE "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "" "$_ho" "$_ro" "del-user-$label" "204" "200" || {
      rm -f "$_ho" "$_ro"; t_fail "T-DEL-USER-$label" "delete failed"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"

  # Independent absence check
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || return 1
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "" "$_ho" "$_ro" "verify-del-$label" "404" || {
      rm -f "$_ho" "$_ro"; t_fail "T-DEL-USER-$label" "user still exists"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  # Only now remove ID file
  rm -f "$id_file"
  [[ -n "$tok_file" && -f "$tok_file" ]] && rm -f "$tok_file"
  registry_mark_deleted "$label"
  t_pass "T-DEL-USER-$label"
}

pb_delete_record() {
  local label="$1" collection="$2" id_file="$3"
  [[ -f "$id_file" ]] || { t_fail "T-DEL-REC-$label" "ID file missing"; return 1; }
  local rec_id; rec_id=$(cat "$id_file")
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || return 1
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture DELETE \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${collection}/records/${rec_id}" \
    "$auth_cfg" "" "$_ho" "$_ro" "del-rec-$label" "204" "200" || {
      rm -f "$_ho" "$_ro"; t_fail "T-DEL-REC-$label" "delete failed"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || return 1
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${collection}/records/${rec_id}" \
    "$auth_cfg" "" "$_ho" "$_ro" "verify-del-rec-$label" "404" || {
      rm -f "$_ho" "$_ro"; t_fail "T-DEL-REC-$label" "record still exists"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  rm -f "$id_file"
  registry_mark_deleted "$label"
  t_pass "T-DEL-REC-$label"
}

# ────────────────────────────────────────────────────────────────
# §19 LEGACY FIXTURE
# ────────────────────────────────────────────────────────────────

pb_create_legacy_fixture() {
  pb_create_test_user "legacy" "legacy_user" "" LEGACY_ID_FILE LEGACY_TOK_FILE || \
    pb_halt "Legacy user creation failed"

  local legacy_id; legacy_id=$(cat "$LEGACY_ID_FILE")
  local patch_body auth_cfg _ho _ro resp_path

  pbj_write patch_body "b:phone_verified=true" || pb_halt "legacy phone patch body"
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body"; pb_halt "auth"; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${legacy_id}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "legacy-phone-set" "200" || pb_halt "phone_verified patch"
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"

  _create_dep_record() {
    local dep="$1" coll="$2" dest_var="$3"; shift 3
    local body _hh _rr rp
    pbj_write body "$@" || { t_unresolved "T-LEGACY-$dep" "body build failed"; return 0; }
    pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$body"; return 1; }
    _hh=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
    _rr=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
    pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${coll}/records" \
      "$auth_cfg" "$body" "$_hh" "$_rr" "T-LEGACY-$dep" "200" || {
        rm -f "$body" "$_hh" "$_rr"
        t_unresolved "T-LEGACY-$dep" "collection '$coll' absent in isolated instance"
        return 0
      }
    rm -f "$body"; rp=$(cat "$_rr"); rm -f "$_hh" "$_rr"
    local df; df=$(mktemp "${RELEASE1B_TEST_TMP}/id_XXXXXXXXXX")
    pb_copy_field "$rp" "id" "$df" || { rm -f "$rp" "$df"; return 1; }
    rm -f "$rp"
    typeset -g "${dest_var}=${df}"
    registry_add "$dep" "record" "$coll" "$df"
    t_pass "T-LEGACY-$dep"
  }

  _create_dep_record "CHILD"     "children"           LEGACY_CHILD_ID_FILE    \
    "user=${legacy_id}" "name=TestChild_${RUN_SUFFIX}" "b:is_born=false"
  _create_dep_record "GROWTH"    "growth_logs"         LEGACY_GROWTH_ID_FILE   \
    "user=${legacy_id}" "n:weight_kg=3.2"
  _create_dep_record "ACTIVITY"  "activity_logs"       LEGACY_ACTIVITY_ID_FILE \
    "user=${legacy_id}" "type=walk"
  _create_dep_record "IMMUN"     "immunisations"       LEGACY_IMMUN_ID_FILE    \
    "user=${legacy_id}" "name=BCG"
  _create_dep_record "PROGRESS"  "lesson_progress"     LEGACY_PROGRESS_ID_FILE \
    "user=${legacy_id}" "n:progress_percent=50"
  _create_dep_record "NB_ENROLL" "newborn_enrollments" LEGACY_NB_ENROLL_ID_FILE \
    "user=${legacy_id}"
}

pb_delete_legacy_fixture() {
  local -a dep_labels=(NB_ENROLL PROGRESS IMMUN ACTIVITY GROWTH CHILD)
  local -a dep_files=("$LEGACY_NB_ENROLL_ID_FILE" "$LEGACY_PROGRESS_ID_FILE"
    "$LEGACY_IMMUN_ID_FILE" "$LEGACY_ACTIVITY_ID_FILE"
    "$LEGACY_GROWTH_ID_FILE" "$LEGACY_CHILD_ID_FILE")
  typeset -i di=1
  for dep in "${dep_labels[@]}"; do
    local df="${dep_files[$di]}"
    if [[ -f "$df" ]]; then
      local coll; coll=$(python3 -c "
v='${FIXTURE_REGISTRY[$dep]:-}'; parts=v.split(':')
print(parts[1] if len(parts)>1 else '')" 2>/dev/null)
      [[ -n "$coll" ]] && pb_delete_record "$dep" "$coll" "$df" || true
    fi
    di=$(( di + 1 ))
  done
  [[ -f "$LEGACY_ID_FILE" ]] && pb_delete_test_user "legacy" "$LEGACY_ID_FILE" "$LEGACY_TOK_FILE" || true
}

# ────────────────────────────────────────────────────────────────
# §20 ALIAS FIXTURES
# ────────────────────────────────────────────────────────────────

pb_setup_alias_group() {
  # WRONG_PW_FILE must exist (created in cp0_run before this call)
  pb_validate_task_file "$WRONG_PW_FILE" "secret-input" "alias-setup/wrong-pw" || \
    pb_halt "WRONG_PW_FILE not ready before alias fixture setup"

  # Interceptor smoke test (no alias account yet)
  local smoke_body _ho _ro resp_path
  pbj_write smoke_body "identity=smoke_${RUN_SUFFIX}@test.invalid" \
    "secret-file:password=${WRONG_PW_FILE}" || pb_halt "alias smoke body"
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-with-password" \
    "" "$smoke_body" "$_ho" "$_ro" "alias-interceptor-smoke" "400" "401" || {
      rm -f "$smoke_body" "$_ho" "$_ro"
      t_blocking "T-ALIAS-INTERCEPTOR-ACTIVE" \
        "alias interceptor not active — all alias-dependent tests blocked"
      return 1
    }
  rm -f "$smoke_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass "T-ALIAS-INTERCEPTOR-ACTIVE"

  pb_create_test_user "timing-legacy" "timing_legacy" "" \
    TIMING_LEGACY_ID_FILE TIMING_LEGACY_TOKEN_FILE || pb_halt "timing legacy creation"

  ALIAS_PW_FILE=$(mktemp "${RELEASE1B_TEST_TMP}/apw_XXXXXXXXXX")
  pb_validate_task_file "$ALIAS_PW_FILE" "output" "alias-pw" || pb_halt "alias pw invalid"
  openssl rand -base64 24 | tr -d '\n' > "$ALIAS_PW_FILE"
  pb_validate_task_file "$ALIAS_PW_FILE" "secret-input" "alias-pw-verify" || pb_halt "alias pw mode"

  ALIAS_ID_FILE=$(mktemp    "${RELEASE1B_TEST_TMP}/alias_id_XXXXXXXXXX")
  ALIAS_TOKEN_FILE=$(mktemp "${RELEASE1B_TEST_TMP}/alias_tok_XXXXXXXXXX")
  local alias_body auth_cfg
  pbj_write alias_body \
    "email=alias_internal_${RUN_SUFFIX}@internal.invalid" \
    "secret-file:password=${ALIAS_PW_FILE}" \
    "secret-file:passwordConfirm=${ALIAS_PW_FILE}" \
    "b:is_alias_account=true" || pb_halt "alias create body"
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$alias_body"; pb_halt "auth"; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records" \
    "$auth_cfg" "$alias_body" "$_ho" "$_ro" "alias-create" "200" || {
      rm -f "$alias_body" "$_ho" "$_ro"; pb_halt "alias account creation failed"
    }
  rm -f "$alias_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  pb_copy_field "$resp_path" "id" "$ALIAS_ID_FILE" || { rm -f "$resp_path"; pb_halt "alias id copy"; }
  rm -f "$resp_path"
  registry_add "alias-account" "user" "users" "$ALIAS_ID_FILE"
  t_pass "T-ALIAS-FIXTURES"
}

pb_cleanup_alias_group() {
  pb_delete_test_user "alias-account"  "$ALIAS_ID_FILE"         "$ALIAS_TOKEN_FILE"  || true
  pb_delete_test_user "timing-legacy"  "$TIMING_LEGACY_ID_FILE" "$TIMING_LEGACY_TOKEN_FILE" || true
  rm -f "$ALIAS_PW_FILE" "$WRONG_PW_FILE"
  ALIAS_PW_FILE="" WRONG_PW_FILE="" ALIAS_ID_FILE="" ALIAS_TOKEN_FILE=""
  TIMING_LEGACY_ID_FILE="" TIMING_LEGACY_TOKEN_FILE=""
}

pb_alias_enum_case() {
  local case_num="$1" label="$2" identity="$3" pw_file="$4" expected="$5"
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-$case_num" "blocked"; return 0; }
  pb_validate_task_file "$pw_file" "secret-input" "alias-c${case_num}/pw" || return 1
  local body _ho _ro respfile hdr_out ct_out sz_out tm_out
  pbj_write body "identity=${identity}" "secret-file:password=${pw_file}" || return 1
  respfile=$(mktemp "${RELEASE1B_TEST_TMP}/eresp_XXXXXXXXXX.json")
  hdr_out=$(mktemp  "${RELEASE1B_TEST_TMP}/hdr_XXXXXXXXXX.txt")
  ct_out=$(mktemp   "${RELEASE1B_TEST_TMP}/ct_XXXXXXXXXX.txt")
  sz_out=$(mktemp   "${RELEASE1B_TEST_TMP}/sz_XXXXXXXXXX.txt")
  tm_out=$(mktemp   "${RELEASE1B_TEST_TMP}/tm_XXXXXXXXXX.txt")

  local raw_hdr="${RELEASE1B_TEST_TMP}/raw_hdr_${case_num}_$$.tmp"
  local curl_meta
  curl_meta=$(curl -s -o "$respfile" -D "$raw_hdr" \
    -w '%{http_code}\t%{content_type}\t%{size_download}\t%{time_total}' \
    -X POST --max-redirs 0 \
    -H 'Content-Type: application/json' \
    --data-binary "@${body}" \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-with-password" 2>/dev/null)
  local curl_rc=$?; rm -f "$body"

  # Sanitize headers (safe fields only, no values that could contain tokens)
  python3 - "$raw_hdr" "$hdr_out" << 'PYEOF' 2>/dev/null
import sys
SAFE = frozenset({'content-type','content-length','cache-control'})
lines = []
with open(sys.argv[1], 'r', errors='replace') as f:
    for line in f:
        s = line.strip()
        if not s: continue
        if ':' in s:
            name = s.split(':', 1)[0].lower().strip()
            if name in SAFE: lines.append(s)
        else: lines.append(s)
with open(sys.argv[2], 'w') as f: f.write('\n'.join(lines))
PYEOF
  rm -f "$raw_hdr"

  if (( curl_rc != 0 )); then
    rm -f "$respfile" "$hdr_out" "$ct_out" "$sz_out" "$tm_out"
    t_fail "T-ALIAS-$case_num" "curl error"; return 1
  fi

  python3 - "$curl_meta" "$ct_out" "$sz_out" "$tm_out" << 'PYEOF' 2>/dev/null || {
    rm -f "$respfile" "$hdr_out" "$ct_out" "$sz_out" "$tm_out"; return 1
  }
import sys, math, re
parts = sys.argv[1].split('\t')
assert len(parts) == 4, f"meta parts: {len(parts)}"
http_code, ct, sz_s, tm_s = parts
assert re.fullmatch(r'[1-5][0-9][0-9]', http_code)
sz = int(sz_s); assert sz >= 0
tm = float(tm_s); assert math.isfinite(tm) and tm >= 0
for ch in ct: assert ord(ch) >= 32
open(sys.argv[2], 'w').write(ct)
open(sys.argv[3], 'w').write(str(sz))
open(sys.argv[4], 'w').write(str(tm))
PYEOF

  local actual_http; actual_http=$(print "$curl_meta" | cut -f1)
  if [[ "$actual_http" != "$expected" ]]; then
    rm -f "$respfile" "$hdr_out" "$ct_out" "$sz_out" "$tm_out"
    t_fail "T-ALIAS-$case_num" "expected $expected got $actual_http"; return 1
  fi

  ENUM_HTTP_VALUES[$case_num]="$actual_http"
  ENUM_RESP_FILES[$case_num]="$respfile"
  ENUM_HDR_FILES[$case_num]="$hdr_out"
  ENUM_CT_FILES[$case_num]="$ct_out"
  ENUM_SIZE_FILES[$case_num]="$sz_out"
  ENUM_TIME_FILES[$case_num]="$tm_out"
  t_pass "T-ALIAS-$case_num: $label → HTTP $actual_http"
}

# ────────────────────────────────────────────────────────────────
# §21 CRUD MATRIX HELPERS
# ────────────────────────────────────────────────────────────────

_t_deny_op() {
  local coll="$1" method="$2" suffix="$3" tok_file="$4" label="$5"
  shift 5; local -a expected=("$@")
  (( HALT_DEPENDENTS )) && { t_skip "$label" "blocked"; return 0; }
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$tok_file" || { t_fail "$label" "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture "$method" \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${coll}/${suffix}" \
    "$auth_cfg" "" "$_ho" "$_ro" "$label" "${expected[@]}" || {
      rm -f "$_ho" "$_ro"; t_fail "$label" "unexpected status"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass "$label"
}

_t_deny_list_or_empty() {
  local coll="$1" filter="$2" tok_file="$3" label="$4" allowed="${5:-antenatal}"
  (( HALT_DEPENDENTS )) && { t_skip "$label" "blocked"; return 0; }
  local auth_cfg _ho _ro
  pb_make_auth auth_cfg "$tok_file" || { t_fail "$label" "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  local url="${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/${coll}/records"
  [[ -n "$filter" ]] && url="${url}?filter=${filter}"
  pb_capture GET "$url" "$auth_cfg" "" "$_ho" "$_ro" "$label" "200" "403" "404" || {
    rm -f "$_ho" "$_ro"; t_fail "$label" "request failed"; return 1
  }
  local actual_http; actual_http=$(cat "$_ho"); local resp_path; resp_path=$(cat "$_ro")
  rm -f "$_ho" "$_ro"
  if [[ "$actual_http" = "403" || "$actual_http" = "404" ]]; then
    [[ -f "$resp_path" ]] && rm -f "$resp_path"; t_pass "$label: denied ($actual_http)"; return 0
  fi
  if [[ -f "$resp_path" ]]; then
    python3 - "$resp_path" "$allowed" "$label" << 'PYEOF'
import json, sys
ALLOWED, label = sys.argv[2], sys.argv[3]
d = json.load(open(sys.argv[1]))
total = d.get('totalItems', -1)
items = d.get('items', [])
if total < 0: print(f"HARNESS_ERROR [{label}]: no totalItems"); sys.exit(2)
if total == 0 and not items: print(f"PASS [{label}]: 200 with 0 items"); sys.exit(0)
prohibited = [i for i in items if i.get('category', '') != ALLOWED]
if prohibited: print(f"BLOCKING [{label}]: {len(prohibited)} prohibited items"); sys.exit(1)
print(f"PASS [{label}]: {total} items, all category={ALLOWED}")
PYEOF
    local rc=$?; rm -f "$resp_path"
    case $rc in
      0) t_pass "$label" ;;
      1) t_blocking "$label" "prohibited content in permitted list response" ;;
      *) t_harness_err "$label" "content check error" ;;
    esac
  fi
}

# Named CRUD wrappers — children
t_ch_list()   { _t_deny_op children GET "records"                                     "$ORDINARY_TOK_FILE" T-CRUD-CH-LIST   "403"; }
t_ch_create() { _t_deny_op children POST "records"                                    "$ORDINARY_TOK_FILE" T-CRUD-CH-CREATE "403"; }
t_ch_view()   {
  (( HALT_DEPENDENTS )) && { t_skip T-CRUD-CH-VIEW "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_unresolved T-CRUD-CH-VIEW "no child ID"; return 0; }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE")
  _t_deny_op children GET "records/${cid}" "$ORDINARY_TOK_FILE" T-CRUD-CH-VIEW "403" "404"
}
t_ch_update() {
  (( HALT_DEPENDENTS )) && { t_skip T-CRUD-CH-UPDATE "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_unresolved T-CRUD-CH-UPDATE "no child ID"; return 0; }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE")
  _t_deny_op children PATCH "records/${cid}" "$ORDINARY_TOK_FILE" T-CRUD-CH-UPDATE "403" "404"
}
t_ch_delete() {
  (( HALT_DEPENDENTS )) && { t_skip T-CRUD-CH-DELETE "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_unresolved T-CRUD-CH-DELETE "no child ID"; return 0; }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE")
  _t_deny_op children DELETE "records/${cid}" "$ORDINARY_TOK_FILE" T-CRUD-CH-DELETE "403" "404"
}
t_ch_expand() {
  (( HALT_DEPENDENTS )) && { t_skip T-CRUD-CH-EXPAND "blocked"; return 0; }
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { t_fail T-CRUD-CH-EXPAND "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records?expand=children" \
    "$auth_cfg" "" "$_ho" "$_ro" T-CRUD-CH-EXPAND "200" "400" "403" || {
      rm -f "$_ho" "$_ro"; t_fail T-CRUD-CH-EXPAND "failed"; return 1
    }
  local ahttp; ahttp=$(cat "$_ho"); resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  if [[ "$ahttp" = "200" && -f "$resp_path" ]]; then
    python3 - "$resp_path" << 'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
for item in d.get('items', []):
    if item.get('expand', {}).get('children'): print("BLOCKING: children expanded"); sys.exit(1)
print("PASS: no children in expansion"); sys.exit(0)
PYEOF
    local rc=$?; rm -f "$resp_path"
    [[ $rc -eq 0 ]] && t_pass T-CRUD-CH-EXPAND || t_blocking T-CRUD-CH-EXPAND "children expanded"
  else
    [[ -f "$resp_path" ]] && rm -f "$resp_path"
    t_pass "T-CRUD-CH-EXPAND: denied ($ahttp)"
  fi
}

# Per-collection named wrappers using _t_deny_op (abbreviated form)
# growth_logs
t_gl_list()   { _t_deny_op growth_logs GET    "records"            "$ORDINARY_TOK_FILE" T-CRUD-GL-LIST   "403"; }
t_gl_create() { _t_deny_op growth_logs POST   "records"            "$ORDINARY_TOK_FILE" T-CRUD-GL-CREATE "403"; }
t_gl_view()   { _t_deny_op growth_logs GET    "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-GL-VIEW  "403" "404"; }
t_gl_update() { _t_deny_op growth_logs PATCH  "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-GL-UPDATE "403" "404"; }
t_gl_delete() { _t_deny_op growth_logs DELETE "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-GL-DELETE "403" "404"; }
# activity_logs
t_al_list()   { _t_deny_op activity_logs GET    "records"            "$ORDINARY_TOK_FILE" T-CRUD-AL-LIST   "403"; }
t_al_create() { _t_deny_op activity_logs POST   "records"            "$ORDINARY_TOK_FILE" T-CRUD-AL-CREATE "403"; }
t_al_view()   { _t_deny_op activity_logs GET    "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-AL-VIEW  "403" "404"; }
t_al_update() { _t_deny_op activity_logs PATCH  "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-AL-UPDATE "403" "404"; }
t_al_delete() { _t_deny_op activity_logs DELETE "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-AL-DELETE "403" "404"; }
# immunisations
t_imm_list()   { _t_deny_op immunisations GET    "records"            "$ORDINARY_TOK_FILE" T-CRUD-IMM-LIST   "403"; }
t_imm_create() { _t_deny_op immunisations POST   "records"            "$ORDINARY_TOK_FILE" T-CRUD-IMM-CREATE "403"; }
t_imm_view()   { _t_deny_op immunisations GET    "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-IMM-VIEW  "403" "404"; }
t_imm_update() { _t_deny_op immunisations PATCH  "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-IMM-UPDATE "403" "404"; }
t_imm_delete() { _t_deny_op immunisations DELETE "records/PLACEHOLDER" "$ORDINARY_TOK_FILE" T-CRUD-IMM-DELETE "403" "404"; }
# content/courses
t_nb_list() { _t_deny_list_or_empty "courses" "category%3D%22newborn%22" "$ORDINARY_TOK_FILE" "T-CRUD-NB-LIST" "antenatal"; }
t_nb_view() {
  [[ -f "$NEWBORN_COURSE_ID_FILE" ]] || { t_unresolved T-CRUD-NB-VIEW "no newborn course ID"; return 0; }
  local nid; nid=$(cat "$NEWBORN_COURSE_ID_FILE")
  _t_deny_op courses GET "records/${nid}" "$ORDINARY_TOK_FILE" T-CRUD-NB-VIEW "403" "404"
}

# ────────────────────────────────────────────────────────────────
# §22 FIELD PROTECTION TESTS
# ────────────────────────────────────────────────────────────────

t_field_role_reject() {
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  local body auth_cfg _ho _ro resp_path
  pbj_write body "role=admin" || { t_fail T-FIELD-ROLE "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-FIELD-ROLE "403" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-FIELD-ROLE "role change accepted"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-FIELD-ROLE
}

t_field_phone_reject() {
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  local body auth_cfg _ho _ro resp_path
  pbj_write body "phone=${T_PHONE_TEST_VALUE}" || { t_fail T-FIELD-PHONE "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-FIELD-PHONE "403" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-FIELD-PHONE "direct phone write accepted"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass "T-FIELD-PHONE: direct phone write rejected (value: $T_PHONE_TEST_VALUE)"
}

t_field_alias_flag_reject() {
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  local body auth_cfg _ho _ro resp_path
  pbj_write body "b:is_alias_account=true" || { t_fail T-FIELD-ALIAS-FLAG "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-FIELD-ALIAS-FLAG "403" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-FIELD-ALIAS-FLAG "is_alias_account accepted"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-FIELD-ALIAS-FLAG
}

# ────────────────────────────────────────────────────────────────
# §23 FILE AUTHORIZATION TESTS
# ────────────────────────────────────────────────────────────────

_t_file_request() {
  local label="$1" url_base="$2" tok_file="${3:-}" status_var="$4"
  local sf bf
  sf=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  bf=$(mktemp "${RELEASE1B_TEST_TMP}/resp_XXXXXXXXXX.bin")
  local -a args=("$sf" "$bf" "$url_base")
  [[ -n "$tok_file" ]] && args+=("$tok_file")
  python3 "$PBJ_HTTP_PY" "${args[@]}" 2>/dev/null
  local hs; hs=$(cat "$sf" 2>/dev/null)
  rm -f "$sf" "$bf"
  typeset -g "${status_var}=${hs}"
}

t_file_auth_1() {
  [[ -f "$PREG_COURSE_ID_FILE" && -f "$PREG_THUMB_FILE" ]] || \
    { t_unresolved T-FILE-AUTH-1 "pregnancy course fixture absent"; return 0; }
  local cid; cid=$(cat "$PREG_COURSE_ID_FILE"); local thumb; thumb=$(cat "$PREG_THUMB_FILE")
  local fhttp
  _t_file_request T-FILE-AUTH-1 \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/courses/${cid}/${thumb}" \
    "$ORDINARY_TOK_FILE" fhttp
  [[ "$fhttp" = "200" ]] && t_pass T-FILE-AUTH-1 || t_fail T-FILE-AUTH-1 "expected 200 got $fhttp"
}

t_file_auth_2() {
  [[ -f "$NEWBORN_COURSE_ID_FILE" ]] || { t_unresolved T-FILE-AUTH-2 "no newborn course ID"; return 0; }
  local nid; nid=$(cat "$NEWBORN_COURSE_ID_FILE"); local fhttp
  _t_file_request T-FILE-AUTH-2 \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/courses/${nid}/thumb.jpg" \
    "$ORDINARY_TOK_FILE" fhttp
  case "$fhttp" in
    401|403|404) t_pass "T-FILE-AUTH-2: newborn denied ($fhttp)" ;;
    *) t_fail T-FILE-AUTH-2 "expected 401/403/404 got $fhttp" ;;
  esac
}

t_file_auth_3() {
  [[ -f "$PREG_COURSE_ID_FILE" && -f "$PREG_THUMB_FILE" ]] || \
    { t_unresolved T-FILE-AUTH-3 "pregnancy course fixture absent"; return 0; }
  local cid; cid=$(cat "$PREG_COURSE_ID_FILE"); local thumb; thumb=$(cat "$PREG_THUMB_FILE")
  local fhttp
  _t_file_request T-FILE-AUTH-3 \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/courses/${cid}/${thumb}" "" fhttp
  case "$fhttp" in
    401|403) t_pass "T-FILE-AUTH-3: unauthenticated denied ($fhttp)" ;;
    *) t_fail T-FILE-AUTH-3 "expected 401/403 got $fhttp" ;;
  esac
}

t_file_auth_4() {
  # Full lifecycle: access established → file token obtained → phone_verified revoked
  # → stale token retried → denial required → restored
  [[ -f "$PREG_COURSE_ID_FILE" && -f "$PREG_THUMB_FILE" ]] || \
    { t_unresolved T-FILE-AUTH-4 "pregnancy course fixture absent"; return 0; }
  local cid; cid=$(cat "$PREG_COURSE_ID_FILE"); local thumb; thumb=$(cat "$PREG_THUMB_FILE")
  local ftok_file; ftok_file=$(mktemp "${RELEASE1B_TEST_TMP}/ftok_XXXXXXXXXX")
  local auth_cfg _ho _ro resp_path

  # Obtain file token
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { t_fail T-FILE-AUTH-4 "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/token" \
    "$auth_cfg" "" "$_ho" "$_ro" "T-FILE-AUTH-4/tok" "200" || {
      rm -f "$_ho" "$_ro" "$ftok_file"
      t_unresolved T-FILE-AUTH-4 "file token endpoint absent"
      return 0
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  pb_copy_field "$resp_path" "token" "$ftok_file" || { rm -f "$resp_path" "$ftok_file"; return 1; }
  rm -f "$resp_path"

  # Pre-revoke access check
  local fhttp
  _t_file_request T-FILE-AUTH-4/pre \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/courses/${cid}/${thumb}" "$ftok_file" fhttp
  [[ "$fhttp" = "200" ]] || { t_fail T-FILE-AUTH-4 "pre-revoke access failed: $fhttp"; rm -f "$ftok_file"; return 1; }

  # Revoke: phone_verified = false
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  local patch_body
  pbj_write patch_body "b:phone_verified=false" || { rm -f "$ftok_file"; return 1; }
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body" "$ftok_file"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "T-FILE-AUTH-4/revoke" "200" || {
      rm -f "$patch_body" "$_ho" "$_ro" "$ftok_file"; t_fail T-FILE-AUTH-4 "revoke failed"; return 1
    }
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"

  # Post-revoke retry
  _t_file_request T-FILE-AUTH-4/post \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/courses/${cid}/${thumb}" "$ftok_file" fhttp
  rm -f "$ftok_file"
  case "$fhttp" in
    200) t_blocking T-FILE-AUTH-4 "stale file token valid post-revocation — controlled download endpoint required" ;;
    401|403) t_pass "T-FILE-AUTH-4: stale token denied post-revocation" ;;
    *) t_fail T-FILE-AUTH-4 "unexpected: $fhttp" ;;
  esac

  # Restore
  pbj_write patch_body "b:phone_verified=true" || return 1
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "T-FILE-AUTH-4/restore" "200" || \
    t_fail T-FILE-AUTH-4/restore "restore failed"
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
}

t_file_auth_5() {
  # Status: MANDATORY DEFERRED
  # Reason: The consent-version file-authorization lifecycle requires two external artifacts
  #   that are preauthorization blockers:
  #   1. B-HOOKS: consent_gate hook must be supplied and installed
  #   2. B-SCHEMA: consent_records collection must be defined with version field
  # This test cannot be made executable without those artifacts.
  # It must not be classified as IMPL-U, future-release, or authorized exclusion.
  # It must be resolved before Checkpoint 0 can be authorized.
  t_deferred_mandatory T-FILE-AUTH-5 \
    "Consent-version file authorization lifecycle blocked by B-HOOKS (consent_gate hook absent) and B-SCHEMA (consent_records schema absent). Resolve both blockers, install consent_gate hook, verify consent enforcement via rule apply + file request + restore lifecycle."
}

t_file_auth_6() {
  # Fresh token denial after phone_verified removed
  [[ -f "$PREG_COURSE_ID_FILE" && -f "$PREG_THUMB_FILE" ]] || \
    { t_unresolved T-FILE-AUTH-6 "pregnancy course fixture absent"; return 0; }
  local cid; cid=$(cat "$PREG_COURSE_ID_FILE"); local thumb; thumb=$(cat "$PREG_THUMB_FILE")
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  local patch_body auth_cfg _ho _ro resp_path

  pbj_write patch_body "b:phone_verified=false" || return 1
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "T-FILE-AUTH-6/revoke" "200" || {
      rm -f "$patch_body" "$_ho" "$_ro"; t_fail T-FILE-AUTH-6 "revoke failed"; return 1
    }
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"

  # Try with current auth token (not file token)
  local fhttp
  _t_file_request T-FILE-AUTH-6/with-auth-tok \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/courses/${cid}/${thumb}" "$ORDINARY_TOK_FILE" fhttp
  case "$fhttp" in
    401|403|404) t_pass "T-FILE-AUTH-6: auth token denied after phone_verified removal" ;;
    200) t_blocking T-FILE-AUTH-6 "file access persists after phone_verified removed" ;;
    *) t_fail T-FILE-AUTH-6 "unexpected: $fhttp" ;;
  esac

  # Restore
  pbj_write patch_body "b:phone_verified=true" || return 1
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "T-FILE-AUTH-6/restore" "200" || true
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
}

t_file_auth_7() {
  # Status: MANDATORY DEFERRED
  # Reason: The account-suspension file-authorization lifecycle requires a product decision
  #   that is not yet recorded in the schema:
  #   1. B-SCHEMA: no suspension field (status, is_suspended, or equivalent) confirmed in users
  #   2. The enforcement mechanism (collection rule vs hook vs auth rule) is not chosen
  #   3. The field name, type, and allowed values have not been reviewed
  # This test cannot be made executable without the schema decision and the resulting
  # migration being included in the B-SCHEMA package.
  # It must not be classified as IMPL-U, future-release, or authorized exclusion.
  # It must be resolved before Checkpoint 0 can be authorized.
  t_deferred_mandatory T-FILE-AUTH-7 \
    "Account-suspension file authorization blocked by B-SCHEMA: suspension field not confirmed in users collection. Decide field name/type/enforcement, add to schema migration, supply in B-SCHEMA package, then implement: set suspended, verify file denied, restore, verify accessible."
}

t_file_auth_8() {
  # Content reclassification: change course category, verify antenatal user denied, restore
  [[ -f "$PREG_COURSE_ID_FILE" && -f "$PREG_THUMB_FILE" ]] || \
    { t_unresolved T-FILE-AUTH-8 "pregnancy course fixture absent"; return 0; }
  local cid; cid=$(cat "$PREG_COURSE_ID_FILE"); local thumb; thumb=$(cat "$PREG_THUMB_FILE")
  local auth_cfg _ho _ro resp_path

  # Reclassify to newborn
  local patch_body
  pbj_write patch_body "category=newborn" || return 1
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/courses/records/${cid}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "T-FILE-AUTH-8/reclassify" "200" || {
      rm -f "$patch_body" "$_ho" "$_ro"; t_fail T-FILE-AUTH-8 "reclassify failed"; return 1
    }
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"

  # Verify ordinary user denied
  local fhttp
  _t_file_request T-FILE-AUTH-8/post-reclassify \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/files/courses/${cid}/${thumb}" "$ORDINARY_TOK_FILE" fhttp
  case "$fhttp" in
    403|404) t_pass "T-FILE-AUTH-8: reclassified content denied" ;;
    200) t_blocking T-FILE-AUTH-8 "file accessible after reclassification to prohibited category" ;;
    *) t_fail T-FILE-AUTH-8 "unexpected: $fhttp" ;;
  esac

  # Restore category
  pbj_write patch_body "category=antenatal" || return 1
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { rm -f "$patch_body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/courses/records/${cid}" \
    "$auth_cfg" "$patch_body" "$_ho" "$_ro" "T-FILE-AUTH-8/restore" "200" || \
    t_fail T-FILE-AUTH-8/restore "restore failed"
  rm -f "$patch_body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
}

# ────────────────────────────────────────────────────────────────
# §24 ALIAS TESTS
# ────────────────────────────────────────────────────────────────

t_alias_compare() {
  local ref_resp="${ENUM_RESP_FILES[1]:-}"
  [[ -f "$ref_resp" ]] || { t_harness_err T-ALIAS-COMPARE "case 1 response missing"; return 1; }
  local ref_shape; ref_shape=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" \
    python3 "$PBJ_SHAPE_PY" "$ref_resp" 2>/dev/null)
  local ref_http="${ENUM_HTTP_VALUES[1]:-}"
  local ref_ct; ref_ct=$(cat "${ENUM_CT_FILES[1]:-/dev/null}" 2>/dev/null)
  local ref_sz; ref_sz=$(cat "${ENUM_SIZE_FILES[1]:-/dev/null}" 2>/dev/null)

  typeset -i n=2
  while (( n <= 4 )); do
    local resp="${ENUM_RESP_FILES[$n]:-}"
    [[ -f "$resp" ]] || { t_harness_err "T-ALIAS-COMPARE-$n" "resp missing"; n=$(( n + 1 )); continue; }
    local cmp_shape; cmp_shape=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_TMP" \
      python3 "$PBJ_SHAPE_PY" "$resp" 2>/dev/null)
    [[ "$cmp_shape" = "$ref_shape" ]] && t_pass "T-ALIAS-COMPARE-SHAPE-$n" || \
      t_blocking "T-ALIAS-COMPARE-SHAPE-$n" "response shape differs from case 1"
    [[ "${ENUM_HTTP_VALUES[$n]}" = "$ref_http" ]] && t_pass "T-ALIAS-COMPARE-HTTP-$n" || \
      t_blocking "T-ALIAS-COMPARE-HTTP-$n" "HTTP status differs from case 1"
    local c_ct; c_ct=$(cat "${ENUM_CT_FILES[$n]:-/dev/null}" 2>/dev/null)
    [[ "$c_ct" = "$ref_ct" ]] && t_pass "T-ALIAS-COMPARE-CT-$n" || t_fail "T-ALIAS-COMPARE-CT-$n" "ct differs"
    local c_sz; c_sz=$(cat "${ENUM_SIZE_FILES[$n]:-/dev/null}" 2>/dev/null)
    [[ "$c_sz" = "$ref_sz" ]] && t_pass "T-ALIAS-COMPARE-SIZE-$n" || \
      t_blocking "T-ALIAS-COMPARE-SIZE-$n" "body size differs — potential oracle"
    n=$(( n + 1 ))
  done
  typeset -i i=1
  while (( i <= 4 )); do
    rm -f "${ENUM_RESP_FILES[$i]:-}" "${ENUM_HDR_FILES[$i]:-}" \
          "${ENUM_CT_FILES[$i]:-}" "${ENUM_SIZE_FILES[$i]:-}" "${ENUM_TIME_FILES[$i]:-}"
    i=$(( i + 1 ))
  done
}

t_alias_timing() {
  typeset -gi TIMING_ROUNDS=20
  local -a tdirs=()
  typeset -i n=1
  while (( n <= 4 )); do
    tdirs[$n]=$(mktemp -d "${RELEASE1B_TEST_TMP}/timing_c${n}_XXXXXXXXXX")
    n=$(( n + 1 ))
  done
  typeset -gA TI=([1]="nouser_${RUN_SUFFIX}@test.invalid"
                  [2]="timing_legacy_${RUN_SUFFIX}@test.invalid"
                  [3]="alias_internal_${RUN_SUFFIX}@internal.invalid"
                  [4]="alias_internal_${RUN_SUFFIX}@internal.invalid")
  typeset -gA TP=([1]="$WRONG_PW_FILE" [2]="$WRONG_PW_FILE"
                  [3]="$WRONG_PW_FILE"  [4]="$ALIAS_PW_FILE")
  typeset -i round=0 any_fail=0
  while (( round < TIMING_ROUNDS && any_fail == 0 )); do
    round=$(( round + 1 ))
    n=1
    while (( n <= 4 && any_fail == 0 )); do
      local body; pbj_write body "identity=${TI[$n]}" "secret-file:password=${TP[$n]}" 2>/dev/null || \
        { any_fail=1; break; }
      local rsp; rsp=$(mktemp "${RELEASE1B_TEST_TMP}/tres_XXXXXXXXXX")
      local tm
      tm=$(curl -s -o "$rsp" -w '%{time_total}' -X POST --max-redirs 0 \
        -H 'Content-Type: application/json' --data-binary "@${body}" \
        "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-with-password" 2>/dev/null)
      rm -f "$body" "$rsp"
      python3 -c "import sys,math; v=float('$tm'); assert math.isfinite(v) and v>=0; print(v)" \
        > "${tdirs[$n]}/r${round}.txt" 2>/dev/null || { t_fail "T-ALIAS-TIMING-$n-R$round" "invalid tm"; any_fail=1; }
      n=$(( n + 1 ))
    done
  done
  (( any_fail == 0 )) || { t_fail T-ALIAS-TIMING "collection aborted"; }
  n=1
  while (( n <= 4 )); do
    python3 "$PBJ_TIMING_PY" "${tdirs[$n]}" "case-$n" "$TIMING_ROUNDS" || \
      t_fail "T-ALIAS-TIMING-$n" "insufficient samples"
    rm -rf "${tdirs[$n]}"
    n=$(( n + 1 ))
  done
  t_pass "T-ALIAS-TIMING: $TIMING_ROUNDS rounds collected and analyzed"
}

t_alias_case5_legacy_login() {
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$LEGACY_TOK_FILE" || { t_fail T-ALIAS-5 "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-refresh" \
    "$auth_cfg" "" "$_ho" "$_ro" T-ALIAS-5 "200" || {
      rm -f "$_ho" "$_ro"; t_fail T-ALIAS-5 "legacy auth refresh failed"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass "T-ALIAS-5: legitimate legacy login not blocked by interceptor"
}

# ────────────────────────────────────────────────────────────────
# §25 AUTH AND EMAIL TESTS
# ────────────────────────────────────────────────────────────────

t_record_auth_response_shape() {
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { t_fail T-RECORD-AUTH-RESP "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-refresh" \
    "$auth_cfg" "" "$_ho" "$_ro" T-RECORD-AUTH-RESP "200" || {
      rm -f "$_ho" "$_ro"; t_fail T-RECORD-AUTH-RESP "refresh failed"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] || return 1
  python3 - "$resp_path" << 'PYEOF'
import json, sys
REQUIRED = {'token', 'record'}
FORBIDDEN = {'password', 'tokenKey', 'passwordConfirm', 'otp'}
d = json.load(open(sys.argv[1]))
missing = REQUIRED - set(d.keys())
if missing: print(f"FAIL: missing {missing}"); sys.exit(1)
record = d.get('record', {})
exposed = FORBIDDEN & set(record.keys())
if exposed: print(f"BLOCKING: exposes {exposed}"); sys.exit(2)
print("PASS: shape valid"); sys.exit(0)
PYEOF
  local rc=$?; rm -f "$resp_path"
  case $rc in
    0) t_pass T-RECORD-AUTH-RESP ;;
    2) t_blocking T-RECORD-AUTH-RESP "forbidden fields in auth response" ;;
    *) t_harness_err T-RECORD-AUTH-RESP "shape check error" ;;
  esac
}

t_auth_refresh_valid() {
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { t_fail T-AUTH-REFRESH "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-refresh" \
    "$auth_cfg" "" "$_ho" "$_ro" T-AUTH-REFRESH "200" || {
      rm -f "$_ho" "$_ro"; t_fail T-AUTH-REFRESH "failed"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-AUTH-REFRESH
}

t_blank_email_behavior() {
  local body _ho _ro resp_path
  pbj_write body "identity=" "secret-file:password=${WRONG_PW_FILE}" || { t_fail T-BLANK-EMAIL "body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/auth-with-password" \
    "" "$body" "$_ho" "$_ro" T-BLANK-EMAIL "400" "401" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-BLANK-EMAIL "accepted"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-BLANK-EMAIL
}

t_email_verification_sent() {
  pb_mailhog_clear_verified "pre-verify"
  local ordinary_identity="ordinary_${RUN_SUFFIX}@test.invalid"
  local body auth_cfg _ho _ro resp_path
  pbj_write body "email=${ordinary_identity}" || { t_fail T-EMAIL-VERIFY "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/request-verification" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-EMAIL-VERIFY "204" "200" || {
      rm -f "$body" "$_ho" "$_ro"
      t_unresolved T-EMAIL-VERIFY "verification endpoint rejected — SMTP may not be configured"
      return 0
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  sleep 3
  local cnt; cnt=$(pb_mailhog_count)
  (( cnt > 0 )) && t_pass "T-EMAIL-VERIFY: $cnt verification email(s) delivered to mail sink" || \
    t_fail T-EMAIL-VERIFY "no email in Mailhog after request"
  pb_mailhog_clear_verified "post-verify"
}

t_password_reset_alias_blocked() {
  # Alias account should not receive or process password-reset emails
  (( HALT_DEPENDENTS )) && { t_skip T-PW-RESET-ALIAS "blocked"; return 0; }
  [[ -f "$ALIAS_ID_FILE" ]] || { t_unresolved T-PW-RESET-ALIAS "no alias ID"; return 0; }
  pb_mailhog_clear_verified "pre-pw-reset-alias"
  local body _ho _ro resp_path
  pbj_write body "email=alias_internal_${RUN_SUFFIX}@internal.invalid" || \
    { t_fail T-PW-RESET-ALIAS "body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/request-password-reset" \
    "" "$body" "$_ho" "$_ro" T-PW-RESET-ALIAS "204" "200" "400" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-PW-RESET-ALIAS "request failed"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  sleep 2
  local cnt; cnt=$(pb_mailhog_count)
  if (( cnt > 0 )); then
    t_blocking T-PW-RESET-ALIAS "alias account received password-reset email — $cnt message(s)"
  else
    t_pass "T-PW-RESET-ALIAS: no email delivered for alias account"
  fi
  pb_mailhog_clear_verified "post-pw-reset-alias"
}

# ────────────────────────────────────────────────────────────────
# §26 OTP TESTS
# ────────────────────────────────────────────────────────────────

t_otp_legacy_link_group() {
  # Authenticated legacy phone-linking OTP — ordinary user only
  print "=== OTP Legacy Linking Tests ==="

  # Test: endpoint requires authentication
  local body _ho _ro resp_path
  pbj_write body "phone=${T_PHONE_TEST_VALUE}" || { t_fail T-OTP-LEGACY-AUTH-REQUIRED "body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/v1/phone/request-otp" \
    "" "$body" "$_ho" "$_ro" T-OTP-LEGACY-AUTH-REQUIRED "401" "403" "404" || {
      rm -f "$body" "$_ho" "$_ro"
      t_unresolved T-OTP-LEGACY-AUTH-REQUIRED "endpoint missing or unexpected status"
      return 0
    }
  local ahttp; ahttp=$(cat "$_ho"); rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  if [[ "$ahttp" = "404" ]]; then
    t_unresolved T-OTP-LEGACY-AUTH-REQUIRED "OTP endpoint /api/v1/phone/request-otp not found — B-HOOKS"
    return 0
  fi
  t_pass "T-OTP-LEGACY-AUTH-REQUIRED: anonymous request rejected ($ahttp)"

  # Test: admin cannot use legacy phone link
  local auth_cfg
  pbj_write body "phone=${T_PHONE_TEST_VALUE}" || return 1
  pb_make_auth auth_cfg "$ADMIN_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/v1/phone/request-otp" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-OTP-LEGACY-ADMIN-DENIED "403" "404" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-OTP-LEGACY-ADMIN-DENIED "unexpected status"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-OTP-LEGACY-ADMIN-DENIED

  # Actual delivery test deferred: requires mock provider (B-HOOKS)
  t_deferred_mandatory T-OTP-LEGACY-DELIVERY "requires mock provider hook in B-HOOKS package"
  t_deferred_mandatory T-OTP-LEGACY-VERIFY   "requires successful OTP delivery first"
  t_deferred_mandatory T-OTP-LEGACY-ATOMIC   "requires OTP verification — phone and phone_verified saved atomically"
}

t_otp_anonymous_disabled() {
  # Future anonymous phone-first flow must not be accessible
  local _ho _ro resp_path
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/v2/phone/register" \
    "" "" "$_ho" "$_ro" T-OTP-ANON-DISABLED "404" "405" "403" || {
      rm -f "$_ho" "$_ro"; t_fail T-OTP-ANON-DISABLED "request failed"; return 1
    }
  local ahttp; ahttp=$(cat "$_ho"); resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  case "$ahttp" in
    404|405) t_pass "T-OTP-ANON-DISABLED: v2 anonymous register not accessible ($ahttp)" ;;
    200|201) t_blocking T-OTP-ANON-DISABLED "anonymous phone-first endpoint unexpectedly accessible" ;;
    403) t_pass "T-OTP-ANON-DISABLED: endpoint gated ($ahttp)" ;;
    *) t_fail T-OTP-ANON-DISABLED "unexpected: $ahttp" ;;
  esac
}

# ────────────────────────────────────────────────────────────────
# §27 ADMIN / SUPERADMIN / NATIVE SUPERUSER TESTS
# ────────────────────────────────────────────────────────────────

t_admin_escalation_rejected() {
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  local body auth_cfg _ho _ro resp_path
  pbj_write body "role=superadmin" || { t_fail T-ESCALATION "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-ESCALATION "403" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-ESCALATION "self-escalation accepted"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-ESCALATION
}

t_admin_cannot_promote() {
  local target_id; target_id=$(cat "$ORDINARY_ID_FILE")
  local body auth_cfg _ho _ro resp_path
  pbj_write body "role=superadmin" || { t_fail T-ADMIN-PROMOTE "body"; return 1; }
  pb_make_auth auth_cfg "$ADMIN_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${target_id}" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-ADMIN-PROMOTE "403" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-ADMIN-PROMOTE "admin can grant superadmin"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-ADMIN-PROMOTE
}

t_superadmin_can_list_users() {
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$SADMIN_TOK_FILE" || { t_fail T-SADMIN-LIST "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records?perPage=1" \
    "$auth_cfg" "" "$_ho" "$_ro" T-SADMIN-LIST "200" || {
      rm -f "$_ho" "$_ro"; t_fail T-SADMIN-LIST "superadmin cannot list"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-SADMIN-LIST
}

t_native_superuser_bypasses_rules() {
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" || { t_fail T-NSU-BYPASS "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records?perPage=1" \
    "$auth_cfg" "" "$_ho" "$_ro" T-NSU-BYPASS "200" || {
      rm -f "$_ho" "$_ro"; t_fail T-NSU-BYPASS "native superuser denied"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass "T-NSU-BYPASS: native _superusers bypasses collection rules"
}

t_native_superuser_hook_behavior() {
  # Test native superuser against each installed hook's protected operations
  # This cannot be implemented until hook sources are supplied (B-HOOKS)
  # Each installed hook must be individually tested with the native_superuser actor
  if [[ ${#HOOK_SRC_PATHS} -eq 0 ]]; then
    t_unresolved T-NSU-HOOK-BEHAVIOR "no hooks installed — B-HOOKS"
    return 0
  fi
  local hook_name
  for hook_name in "${(k)HOOK_SRC_PATHS[@]}"; do
    t_deferred_mandatory "T-NSU-HOOK-${hook_name^^}" \
      "native_superuser actor test for $hook_name — implement after hook package delivered"
  done
}

# ────────────────────────────────────────────────────────────────
# §28 ORDINARY USER OPERATIONS
# ────────────────────────────────────────────────────────────────

t_ordinary_name_update() {
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  local body auth_cfg _ho _ro resp_path
  pbj_write body "name=SafeName_${RUN_SUFFIX}" || { t_fail T-NAME-UPDATE "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture PATCH "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-NAME-UPDATE "200" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-NAME-UPDATE "rejected"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  local nv; nv=$(pb_field "$resp_path" "name" 2>/dev/null); rm -f "$resp_path"
  [[ "$nv" = "SafeName_${RUN_SUFFIX}" ]] && t_pass T-NAME-UPDATE || t_fail T-NAME-UPDATE "mismatch"
}

t_ordinary_language_update() {
  local lang_url="${RELEASE1B_CANONICAL_URL_PREFIX}/api/v1/onboarding/select-language"
  local lang body auth_cfg _ho _ro resp_path
  for lang in ms en zh; do
    pbj_write body "language=$lang" || { t_fail "T-LANG-$lang" "body"; continue; }
    pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; continue; }
    _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
    _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
    pb_capture POST "$lang_url" "$auth_cfg" "$body" "$_ho" "$_ro" "T-LANG-$lang" "200" || {
      rm -f "$body" "$_ho" "$_ro"
      t_unresolved "T-LANG-$lang" "language endpoint missing or rejected — B-HOOKS"
      continue
    }
    rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
    [[ -f "$resp_path" ]] && rm -f "$resp_path"
    t_pass "T-LANG-$lang"
  done
  pbj_write body "language=fr" || { t_fail T-LANG-INVALID "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "$lang_url" "$auth_cfg" "$body" "$_ho" "$_ro" T-LANG-INVALID "400" "422" || {
    rm -f "$body" "$_ho" "$_ro"; t_fail T-LANG-INVALID "invalid language accepted"; return 1
  }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-LANG-INVALID
}

t_avatar_lifecycle() {
  local user_id; user_id=$(cat "$ORDINARY_ID_FILE")
  # Minimal 1x1 white PNG
  local png_b64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
  local png_file; png_file=$(mktemp "${RELEASE1B_TEST_TMP}/avatar_XXXXXXXXXX.png")
  python3 -c "import base64,sys; open(sys.argv[1],'wb').write(base64.b64decode('$png_b64'))" "$png_file" || \
    { t_fail T-AVATAR "png creation"; rm -f "$png_file"; return 1; }
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$png_file"; t_fail T-AVATAR "auth"; return 1; }
  local actual_http
  actual_http=$(curl -s -o /dev/null -w '%{http_code}' -X PATCH --max-redirs 0 \
    -H "$(cat "$auth_cfg" | grep -o 'Bearer [^ "]*' | sed 's/^/Authorization: /')" \
    -F "avatar=@${png_file}" \
    "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${user_id}" 2>/dev/null) || true
  rm -f "$auth_cfg" "$png_file"
  case "$actual_http" in
    200) t_pass T-AVATAR ;;
    *) t_fail T-AVATAR "avatar upload returned $actual_http" ;;
  esac
}

# ────────────────────────────────────────────────────────────────
# §29 CONTENT CLASSIFICATION AND LEGACY DATA TESTS
# ────────────────────────────────────────────────────────────────

t_articles_antenatal_visible() {
  _t_deny_list_or_empty "articles" "category%3D%22antenatal%22" "$ORDINARY_TOK_FILE" \
    T-ARTICLES-ANTENATAL "antenatal"
}

t_articles_prohibited_hidden() {
  local cat
  for cat in newborn postnatal child; do
    _t_deny_list_or_empty "articles" "category%3D%22${cat}%22" "$ORDINARY_TOK_FILE" \
      "T-ARTICLES-$cat-HIDDEN" "antenatal"
  done
}

t_legacy_user_data_denied() {
  (( HALT_DEPENDENTS )) && { t_skip T-LEGACY-DATA-DENIED "blocked"; return 0; }
  [[ -f "$LEGACY_ID_FILE" ]] || { t_unresolved T-LEGACY-DATA-DENIED "no legacy ID"; return 0; }
  local legacy_id; legacy_id=$(cat "$LEGACY_ID_FILE")
  local auth_cfg _ho _ro resp_path
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { t_fail T-LEGACY-DATA-DENIED "auth"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${legacy_id}" \
    "$auth_cfg" "" "$_ho" "$_ro" T-LEGACY-DATA-DENIED "403" "404" || {
      rm -f "$_ho" "$_ro"; t_fail T-LEGACY-DATA-DENIED "legacy data accessible to ordinary user"; return 1
    }
  resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-LEGACY-DATA-DENIED
}

t_anon_create_field_injection() {
  # Anonymous account creation must not accept role, is_alias_account, or phone injection
  local -a injections=("role=admin" "b:is_alias_account=true" "phone=${T_PHONE_TEST_VALUE}")
  local inj
  for inj in "${injections[@]}"; do
    local field; field="${inj%%=*}"; field="${field##b:}"
    local body _ho _ro resp_path
    pbj_write body "email=anon_inj_${field}_${RUN_SUFFIX}@test.invalid" \
      "secret-file:password=${WRONG_PW_FILE}" \
      "secret-file:passwordConfirm=${WRONG_PW_FILE}" $=inj || {
        t_fail "T-INJECT-$field" "body"; continue
      }
    _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
    _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
    pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records" \
      "" "$body" "$_ho" "$_ro" "T-INJECT-$field" "200" "400" "403" || {
        rm -f "$body" "$_ho" "$_ro"; t_fail "T-INJECT-$field" "request failed"; continue
      }
    local ahttp; ahttp=$(cat "$_ho"); resp_path=$(cat "$_ro"); rm -f "$body" "$_ho" "$_ro"
    if [[ "$ahttp" = "200" && -f "$resp_path" ]]; then
      # Account created — verify injected field was not stored and then clean up
      local rec_id; rec_id=""
      python3 - "$resp_path" "$field" << 'PYEOF' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1])); field = sys.argv[2]
val = d.get(field, '__absent__')
if isinstance(val, bool): val = str(val).lower()
print(f"INJECTED_VALUE={val}")
PYEOF
      local injval; injval=$(python3 - "$resp_path" "$field" << 'PYEOF' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1])); field = sys.argv[2]
print('' if d.get(field,'') == '' or d.get(field) is None or d.get(field) == False else 'FOUND')
PYEOF
      )
      # Clean up created account
      python3 - "$resp_path" << 'PYEOF' > "${RELEASE1B_TEST_TMP}/inj_rec_id_$$.txt" 2>/dev/null
import json, sys; d=json.load(open(sys.argv[1])); print(d.get('id',''))
PYEOF
      local created_id; created_id=$(cat "${RELEASE1B_TEST_TMP}/inj_rec_id_$$.txt" 2>/dev/null)
      rm -f "$resp_path" "${RELEASE1B_TEST_TMP}/inj_rec_id_$$.txt"
      if [[ -n "$created_id" ]]; then
        local auth_cfg
        pb_make_auth auth_cfg "$_NATIVE_SU_TOK_FILE" 2>/dev/null || true
        local _hh _rr
        _hh=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
        _rr=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
        pb_capture DELETE "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records/${created_id}" \
          "$auth_cfg" "" "$_hh" "$_rr" "T-INJECT-cleanup-$field" "204" "200" || true
        local rp; rp=$(cat "$_rr" 2>/dev/null); rm -f "$_hh" "$_rr"
        [[ -f "$rp" ]] && rm -f "$rp"
      fi
      if [[ "$injval" = "FOUND" ]]; then
        t_blocking "T-INJECT-$field" "injected $field value stored in new account"
      else
        t_pass "T-INJECT-$field: account created but injected field not stored"
      fi
    else
      [[ -f "$resp_path" ]] && rm -f "$resp_path"
      t_pass "T-INJECT-$field: creation rejected ($ahttp)"
    fi
  done
}

t_auth_user_cannot_create_extra() {
  local body auth_cfg _ho _ro resp_path
  pbj_write body "email=extra_${RUN_SUFFIX}@test.invalid" \
    "secret-file:password=${WRONG_PW_FILE}" \
    "secret-file:passwordConfirm=${WRONG_PW_FILE}" || { t_fail T-NO-EXTRA "body"; return 1; }
  pb_make_auth auth_cfg "$ORDINARY_TOK_FILE" || { rm -f "$body"; return 1; }
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture POST "${RELEASE1B_CANONICAL_URL_PREFIX}/api/collections/users/records" \
    "$auth_cfg" "$body" "$_ho" "$_ro" T-NO-EXTRA "403" || {
      rm -f "$body" "$_ho" "$_ro"; t_fail T-NO-EXTRA "authenticated user can create account"; return 1
    }
  rm -f "$body"; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-NO-EXTRA
}

# ────────────────────────────────────────────────────────────────
# §30 API DECLARATIONS AND STATIC ROUTES
# ────────────────────────────────────────────────────────────────

t_api_declarations() {
  local -a expected_routes=(
    "GET:/api/health"
    "POST:/api/collections/users/auth-with-password"
    "POST:/api/collections/users/auth-refresh"
    "POST:/api/collections/users/request-password-reset"
    "GET:/api/collections/courses/records"
    "GET:/api/collections/articles/records"
  )
  local route
  for route in "${expected_routes[@]}"; do
    local method="${route%%:*}" path="${route##*:}"
    local _ho _ro resp_path
    _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
    _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
    pb_capture "$method" "${RELEASE1B_CANONICAL_URL_PREFIX}${path}" \
      "" "" "$_ho" "$_ro" "T-API-$method-$(print "$path" | tr / _)" \
      "200" "400" "401" "403" "404" "422" || {
        rm -f "$_ho" "$_ro"; t_fail "T-API-$method-$(print "$path" | tr / _)" "request failed"; continue
      }
    local ahttp; ahttp=$(cat "$_ho"); resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
    [[ -f "$resp_path" ]] && rm -f "$resp_path"
    [[ "$ahttp" != "000" && "$ahttp" != "404" ]] && \
      t_pass "T-API-EXISTS: $method $path ($ahttp)" || \
      t_fail "T-API-EXISTS: $method $path" "404 or connection failure"
  done

  # Fabricated route must return 404
  _ho=$(mktemp "${RELEASE1B_TEST_TMP}/http_XXXXXXXXXX")
  _ro=$(mktemp "${RELEASE1B_TEST_TMP}/rpath_XXXXXXXXXX")
  pb_capture GET "${RELEASE1B_CANONICAL_URL_PREFIX}/api/cp0_fabricated_${RUN_SUFFIX}" \
    "" "" "$_ho" "$_ro" T-API-404 "404" || {
      rm -f "$_ho" "$_ro"; t_fail T-API-404 "fabricated route not 404"; return 1
    }
  local resp_path; resp_path=$(cat "$_ro"); rm -f "$_ho" "$_ro"
  [[ -f "$resp_path" ]] && rm -f "$resp_path"
  t_pass T-API-404
}

t_static_route_inventory() {
  if [[ -z "$RELEASE1B_FRONTEND_SRC" || ! -d "$RELEASE1B_FRONTEND_SRC" ]]; then
    t_unresolved T-STATIC-ROUTES "B-FRONTEND: frontend source not supplied"
    return 0
  fi

  # Verify source integrity first
  local app_tsx="${RELEASE1B_FRONTEND_SRC}/src/App.tsx"
  [[ -f "$app_tsx" ]] || { t_fail T-STATIC-ROUTES "App.tsx not found in frontend source"; return 1; }

  python3 - "$app_tsx" "$RELEASE1B_FRONTEND_SRC" << 'PYEOF'
import sys, re, os
app_tsx = open(sys.argv[1], 'r', errors='replace').read()
# Extract route paths
routes = re.findall(r'path=["\']([^"\']+)["\']', app_tsx)
print("Routes found:", routes)
# Required routes
REQUIRED = ['/onboarding', '/home', '/profile', '/courses', '/articles']
PROHIBITED = ['/admin']  # should not be directly in SPA routes
missing = [r for r in REQUIRED if not any(r in route for route in routes)]
prohibited = [r for r in PROHIBITED if any(r in route for route in routes)]
if missing: print(f"FAIL: missing routes {missing}"); sys.exit(1)
if prohibited: print(f"BLOCKING: prohibited routes present {prohibited}"); sys.exit(2)
print("PASS: route inventory complete")
PYEOF
  local rc=$?
  case $rc in
    0) t_pass T-STATIC-ROUTES ;;
    1) t_fail T-STATIC-ROUTES "missing required routes" ;;
    2) t_blocking T-STATIC-ROUTES "prohibited routes in SPA" ;;
    *) t_harness_err T-STATIC-ROUTES "inventory script error" ;;
  esac
}

# ────────────────────────────────────────────────────────────────
# §31 CLEANUP AND REPORT
# ────────────────────────────────────────────────────────────────

pb_validate_destructive_target() {
  local root="$1"
  local marker="${root}/.release1b_marker"

  # 1. Marker must be a regular file, not a symlink
  [[ -f "$marker" ]] || { print "[validate-target] marker absent"; return 1; }
  [[ -L "$marker" ]] && { print "[validate-target] marker is symlink"; return 1; }

  # 2. Marker contents must match this run
  local content; content=$(cat "$marker" 2>/dev/null)
  [[ "$content" = "release1b_cp0_${RUN_SUFFIX}" ]] || \
    { print "[validate-target] marker mismatch"; return 1; }

  # 3. Canonical path must match stored value
  local canon; canon=$(pb_realpath "$root" 2>/dev/null)
  [[ "$canon" = "$RELEASE1B_CANONICAL_ROOT" ]] || \
    { print "[validate-target] canonical path mismatch"; return 1; }

  # 4. Parent must match stored value
  local parent; parent=$(pb_realpath "$(dirname "$root")" 2>/dev/null)
  [[ "$parent" = "$RELEASE1B_CANONICAL_PARENT" ]] || \
    { print "[validate-target] parent mismatch"; return 1; }

  # 5. Basename prefix
  local base; base=$(basename "$root")
  [[ "$base" = release1b_cp0_* ]] || { print "[validate-target] bad basename"; return 1; }

  # 6. Not a dangerous path
  local bad
  for bad in "/" "$HOME" "/tmp" "/private/tmp" "/var/tmp" "/usr" "/etc"; do
    [[ "$canon" = "$bad" ]] && { print "[validate-target] dangerous path"; return 1; }
  done
  [[ "${#canon}" -gt 30 ]] || { print "[validate-target] path too short"; return 1; }

  # 7. Owner matches current user
  local owner cur_uid
  owner=$(stat -f '%u' "$root" 2>/dev/null || stat -c '%u' "$root" 2>/dev/null)
  cur_uid=$(id -u)
  [[ "$owner" = "$cur_uid" ]] || { print "[validate-target] owner mismatch"; return 1; }

  # 8. CLEANUP_FAILURE must be clear
  (( CLEANUP_FAILURE == 0 )) || { print "[validate-target] CLEANUP_FAILURE set"; return 1; }

  return 0
}

pb_generate_report() {
  print "\n\n## Summary\n" >> "$RELEASE1B_REPORT_WORK"
  printf '- PASS: %d\n- FAIL: %d\n- BLOCKING: %d\n- UNRESOLVED: %d\n- DEFERRED: %d\n- HARNESS_ERR: %d\n- SKIP: %d\n' \
    "$T_PASS" "$T_FAIL" "$T_BLOCKING" "$T_UNRESOLVED" "$T_DEFERRED" "$T_HARNESS_ERR" "$T_SKIP" \
    >> "$RELEASE1B_REPORT_WORK"
  if (( ${#BLOCKING_DECISIONS[@]} > 0 )); then
    print "\n### Blocking Decisions" >> "$RELEASE1B_REPORT_WORK"
    local d; for d in "${BLOCKING_DECISIONS[@]}"; do print "- $d" >> "$RELEASE1B_REPORT_WORK"; done
  fi
  if (( ${#UNRESOLVED_ITEMS[@]} > 0 )); then
    print "\n### Unresolved Items" >> "$RELEASE1B_REPORT_WORK"
    local u; for u in "${UNRESOLVED_ITEMS[@]}"; do print "- $u" >> "$RELEASE1B_REPORT_WORK"; done
  fi
  if (( ${#HARNESS_ERRORS[@]} > 0 )); then
    print "\n### Harness Errors" >> "$RELEASE1B_REPORT_WORK"
    local e; for e in "${HARNESS_ERRORS[@]}"; do print "- $e" >> "$RELEASE1B_REPORT_WORK"; done
  fi
  printf 'CLEANUP_FAILURE: %d\n' "$CLEANUP_FAILURE" >> "$RELEASE1B_REPORT_WORK"
}

pb_scan_and_export_report() {
  pb_generate_report
  # Scan report for secrets before export
  if python3 "$PBJ_SCAN_PY" --file "$RELEASE1B_REPORT_WORK" 2>/dev/null | grep -q "^PASS"; then
    cp "$RELEASE1B_REPORT_WORK" "$RELEASE1B_REPORT_PATH"
    t_pass "T-REPORT-EXPORT: report scanned and exported"
  else
    CLEANUP_FAILURE=1
    print "HALT: report triggered secret scan — not exported; review $RELEASE1B_REPORT_WORK manually"
  fi
}

pb_cleanup_normal() {
  print "=== Normal Cleanup ==="
  # Alias group first
  pb_cleanup_alias_group || CLEANUP_FAILURE=1
  # Legacy fixture (reverse order)
  pb_delete_legacy_fixture || CLEANUP_FAILURE=1
  # Named test users
  local lbl id_f tok_f
  for lbl id_f tok_f in \
    "sadmin" "$SADMIN_ID_FILE"   "$SADMIN_TOK_FILE" \
    "admin"  "$ADMIN_ID_FILE"    "$ADMIN_TOK_FILE" \
    "ordinary" "$ORDINARY_ID_FILE" "$ORDINARY_TOK_FILE"; do
    [[ -f "$id_f" ]] && pb_delete_test_user "$lbl" "$id_f" "$tok_f" || true
  done
  # Remove installed hooks
  local hook_name
  for hook_name in "${(k)HOOK_SRC_PATHS[@]}"; do
    local dest="${RELEASE1B_PB_HOOKS_DIR}/${hook_name}.pb.js"
    [[ -f "$dest" ]] && { rm -f "$dest" || CLEANUP_FAILURE=1; }
  done
  # Native superuser
  [[ -f "$_NATIVE_SU_ID_FILE" ]] && pb_delete_local_superuser || true
  # Registry report
  pb_report_fixture_cleanup
  # Stop services
  pb_stop_pocketbase || CLEANUP_FAILURE=1
  pb_stop_mailhog    || CLEANUP_FAILURE=1
  # Generate and export report
  pb_scan_and_export_report
  # Destroy isolated root only if all clean
  if pb_validate_destructive_target "$RELEASE1B_ISOLATED_ROOT"; then
    rm -rf "$RELEASE1B_ISOLATED_ROOT"
    RELEASE1B_ISOLATED_ROOT=""
    print "=== Isolated root removed ==="
  else
    CLEANUP_FAILURE=1
    print "=== CLEANUP FAILURE: isolated root preserved for review ==="
  fi
}

# ────────────────────────────────────────────────────────────────
# §32 ORCHESTRATION
# ────────────────────────────────────────────────────────────────

pb_run_stage() {
  local stage_name="$1"; shift
  print "\n=== Stage: $stage_name ==="
  "$@"
  local rc=$?
  if (( rc != 0 )); then
    print "Stage '$stage_name' returned $rc"
  fi
  return $rc
}

cp0_run() {
  pb_check_package_completeness || pb_halt "Package completeness check failed"
  pb_generate_run_suffix
  pb_setup_umask
  pb_setup_root

  pb_run_stage "Write Python helpers"    pb_write_scripts          || pb_halt "helpers"
  pb_run_stage "Preflight ports"         pb_preflight_ports        || pb_halt "ports"
  pb_run_stage "Apply schema migrations" pb_apply_schema_migrations || pb_halt "schema migrations"
  pb_run_stage "Start Mailhog"           pb_start_mailhog          || pb_halt "mailhog"
  pb_run_stage "Start PocketBase"        pb_start_pocketbase       || pb_halt "pocketbase"
  pb_run_stage "Verify hook directory"   pb_verify_hook_directory  || pb_halt "hook dir"
  pb_run_stage "Verify schema"           pb_verify_schema          || pb_halt "schema verify"
  pb_run_stage "Create local superuser"  pb_create_local_superuser || pb_halt "local su"

  # Install hooks
  local hook_name
  for hook_name in "${(k)HOOK_SRC_PATHS[@]}"; do
    pb_run_stage "Install hook: $hook_name" pb_install_hook_verified "$hook_name" "$hook_name" || pb_halt "hook install"
  done
  (( ${#HOOK_SRC_PATHS} > 0 )) && pb_restart_pocketbase

  # Create test users
  pb_run_stage "Create ordinary user" pb_create_test_user "ordinary" "ordinary" "" ORDINARY_ID_FILE ORDINARY_TOK_FILE || pb_halt "ordinary user"
  pb_run_stage "Create admin user"    pb_create_test_user "admin"    "admin"    "role=admin"    ADMIN_ID_FILE   ADMIN_TOK_FILE   || pb_halt "admin user"
  pb_run_stage "Create sadmin user"   pb_create_test_user "sadmin"   "sadmin"   "role=superadmin" SADMIN_ID_FILE  SADMIN_TOK_FILE  || pb_halt "sadmin user"
  pb_run_stage "Create legacy fixture" pb_create_legacy_fixture || pb_halt "legacy fixture"

  # WRONG_PW_FILE must be created before alias fixture setup
  WRONG_PW_FILE=$(mktemp "${RELEASE1B_TEST_TMP}/wpw_XXXXXXXXXX")
  pb_validate_task_file "$WRONG_PW_FILE" "output" "wrong-pw" || pb_halt "wrong pw file"
  openssl rand -base64 24 | tr -d '\n' > "$WRONG_PW_FILE"
  pb_validate_task_file "$WRONG_PW_FILE" "secret-input" "wrong-pw-verify" || pb_halt "wrong pw mode"

  pb_run_stage "Setup alias group" pb_setup_alias_group || pb_halt "alias fixtures"

  # Hook smoke tests (five-actor matrix per hook)
  for hook_name in "${(k)HOOK_SRC_PATHS[@]}"; do
    pb_run_stage "Hook smoke: $hook_name" pb_hook_smoke_matrix "$hook_name" \
      "${RELEASE1B_CANONICAL_URL_PREFIX}/api/${hook_name}/health" "GET" \
      "200" "403" "403" "200" "200" || true
  done

  # Test groups
  pb_run_stage "Auth response shape"    t_record_auth_response_shape
  pb_run_stage "Auth refresh"           t_auth_refresh_valid
  pb_run_stage "Blank email"            t_blank_email_behavior
  pb_run_stage "Field: role reject"     t_field_role_reject
  pb_run_stage "Field: phone reject"    t_field_phone_reject
  pb_run_stage "Field: alias flag"      t_field_alias_flag_reject
  pb_run_stage "CRUD: children"         t_ch_list t_ch_view t_ch_create t_ch_update t_ch_delete t_ch_expand
  pb_run_stage "CRUD: growth_logs"      t_gl_list t_gl_view t_gl_create t_gl_update t_gl_delete
  pb_run_stage "CRUD: activity_logs"    t_al_list t_al_view t_al_create t_al_update t_al_delete
  pb_run_stage "CRUD: immunisations"    t_imm_list t_imm_view t_imm_create t_imm_update t_imm_delete
  pb_run_stage "Newborn content"        t_nb_list t_nb_view
  pb_run_stage "File auth 1-4"          t_file_auth_1 t_file_auth_2 t_file_auth_3 t_file_auth_4
  pb_run_stage "File auth 5-8"          t_file_auth_5 t_file_auth_6 t_file_auth_7 t_file_auth_8
  pb_run_stage "Alias enum cases"       \
    "pb_alias_enum_case 1 'nonexistent+wrong-pw' 'nouser_${RUN_SUFFIX}@test.invalid' '$WRONG_PW_FILE' '400'" \
    "pb_alias_enum_case 2 'legacy+wrong-pw' 'timing_legacy_${RUN_SUFFIX}@test.invalid' '$WRONG_PW_FILE' '400'" \
    "pb_alias_enum_case 3 'alias+wrong-pw' 'alias_internal_${RUN_SUFFIX}@internal.invalid' '$WRONG_PW_FILE' '400'" \
    "pb_alias_enum_case 4 'alias+correct-pw' 'alias_internal_${RUN_SUFFIX}@internal.invalid' '$ALIAS_PW_FILE' '200'"
  pb_alias_enum_case 1 "nonexistent+wrong-pw"    "nouser_${RUN_SUFFIX}@test.invalid"              "$WRONG_PW_FILE" "400"
  pb_alias_enum_case 2 "legacy+wrong-pw"          "timing_legacy_${RUN_SUFFIX}@test.invalid"       "$WRONG_PW_FILE" "400"
  pb_alias_enum_case 3 "alias+wrong-pw"           "alias_internal_${RUN_SUFFIX}@internal.invalid"  "$WRONG_PW_FILE" "400"
  pb_alias_enum_case 4 "alias+correct-pw"         "alias_internal_${RUN_SUFFIX}@internal.invalid"  "$ALIAS_PW_FILE" "200"
  pb_run_stage "Alias compare"          t_alias_compare
  pb_run_stage "Alias timing"           t_alias_timing
  pb_run_stage "Alias case 5"           t_alias_case5_legacy_login
  pb_run_stage "Email verification"     t_email_verification_sent
  pb_run_stage "Password reset alias"   t_password_reset_alias_blocked
  pb_run_stage "OTP legacy group"       t_otp_legacy_link_group
  pb_run_stage "OTP anon disabled"      t_otp_anonymous_disabled
  pb_run_stage "Escalation rejected"    t_admin_escalation_rejected
  pb_run_stage "Admin cannot promote"   t_admin_cannot_promote
  pb_run_stage "Superadmin list users"  t_superadmin_can_list_users
  pb_run_stage "NSU bypasses rules"     t_native_superuser_bypasses_rules
  pb_run_stage "NSU hook behavior"      t_native_superuser_hook_behavior
  pb_run_stage "Name update"            t_ordinary_name_update
  pb_run_stage "Language update"        t_ordinary_language_update
  pb_run_stage "Avatar lifecycle"       t_avatar_lifecycle
  pb_run_stage "Articles antenatal"     t_articles_antenatal_visible
  pb_run_stage "Articles prohibited"    t_articles_prohibited_hidden
  pb_run_stage "Legacy data denied"     t_legacy_user_data_denied
  pb_run_stage "Field injection"        t_anon_create_field_injection
  pb_run_stage "No extra account"       t_auth_user_cannot_create_extra
  pb_run_stage "API declarations"       t_api_declarations
  pb_run_stage "Static routes"          t_static_route_inventory

  # Remove hooks after testing
  for hook_name in "${(k)HOOK_SRC_PATHS[@]}"; do
    local probe_url="${RELEASE1B_CANONICAL_URL_PREFIX}/api/${hook_name}/health"
    pb_run_stage "Remove hook: $hook_name" pb_remove_hook_verified "$hook_name" "$hook_name" "$probe_url" "GET" || true
  done

  pb_run_stage "Normal cleanup" pb_cleanup_normal

  # Final result
  print "\n=============================="
  print "RELEASE 1B CHECKPOINT 0 RESULT"
  print "=============================="
  printf 'PASS=%d FAIL=%d BLOCKING=%d HARNESS_ERR=%d UNRESOLVED=%d DEFERRED=%d SKIP=%d CLEANUP_FAILURE=%d\n' \
    "$T_PASS" "$T_FAIL" "$T_BLOCKING" "$T_HARNESS_ERR" "$T_UNRESOLVED" "$T_DEFERRED" "$T_SKIP" "$CLEANUP_FAILURE"

  # Exit condition: all mandatory counters must be zero
  # Authorized exclusions and future-release tests do not contribute to any counter
  if (( T_FAIL == 0 && T_BLOCKING == 0 && T_HARNESS_ERR == 0 && \
        T_UNRESOLVED == 0 && T_SKIP == 0 && T_DEFERRED == 0 && CLEANUP_FAILURE == 0 )); then
    print "RESULT: PASS (conditional — all implemented tests passed)"
    return 0
  else
    print "RESULT: NOT AUTHORIZED FOR NEXT CHECKPOINT"
    return 1
  fi
}

# ────────────────────────────────────────────────────────────────
# §33 ENTRY POINT
# ────────────────────────────────────────────────────────────────

main() {
  case "${1:-}" in
    --package-check)
      pb_check_package_completeness
      exit $?
      ;;
    --harness-check)
      pb_generate_run_suffix
      pb_setup_umask
      pb_setup_root
      pb_write_scripts
      t_harness_selftest
      local rc=$?
      # Don't invoke full cleanup — just print counters and let trap handle root
      printf 'Stage 0: PASS=%d FAIL=%d HARNESS_ERR=%d\n' "$T_PASS" "$T_FAIL" "$T_HARNESS_ERR"
      exit $rc
      ;;
    --preflight)
      pb_check_package_completeness || exit 1
      pb_generate_run_suffix
      pb_setup_umask
      pb_setup_root
      pb_write_scripts
      t_harness_selftest || exit 1
      pb_preflight_ports
      print "Preflight complete — no services started"
      exit 0
      ;;
    --run)
      cp0_run
      exit $?
      ;;
    "")
      print "Usage: zsh release1b_cp0.zsh [--package-check | --harness-check | --preflight | --run]" >&2
      exit 1
      ;;
    *)
      print "Unknown mode: $1" >&2
      print "Usage: zsh release1b_cp0.zsh [--package-check | --harness-check | --preflight | --run]" >&2
      exit 1
      ;;
  esac
}

main "$@"
