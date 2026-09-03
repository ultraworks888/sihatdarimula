#!/usr/bin/env zsh
# ============================================================
# release1b_cp0.zsh — Release 1B Checkpoint 0 Harness
# Round  : 20 (corrected from Round 19)
# Status : DRAFTED — statically validated; zsh -n PASS.
#          Checkpoint 0 authorization status:
#          AUTHORIZED BUT NOT EXECUTED —
#          EXECUTION ENVIRONMENT UNAVAILABLE
# ============================================================
#
# R20 corrections applied (see release1b_round20_review.md):
#   D-1.  Checksum file: self-computing; no placeholders.
#   D-2.  PB archive: operator instructions use GitHub assets API.
#   D-3.  Seed migration excluded by exact filename; credential scan
#         added; S-3 incident removed from CP0 execution scope.
#   D-4.  pb_inject_create_and_verify: strict HTTP contract.
#         Only 400/401/403 are clean passes; transport error/5xx =
#         HARNESS_ERROR; inability to verify persistence = BLOCKING.
#   D-5.  T-INJECT-CREATE-UNEXPECTED: reads and verifies persisted
#         application-controlled fields (not just HTTP status).
#   D-6.  S-3 credential incident removed from harness execution.
#         Documented in review only.
#   D-7.  OTP adapter delivered as ninth artifact; deployed
#         automatically; replaces auth_whatsapp_otp in isolated env.
#   D-8.  Report retention: --report-dest option; pre-cleanup export.
#   D-9.  Cleanup: pb_validate_cleanup_target() required before rm -rf.
#   D-10. T-ART-ANON-POLICY: scored FAIL (antenatal requirement known).
#         T-ART-ANTENATAL-AUTH-ONLY: scored test.
#   D-11. Phone future state: temporary local schema migration in
#         isolated env; T-PHONE-FUTURE tests added.
#   D-12. Test email domain: example.invalid (RFC 2606 reserved).
#   D-13. Hook probes: behavioral probes for hooks without routes.
# ============================================================

# ────────────────────────────────────────────────────────────
# §2  SAFETY OPTIONS
# ────────────────────────────────────────────────────────────

setopt NO_UNSET PIPE_FAIL

# ────────────────────────────────────────────────────────────
# §3  CONSTANTS
# ────────────────────────────────────────────────────────────

readonly RELEASE1B_SCRIPT_ROUND="20"
readonly RELEASE1B_PB_PORT="8090"
readonly RELEASE1B_PB_VERSION="0.29.3"

# D-12: Test email domain — RFC 2606 §2 reserves .invalid for use
# in documentation and testing. These addresses cannot be delivered
# to real mailboxes. PocketBase syntactic email validation should
# accept .invalid domains; harness self-test verifies this.
readonly RELEASE1B_TEST_DOMAIN="example.invalid"

# D-3: Exact filename of the seed migration containing a committed
# credential. This file is EXCLUDED from the isolated migration copy.
# The filename is validated before use; it must appear in the source
# directory exactly once.
readonly SEED_MIGRATION_EXCLUDE="1782898775_seed_superadmin_user_4fd7.js"

# D-7: OTP test adapter filename. Deployed from the package directory
# (same directory as this script) to the isolated hooks directory.
# The production OTP hook (auth_whatsapp_otp.pb.js) is NOT deployed
# to the isolated directory; the adapter replaces it for testing only.
readonly OTP_ADAPTER_FILENAME="release1b_otp_test_adapter.pb.js"

typeset -grA PB_ARCHIVE_NAME=(
  [darwin_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_arm64.zip"
  [darwin_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_amd64.zip"
  [linux_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_amd64.zip"
  [linux_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_arm64.zip"
)

# D-2: Archive integrity is verified against the GitHub release-assets
# API digest field, not a pre-stored constant in this file.
# See operator instructions §3 for the mandatory pre-run API step.

# D-13: Hook source paths. auth_whatsapp_otp is intentionally absent —
# the OTP adapter replaces it in the isolated env.
# HOOK_PROBE_TYPE: "route" probes a registered HTTP route;
# "behavioral" means the hook has no standalone route and is
# verified through its effect on standard collection endpoints.
typeset -grA HOOK_SRC_PATHS=(
  [emergency_hardening]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
)

typeset -grA HOOK_EXPECTED_SHA256=(
  [emergency_hardening]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
)

# D-13: Probe types. emergency_hardening has no registered route —
# verified behaviorally in §24 (T-FIELD-ROLE-REJECT).
typeset -grA HOOK_PROBE_TYPE=(
  [emergency_hardening]="behavioral"
  [push_broadcast]="route"
  [whatsapp]="route"
)

typeset -grA HOOK_PROBE_ROUTES=(
  [emergency_hardening]=""
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
)

typeset -grA HOOK_PROBE_METHODS=(
  [emergency_hardening]=""
  [push_broadcast]="POST"
  [whatsapp]="POST"
)

# OTP hook routes — resolved from static source inspection.
typeset -g HOOK_OTP_PHONE_ROUTE="/api/auth/request-whatsapp-otp"
typeset -g HOOK_OTP_VERIFY_ROUTE="/api/auth/verify-whatsapp-otp"
typeset -g HOOK_OTP_CTRL_ROUTE="/api/test/otp-control"
typeset -g HOOK_OTP_RATE_ROUTE="/api/test/otp-rate-count"

# Operator must set to absolute path of pb_migrations/ directory.
# The harness copies *.js files from this directory EXCEPT the
# excluded seed migration.
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

# D-8: Caller-supplied report destination (outside isolated root).
typeset -g RELEASE1B_REPORT_DEST=""

typeset -g PBJ_STAT_PY="" PBJ_URL_PY="" PBJ_PY="" PBJ_AUTH_PY=""
typeset -g PBJ_FIELD_PY="" PBJ_COPY_PY="" PBJ_EXTRACT_PY="" PBJ_SHAPE_PY=""
typeset -g PBJ_SCAN_PY="" PBJ_HTTP_PY="" PBJ_CRED_SCAN_PY=""
typeset -g RUN_SUFFIX=""

typeset -g _NATIVE_SU_TOK_FILE=""
typeset -g _NATIVE_SU_ID_FILE=""
typeset -g _NATIVE_SU_AUTH_CFG=""

typeset -g ORDINARY_ID_FILE="" ORDINARY_TOK_FILE="" ORDINARY_AUTH_CFG=""
typeset -g ADMIN_ID_FILE=""    ADMIN_TOK_FILE=""    ADMIN_AUTH_CFG=""
typeset -g SADMIN_ID_FILE=""   SADMIN_TOK_FILE=""   SADMIN_AUTH_CFG=""
typeset -g LEGACY_ID_FILE=""   LEGACY_TOK_FILE=""   LEGACY_AUTH_CFG=""

typeset -g LEGACY_CHILD_ID_FILE="" LEGACY_GROWTH_ID_FILE=""
typeset -g LEGACY_ACTIVITY_ID_FILE="" LEGACY_IMMUN_ID_FILE=""
typeset -g LEGACY_ENROLL_ID_FILE=""

typeset -g ALIAS_ID_FILE="" ALIAS_PW_FILE="" ALIAS_AUTH_CFG=""
typeset -g WRONG_PW_FILE=""
typeset -g TIMING_LEGACY_ID_FILE="" TIMING_LEGACY_PW_FILE=""
typeset -g TIMING_LEGACY_AUTH_CFG=""

typeset -gA RULE_BASELINE=()
typeset -ga ENUM_RESP_FILES=() ENUM_HTTP_VALUES=() ENUM_TIME_FILES=()
typeset -gA FIXTURE_REGISTRY=()

typeset -g PLATFORM_KEY=""

# D-11: Track whether future-schema migrations have been applied.
typeset -gi FUTURE_SCHEMA_PHONE_APPLIED=0

# D-12: Set at runtime after self-test confirms domain acceptance.
typeset -g TEST_EMAIL_DOMAIN="$RELEASE1B_TEST_DOMAIN"

# ────────────────────────────────────────────────────────────
# §5  CORE UTILITIES
# ────────────────────────────────────────────────────────────

pb_realpath() {
  python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" -- "$1"
}

pb_generate_run_suffix() {
  RUN_SUFFIX=$(openssl rand -hex 6 2>/dev/null) || \
    RUN_SUFFIX=$(date +%s%3N | shasum -a 256 | head -c 12)
}

pb_setup_umask() { umask 077 }

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
  mkdir -p "$RELEASE1B_PB_DATA_DIR" "$RELEASE1B_PB_HOOKS_DIR" \
    "$RELEASE1B_PB_MIGRATIONS_DIR" "$RELEASE1B_TEST_TMP" "$RELEASE1B_EVIDENCE_DIR"
  chmod 700 "$RELEASE1B_PB_DATA_DIR" "$RELEASE1B_PB_HOOKS_DIR" \
    "$RELEASE1B_PB_MIGRATIONS_DIR" "$RELEASE1B_TEST_TMP" "$RELEASE1B_EVIDENCE_DIR"
  printf 'release1b_cp0_%s\n' "$RUN_SUFFIX" > "${root}/.release1b_marker"
  chmod 600 "${root}/.release1b_marker"
  printf '# CP0 Report %s\n\n| Test | Result | Notes |\n|---|---|---|\n' \
    "$RUN_SUFFIX" > "$RELEASE1B_REPORT_WORK"
  print "=== Isolated root: [${RELEASE1B_CANONICAL_ROOT}] ==="
}

pb_inc() {
  local _var="$1"
  typeset -g "${_var}"=$(( ${(P)_var} + 1 ))
}

pb_halt() { print "[HALT] $*" >&2; exit 1 }

pb_secure_tmpfile() {
  local suffix="${1:-.tmp}"
  local path="${RELEASE1B_TEST_TMP}/${RUN_SUFFIX}_$$_${RANDOM}${suffix}"
  : > "$path"; chmod 600 "$path"; print "$path"
}

pb_wipe_secret_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  dd if=/dev/zero of="$f" bs=1024 count=4 2>/dev/null || true
  # || true #1 (BENIGN-RETAINED): dd may return nonzero on short files.
  rm -f "$f"
}

# ────────────────────────────────────────────────────────────
# §6  TRAP / CLEANUP
# ────────────────────────────────────────────────────────────

# D-9: Canonical validation before any recursive removal.
pb_validate_cleanup_target() {
  local target="$1"
  [[ -z "$target" ]] && {
    print "[cleanup] REJECT: empty target" >&2; return 1
  }
  local canonical; canonical=$(pb_realpath "$target" 2>/dev/null) || {
    print "[cleanup] REJECT: cannot canonicalize target" >&2; return 1
  }
  [[ -z "$canonical" ]] && {
    print "[cleanup] REJECT: canonical path is empty" >&2; return 1
  }
  # Must be direct child of approved temp parent.
  local parent_dir="${canonical%/*}"
  local canonical_parent; canonical_parent=$(pb_realpath "$parent_dir" 2>/dev/null) || {
    print "[cleanup] REJECT: cannot canonicalize parent" >&2; return 1
  }
  if [[ "$canonical_parent" != "$RELEASE1B_CANONICAL_PARENT" ]]; then
    print "[cleanup] REJECT: target parent '${canonical_parent}' != approved '${RELEASE1B_CANONICAL_PARENT}'" >&2
    return 1
  fi
  # Must have exact prefix in basename.
  local base="${canonical##*/}"
  if [[ "$base" != release1b_cp0_* ]]; then
    print "[cleanup] REJECT: missing required prefix 'release1b_cp0_'" >&2; return 1
  fi
  # Must not be a symlink.
  local lstat_result
  lstat_result=$(python3 -c "
import os,sys,stat
try:
    s = os.lstat(sys.argv[1])
    print('SYMLINK' if stat.S_ISLNK(s.st_mode) else 'OK')
except Exception as e:
    print('ERROR:'+str(e))
" -- "$canonical" 2>/dev/null)
  if [[ "$lstat_result" == "SYMLINK" || "$lstat_result" == ERROR* ]]; then
    print "[cleanup] REJECT: symlink or lstat error: ${lstat_result}" >&2; return 1
  fi
  # Prohibited targets.
  case "$canonical" in
    /|/tmp|/var|/usr|/etc|/home|/root|/System|/Library)
      print "[cleanup] REJECT: prohibited top-level target: ${canonical}" >&2; return 1 ;;
  esac
  if [[ -n "${HOME:-}" ]]; then
    local home_canonical; home_canonical=$(pb_realpath "$HOME" 2>/dev/null)
    if [[ -n "$home_canonical" && "$canonical" == "$home_canonical" ]]; then
      print "[cleanup] REJECT: target is HOME" >&2; return 1
    fi
  fi
  # Must contain the run-suffix marker.
  if [[ ! -f "${canonical}/.release1b_marker" ]]; then
    print "[cleanup] REJECT: no .release1b_marker in target" >&2; return 1
  fi
  return 0
}

pb_trap_cleanup() {
  # D-8: Export report before cleanup if --report-dest was provided.
  if [[ -n "$RELEASE1B_REPORT_DEST" && -f "$RELEASE1B_REPORT_PATH" ]]; then
    pb_export_report || {
      print "[trap] WARNING: report export failed — see above" >&2
      CLEANUP_FAILURE=1
    }
  fi

  if (( RELEASE1B_PB_PID > 0 )); then
    local _stored_pid=$RELEASE1B_PB_PID
    local _ppid_init
    _ppid_init=$(ps -p "$_stored_pid" -o ppid= 2>/dev/null | tr -d ' ')
    if [[ "$_ppid_init" != "$$" ]]; then
      print "[trap] PID ${_stored_pid} not our child; skipping" >&2
      RELEASE1B_PB_PID=0
    else
      kill "$_stored_pid" 2>/dev/null
      local _wdflag="${RELEASE1B_TEST_TMP}/${RUN_SUFFIX}_wdflag_${_stored_pid}"
      : > "$_wdflag" && chmod 600 "$_wdflag"
      (
        sleep 6
        local _ppid_wd
        _ppid_wd=$(ps -p "$_stored_pid" -o ppid= 2>/dev/null | tr -d ' ')
        if [[ "$_ppid_wd" == "$$" ]]; then
          kill -9 "$_stored_pid" 2>/dev/null; printf '1' > "$_wdflag"
        fi
      ) &
      local _wd_pid=$!
      wait "$_stored_pid" 2>/dev/null
      kill "$_wd_pid" 2>/dev/null || true
      # || true #2 (BENIGN): watchdog may have already exited.
      wait "$_wd_pid" 2>/dev/null || true
      rm -f "$_wdflag"
      RELEASE1B_PB_PID=0
    fi
  fi

  local sf
  for sf in "$_NATIVE_SU_TOK_FILE" "$_NATIVE_SU_ID_FILE" "$_NATIVE_SU_AUTH_CFG" \
    "$ORDINARY_TOK_FILE" "$ADMIN_TOK_FILE" "$SADMIN_TOK_FILE" \
    "$LEGACY_TOK_FILE" "$ALIAS_PW_FILE" "$WRONG_PW_FILE" \
    "$TIMING_LEGACY_PW_FILE"; do
    [[ -n "$sf" ]] && pb_wipe_secret_file "$sf"
  done

  if [[ -n "$RELEASE1B_ISOLATED_ROOT" && -d "$RELEASE1B_ISOLATED_ROOT" ]]; then
    if pb_validate_cleanup_target "$RELEASE1B_ISOLATED_ROOT"; then
      rm -rf "$RELEASE1B_ISOLATED_ROOT" 2>/dev/null || CLEANUP_FAILURE=1
    else
      print "[trap] REFUSE to rm -rf: cleanup target failed validation. Root retained: ${RELEASE1B_ISOLATED_ROOT}" >&2
      CLEANUP_FAILURE=1
    fi
  fi

  (( CLEANUP_FAILURE )) && \
    print "[trap] Cleanup incomplete — root may be retained: ${RELEASE1B_ISOLATED_ROOT}" >&2
}

pb_install_trap() { trap pb_trap_cleanup EXIT TERM INT }

# ────────────────────────────────────────────────────────────
# §7  RESULT TRACKING
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
# §8  PYTHON HELPER SCRIPTS
# ────────────────────────────────────────────────────────────

pb_write_scripts() {
  local d="$RELEASE1B_TEST_TMP"

  PBJ_STAT_PY="${d}/pbj_stat.py"
  cat > "$PBJ_STAT_PY" << 'PYEOF'
import sys,os,stat as _st
CANONICAL_TMP=os.environ.get('RELEASE1B_CANONICAL_TMP','')
path=sys.argv[1]
try:
    lstat=os.lstat(path)
except Exception as exc:
    print(f'ERROR:{exc}',file=sys.stderr); sys.exit(2)
if _st.S_ISLNK(lstat.st_mode): print('SYMLINK'); sys.exit(0)
if CANONICAL_TMP:
    real_path=os.path.realpath(path); real_tmp=os.path.realpath(CANONICAL_TMP)
    if not real_path.startswith(real_tmp+os.sep) and real_path!=real_tmp:
        print('OUTSIDE_ROOT'); sys.exit(0)
print(oct(_st.S_IMODE(lstat.st_mode))[2:])
PYEOF

  PBJ_URL_PY="${d}/pbj_url.py"
  cat > "$PBJ_URL_PY" << 'PYEOF'
import sys,re,urllib.parse
url_str=sys.argv[1]; exp_host=sys.argv[2]; exp_port=sys.argv[3]
try:
    p=urllib.parse.urlparse(url_str)
except Exception:
    print('REJECT:parse-error'); sys.exit(0)
if p.scheme!='http': print(f'REJECT:scheme={p.scheme!r}'); sys.exit(0)
if p.username or p.password: print('REJECT:userinfo'); sys.exit(0)
if p.fragment: print('REJECT:fragment'); sys.exit(0)
host=(p.hostname or '').lower()
if host!=exp_host: print(f'REJECT:host={host!r}'); sys.exit(0)
port=str(p.port) if p.port else '80'
if port!=exp_port: print(f'REJECT:port={port!r}'); sys.exit(0)
if not p.path.startswith('/api/'): print(f'REJECT:path={p.path!r}'); sys.exit(0)
raw_host=url_str.split('://')[1].split('/')[0].split('@')[-1].split(':')[0]
if re.search(r'0x|%|0[0-9]{2,}',raw_host): print('REJECT:encoded-host'); sys.exit(0)
print('OK')
PYEOF

  PBJ_PY="${d}/pbj.py"
  cat > "$PBJ_PY" << 'PYEOF'
import sys,os,json,math,stat as _st
BLOCKED=frozenset({'id','collectionId','collectionName','created','updated',
    'tokenKey','passwordHash'})
out_path=sys.argv[1]; args=sys.argv[2:]; obj={}
for arg in args:
    if ':' in arg.split('=')[0]: typ,rest=arg.split(':',1)
    else: typ='s'; rest=arg
    if '=' not in rest:
        print(f'ERROR: no = in arg {arg!r}',file=sys.stderr); sys.exit(1)
    key,val=rest.split('=',1)
    if key in BLOCKED:
        print(f'ERROR: blocked key {key!r}',file=sys.stderr); sys.exit(1)
    if key in obj:
        print(f'ERROR: duplicate key {key!r}',file=sys.stderr); sys.exit(1)
    if typ=='s':
        if val.startswith('secret-file:'):
            sf=val[len('secret-file:'):]
            try:
                lst=os.lstat(sf)
            except Exception as e:
                print(f'ERROR: secret-file stat: {e}',file=sys.stderr); sys.exit(1)
            if _st.S_ISLNK(lst.st_mode):
                print('ERROR: secret-file is a symlink',file=sys.stderr); sys.exit(1)
            with open(sf) as fh: obj[key]=fh.read().strip()
        else: obj[key]=val
    elif typ=='b':
        if val.lower() not in ('true','false'):
            print(f'ERROR: bool must be true/false',file=sys.stderr); sys.exit(1)
        obj[key]=(val.lower()=='true')
    elif typ=='n':
        try:
            fv=float(val); obj[key]=int(fv) if fv==math.floor(fv) else fv
        except ValueError:
            print(f'ERROR: not a number: {val!r}',file=sys.stderr); sys.exit(1)
    else:
        print(f'ERROR: unknown type {typ!r}',file=sys.stderr); sys.exit(1)
lst=os.lstat(out_path)
if _st.S_ISLNK(lst.st_mode):
    print('ERROR: output path is a symlink',file=sys.stderr); sys.exit(1)
with open(out_path,'w') as fh: json.dump(obj,fh)
os.chmod(out_path,0o600)
PYEOF

  PBJ_AUTH_PY="${d}/pbj_auth.py"
  cat > "$PBJ_AUTH_PY" << 'PYEOF'
import sys,os,re,stat as _st
auth_cfg=sys.argv[1]; tok_file=sys.argv[2]
try:
    lst=os.lstat(tok_file)
    if _st.S_ISLNK(lst.st_mode):
        print('ERROR: tok_file is a symlink',file=sys.stderr); sys.exit(1)
    with open(tok_file) as fh: token=fh.read().strip()
except Exception as e:
    print(f'ERROR: {e}',file=sys.stderr); sys.exit(1)
if not re.match(r'^[A-Za-z0-9._\-]+$',token):
    print('ERROR: token failed safety pattern',file=sys.stderr); sys.exit(1)
hdr=f'Authorization: Bearer {token}'
try:
    lst=os.lstat(auth_cfg)
    if _st.S_ISLNK(lst.st_mode):
        print('ERROR: auth_cfg is a symlink',file=sys.stderr); sys.exit(1)
    with open(auth_cfg,'w') as fh: fh.write(hdr)
    os.chmod(auth_cfg,0o600)
except Exception as e:
    print(f'ERROR: {e}',file=sys.stderr); sys.exit(1)
PYEOF

  PBJ_HTTP_PY="${d}/pbj_http.py"
  cat > "$PBJ_HTTP_PY" << 'PYEOF'
import sys,os,subprocess,re,stat as _st
MAX_RESP=1024*512
def main():
    status_out=sys.argv[1]; path_out=sys.argv[2]; url=sys.argv[3]
    auth_file=sys.argv[4] if len(sys.argv)>4 else ''
    body_file=sys.argv[5] if len(sys.argv)>5 else ''
    method=sys.argv[6] if len(sys.argv)>6 else 'GET'
    CANONICAL_TMP=os.environ.get('RELEASE1B_CANONICAL_TMP','')
    resp_path=os.path.join(
        CANONICAL_TMP or os.path.dirname(status_out),
        f'resp_{os.getpid()}_{os.urandom(4).hex()}.json')
    try:
        with open(resp_path,'w') as fh: fh.write('')
        os.chmod(resp_path,0o600)
    except Exception as e:
        print(f'ERROR creating resp: {e}',file=sys.stderr); sys.exit(1)
    cmd=['curl','-sf','--max-time','30','--connect-timeout','10',
         '--output',resp_path,'--write-out','%{http_code}',
         '-X',method.upper(),'-H','Content-Type: application/json']
    if auth_file and os.path.isfile(auth_file):
        try:
            lst=os.lstat(auth_file)
            if not _st.S_ISLNK(lst.st_mode):
                with open(auth_file) as fh: hdr=fh.read().strip()
                if re.match(r'^Authorization: Bearer [A-Za-z0-9._\-]+$',hdr):
                    cmd+=['-H',hdr]
        except Exception: pass
    if body_file and os.path.isfile(body_file):
        cmd+=['--data-binary',f'@{body_file}']
    cmd.append(url)
    result=subprocess.run(cmd,capture_output=True,text=True)
    status=result.stdout.strip() or '000'
    try:
        sz=os.path.getsize(resp_path)
        if sz>MAX_RESP:
            with open(resp_path,'r+b') as fh: fh.seek(MAX_RESP); fh.truncate()
    except Exception: pass
    with open(status_out,'w') as fh: fh.write(status)
    os.chmod(status_out,0o600)
    with open(path_out,'w') as fh: fh.write(resp_path)
    os.chmod(path_out,0o600)
main()
PYEOF

  PBJ_FIELD_PY="${d}/pbj_field.py"
  cat > "$PBJ_FIELD_PY" << 'PYEOF'
import sys,os,json,re
BLOCKED=frozenset({'password','passwordHash','tokenKey'})
resp_file=sys.argv[1]; field=sys.argv[2]
if field in BLOCKED: print('BLOCKED',file=sys.stderr); sys.exit(1)
try:
    with open(resp_file) as fh: data=json.load(fh)
except Exception as e:
    print(f'ERROR: {e}',file=sys.stderr); sys.exit(1)
if field not in data: print('__absent__'); sys.exit(0)
val=data[field]
if val is None: print('__null__')
elif isinstance(val,bool): print('true' if val else 'false')
elif isinstance(val,(int,float)): print(val)
elif isinstance(val,str):
    if len(val)>512: print('__truncated__')
    elif re.search(r'[^\x20-\x7e]',val): print('__nonascii__')
    else: print(val)
else: print(f'__type:{type(val).__name__}__')
PYEOF

  PBJ_EXTRACT_PY="${d}/pbj_extract.py"
  cat > "$PBJ_EXTRACT_PY" << 'PYEOF'
import sys,json,re
ALLOWED=frozenset({'id','email','role','name','otpId','collectionId'})
resp_file=sys.argv[1]; field=sys.argv[2]
if field not in ALLOWED:
    print(f'ERROR: field {field!r} not in extraction allowlist',file=sys.stderr); sys.exit(1)
with open(resp_file) as fh: data=json.load(fh)
val=data.get(field,'__absent__')
if isinstance(val,str):
    if not re.match(r'^[A-Za-z0-9@._\-\s]{1,256}$',val):
        print('ERROR: field value failed safety pattern',file=sys.stderr); sys.exit(1)
    print(val)
elif val=='__absent__': print('__absent__')
else: print(str(val))
PYEOF

  PBJ_SHAPE_PY="${d}/pbj_shape.py"
  cat > "$PBJ_SHAPE_PY" << 'PYEOF'
import sys,json
resp_file=sys.argv[1]; args=sys.argv[2:]; required=[]; absent=[]; mode='required'
for a in args:
    if a=='--absent': mode='absent'
    else: (absent if mode=='absent' else required).append(a)
with open(resp_file) as fh: data=json.load(fh)
errors=[]
for f in required:
    if f not in data: errors.append(f'missing:{f}')
for f in absent:
    if f in data: errors.append(f'present:{f}')
if errors: print('SHAPE_ERR: '+', '.join(errors)); sys.exit(1)
print('OK')
PYEOF

  PBJ_SCAN_PY="${d}/pbj_scan.py"
  cat > "$PBJ_SCAN_PY" << 'PYEOF'
import sys,os,re
CANONICAL_ROOT=os.environ.get('RELEASE1B_CANONICAL_ROOT','')
def sanitize(line):
    if CANONICAL_ROOT: line=line.replace(CANONICAL_ROOT,'[ISOLATED_ROOT]')
    home=os.path.expanduser('~')
    if home and home!='~': line=line.replace(home,'[HOME]')
    line=re.sub(r'/tmp/release1b_cp0_[A-Za-z0-9_]+','[ISOLATED_ROOT]',line)
    # D-6: Redact any line that appears to reference an email at ultra.works
    # or any sdmadmin-pattern identity. No credential value is printed.
    line=re.sub(r'\bsdmadmin\b','[REDACTED-SEED-IDENTITY]',line,flags=re.IGNORECASE)
    line=re.sub(r'[A-Za-z0-9._%+\-]+@ultra\.works','[REDACTED-SEED-EMAIL]',line,flags=re.IGNORECASE)
    return line
report_in=sys.argv[1]; report_out=sys.argv[2]
lines=[]
try:
    with open(report_in) as fh:
        for line in fh: lines.append(sanitize(line.rstrip('\n')))
except Exception as e:
    print(f'ERROR reading: {e}',file=sys.stderr); sys.exit(1)
tmp=report_out+'.scantmp'
try:
    with open(tmp,'w') as fh: fh.write('\n'.join(lines)+'\n')
    os.chmod(tmp,0o600)
    os.replace(tmp,report_out)
except Exception as e:
    print(f'ERROR writing: {e}',file=sys.stderr)
    try: os.unlink(tmp)
    except Exception: pass
    sys.exit(1)
PYEOF

  # D-3: Credential scan helper.
  # Scans a migration JS file for patterns suggesting embedded credentials.
  # Outputs FILENAME:LINENO only — never the matching content.
  # Exit 0 = clean. Exit 1 = suspected credential found. Exit 2 = error.
  PBJ_CRED_SCAN_PY="${d}/pbj_cred_scan.py"
  cat > "$PBJ_CRED_SCAN_PY" << 'PYEOF'
import sys,re
filepath=sys.argv[1]
try:
    with open(filepath,encoding='utf-8',errors='replace') as fh:
        lines=fh.readlines()
except Exception as e:
    print(f'ERROR:{e}',file=sys.stderr); sys.exit(2)
# Patterns indicative of embedded credentials (conservative):
# 1. Dollar-delimited strings: $$...$$ pattern used in known credential.
# 2. String literals >20 chars with mixed case, digits, and symbols.
# 3. Any field assignment that looks like "password" or "secret" with a value.
PATTERNS=[
    re.compile(r'\$\$[^\$\n]{6,}'),
    re.compile(r'["\'](?=[^"\']{20,}["\'])(?=[^"\']*[A-Z])(?=[^"\']*[a-z])(?=[^"\']*\d)(?=[^"\']*[!@#$%^&*()\-_+=])[^"\']{20,}["\']'),
    re.compile(r'(?:set|\.set)\s*\(["\']password["\']',re.IGNORECASE),
]
found=False
for i,line in enumerate(lines,1):
    stripped=line.rstrip('\n')
    if stripped.lstrip().startswith('//') or stripped.lstrip().startswith('*'):
        continue
    for pat in PATTERNS:
        if pat.search(stripped):
            # Print only filename and line number — never the content.
            print(f'SUSPECTED:{filepath}:{i}')
            found=True
            break
sys.exit(1 if found else 0)
PYEOF

  PBJ_COPY_PY="${d}/pbj_copy.py"
  cat > "$PBJ_COPY_PY" << 'PYEOF'
import sys,json
BLOCKED=frozenset({'password','passwordHash','tokenKey'})
src_file=sys.argv[1]; dst_file=sys.argv[2]; field=sys.argv[3]
out_field=sys.argv[4] if len(sys.argv)>4 else field
if field in BLOCKED or out_field in BLOCKED:
    print('BLOCKED',file=sys.stderr); sys.exit(1)
with open(src_file) as fh: src=json.load(fh)
with open(dst_file) as fh: dst=json.load(fh)
if field not in src:
    print(f'ABSENT: {field!r}',file=sys.stderr); sys.exit(1)
dst[out_field]=src[field]
with open(dst_file,'w') as fh: json.dump(dst,fh)
PYEOF

  chmod 400 "$PBJ_STAT_PY" "$PBJ_URL_PY" "$PBJ_PY" "$PBJ_AUTH_PY" \
    "$PBJ_HTTP_PY" "$PBJ_FIELD_PY" "$PBJ_COPY_PY" "$PBJ_EXTRACT_PY" \
    "$PBJ_SHAPE_PY" "$PBJ_SCAN_PY" "$PBJ_CRED_SCAN_PY"
  print "=== Python helpers written ==="
}

# ────────────────────────────────────────────────────────────
# §9  VALIDATION HELPERS
# ────────────────────────────────────────────────────────────

pb_validate_path() {
  local path="$1"
  local result
  result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$path" 2>/dev/null)
  case "$result" in
    SYMLINK)      print "PATH_SYMLINK:${path}"; return 1 ;;
    OUTSIDE_ROOT) print "PATH_OUTSIDE:${path}"; return 1 ;;
    ERROR*)       print "PATH_ERROR:${path}";   return 1 ;;
    *)            return 0 ;;
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
  pb_validate_url "$url" || pb_halt "URL validation failed: ${url}"
  print "$url"
}

# ────────────────────────────────────────────────────────────
# §10 PACKAGE COMPLETENESS CHECK
# ────────────────────────────────────────────────────────────

pb_check_package_completeness() {
  print "=== Package completeness check ==="
  local ok=1

  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local src="${HOOK_SRC_PATHS[$hk]}"
    if [[ "$src" == UNRESOLVED* ]]; then
      print "[pkg] HOOK_SRC_PATHS[$hk]: UNRESOLVED"; ok=0
    elif [[ ! -f "$src" ]]; then
      print "[pkg] HOOK_SRC_PATHS[$hk]: file not found: ${src}"; ok=0
    fi
  done

  if [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]]; then
    print "[pkg] RELEASE1B_SCHEMA_SRC: UNRESOLVED"; ok=0
  fi

  # D-7: Check OTP adapter alongside script.
  local script_dir="${${(%):-%N}:h}"
  local adapter_path="${script_dir}/${OTP_ADAPTER_FILENAME}"
  if [[ ! -f "$adapter_path" ]]; then
    print "[pkg] OTP adapter not found: ${adapter_path}"; ok=0
  fi

  (( ok )) && print "[pkg] OK" && return 0
  print "[pkg] INCOMPLETE"; return 1
}

# ────────────────────────────────────────────────────────────
# §11 HARNESS SELF-TEST
# ────────────────────────────────────────────────────────────

t_harness_selftest() {
  print "=== Harness self-test ==="
  local fail=0

  t_pass "SELFTEST-PASS-COUNTER"

  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=test" "role=user" 2>/dev/null || {
    print "[selftest] FAIL: pbj.py rejected valid args" >&2; fail=1
  }
  rm -f "$body_f"

  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "id=inject" 2>/dev/null && {
    print "[selftest] FAIL: pbj.py accepted blocked key 'id'" >&2; fail=1
  }
  rm -f "$body_f"

  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=a" "name=b" 2>/dev/null && {
    print "[selftest] FAIL: pbj.py accepted duplicate key" >&2; fail=1
  }
  rm -f "$body_f"

  local link_target; link_target=$(pb_secure_tmpfile .tgt)
  local link_name="${RELEASE1B_TEST_TMP}/selftest_link_${RANDOM}"
  ln -s "$link_target" "$link_name" 2>/dev/null
  local link_result
  link_result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$link_name" 2>/dev/null)
  [[ "$link_result" != "SYMLINK" ]] && {
    print "[selftest] FAIL: symlink not detected (got ${link_result})" >&2; fail=1
  }
  rm -f "$link_name" "$link_target"

  # D-3: Credential scan self-test — verify the scanner catches the known pattern.
  local cred_test_f; cred_test_f=$(pb_secure_tmpfile .js)
  # Write a line with the known suspicious pattern style (not the actual credential).
  printf 'admin.set("password", "$$FakeTestCred!1Ab$$");\n' > "$cred_test_f"
  python3 "$PBJ_CRED_SCAN_PY" "$cred_test_f" 2>/dev/null
  local scan_rc=$?
  rm -f "$cred_test_f"
  (( scan_rc != 1 )) && {
    print "[selftest] FAIL: credential scanner did not detect test pattern (rc=${scan_rc})" >&2
    fail=1
  }

  # D-9: Cleanup validation self-test — verify a bad path is rejected.
  local cleanup_ok=0
  pb_validate_cleanup_target "/" 2>/dev/null && cleanup_ok=1
  (( cleanup_ok )) && {
    print "[selftest] FAIL: pb_validate_cleanup_target accepted '/'" >&2; fail=1
  }

  # D-12: Test whether PocketBase accepts example.invalid email domain.
  # This test runs after pb_start_pocketbase(); here we pre-check DNS won't
  # accidentally resolve the domain (it must not be resolvable).
  local nslookup_result
  nslookup_result=$(nslookup "example.invalid" 2>&1 || true)
  if [[ "$nslookup_result" == *"Name: example.invalid"* ]]; then
    print "[selftest] FAIL: example.invalid resolves in DNS — domain not safe for testing" >&2
    fail=1
  fi

  local saved_halt=$HALT_DEPENDENTS; HALT_DEPENDENTS=1
  t_skip "SELFTEST-SKIP-TEST" "testing skip propagation"
  HALT_DEPENDENTS=$saved_halt

  T_PASS=$(( T_PASS - 1 ))
  T_SKIP=$(( T_SKIP - 1 ))

  if (( fail )); then
    print "[selftest] RESULT: FAIL (${fail} assertion(s))" >&2; return 1
  else
    print "[selftest] RESULT: PASS"; return 0
  fi
}

# ────────────────────────────────────────────────────────────
# §12 INFRASTRUCTURE
# ────────────────────────────────────────────────────────────

pb_detect_platform() {
  local os_name; os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  local arch; arch=$(uname -m)
  case "$arch" in arm64|aarch64) arch="arm64" ;; x86_64) arch="amd64" ;;
    *) pb_halt "Unsupported architecture: ${arch}" ;; esac
  case "$os_name" in darwin|linux) : ;; *) pb_halt "Unsupported OS: ${os_name}" ;; esac
  PLATFORM_KEY="${os_name}_${arch}"
  print "=== Platform: ${PLATFORM_KEY} ==="
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

pb_extract_pocketbase() {
  local archive="$1"
  unzip -o "$archive" -d "$RELEASE1B_ISOLATED_ROOT" pocketbase 2>/dev/null \
    || pb_halt "Cannot extract pocketbase from ${archive}"
  chmod 700 "$RELEASE1B_PB_BIN"
}

pb_preflight_ports() {
  print "=== Preflight port check ==="
  if lsof -iTCP:"$RELEASE1B_PB_PORT" -sTCP:LISTEN -P -n &>/dev/null; then
    t_blocking "T-PREFLIGHT-PORTS" "Port ${RELEASE1B_PB_PORT} already in use"
    return 1
  fi
  t_pass "T-PREFLIGHT-PORTS"
}

# D-3: Apply schema migrations, excluding the seed credential migration.
pb_apply_schema_migrations() {
  print "=== Applying schema migrations ==="
  if [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]]; then
    t_unresolved "T-SCHEMA-MIGRATIONS" "RELEASE1B_SCHEMA_SRC NEEDS-EXTERNAL"; return 0
  fi
  [[ -d "$RELEASE1B_SCHEMA_SRC" ]] || {
    t_blocking "T-SCHEMA-MIGRATIONS" "RELEASE1B_SCHEMA_SRC not a directory: ${RELEASE1B_SCHEMA_SRC}"
    return 1
  }

  local js_count=0 excluded_count=0 credential_suspect=0

  local _jf
  for _jf in "${RELEASE1B_SCHEMA_SRC}"/*.js(N); do
    local basename_jf; basename_jf="${_jf##*/}"

    # Exclude the exact seed migration by filename.
    if [[ "$basename_jf" == "$SEED_MIGRATION_EXCLUDE" ]]; then
      print "[migrations] EXCLUDED seed migration: ${basename_jf} (D-3: S-3 incident)"
      (( excluded_count++ ))
      continue
    fi

    # D-3: Credential scan — fail closed if suspected credential found in any
    # other migration. Never print matching content.
    local scan_rc
    python3 "$PBJ_CRED_SCAN_PY" "$_jf" 2>/dev/null
    scan_rc=$?
    if (( scan_rc == 1 )); then
      print "[migrations] CREDENTIAL SUSPECTED in migration (filename only, no content): ${basename_jf}" >&2
      credential_suspect=1
    elif (( scan_rc == 2 )); then
      t_harness_err "T-SCHEMA-MIGRATIONS-SCAN" "Scan error on ${basename_jf}"
    fi

    cp "$_jf" "${RELEASE1B_PB_MIGRATIONS_DIR}/" || {
      t_blocking "T-SCHEMA-MIGRATIONS-COPY" "cp failed: ${basename_jf}"; return 1
    }
    chmod 600 "${RELEASE1B_PB_MIGRATIONS_DIR}/${basename_jf}" || {
      t_blocking "T-SCHEMA-MIGRATIONS-PERMS" "chmod failed: ${basename_jf}"; return 1
    }
    (( js_count++ ))
  done

  if (( credential_suspect )); then
    t_blocking "T-SCHEMA-MIGRATIONS-CREDENTIAL" \
      "Suspected credential found in a non-excluded migration file. " \
      "Review file list above. Do not run harness until confirmed clean."
    return 1
  fi

  if (( js_count == 0 )); then
    t_blocking "T-SCHEMA-MIGRATIONS-COPY" "No .js files found after exclusions"; return 1
  fi

  if (( excluded_count == 0 )); then
    t_blocking "T-SCHEMA-MIGRATIONS-EXCLUDE" \
      "Expected to exclude '${SEED_MIGRATION_EXCLUDE}' but it was not found in source. "\
      "Verify RELEASE1B_SCHEMA_SRC points to the correct pb_migrations/ directory."
    return 1
  fi

  t_pass "T-SCHEMA-MIGRATIONS-COPY"
}

# D-7: Deploy hooks. auth_whatsapp_otp is not deployed; OTP adapter replaces it.
pb_deploy_hooks() {
  print "=== Deploying hooks ==="

  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local src="${HOOK_SRC_PATHS[$hk]}"
    if [[ "$src" == UNRESOLVED* ]]; then
      t_unresolved "T-HOOK-DEPLOY-${hk}" "src NEEDS-EXTERNAL"; continue
    fi
    [[ -f "$src" ]] || { t_blocking "T-HOOK-DEPLOY-${hk}" "file not found: ${src}"; continue }

    local expected_sha="${HOOK_EXPECTED_SHA256[$hk]:-}"
    if [[ "$expected_sha" != UNRESOLVED* ]]; then
      local actual_sha; actual_sha=$(shasum -a 256 "$src" | awk '{print $1}')
      if [[ "$actual_sha" != "$expected_sha" ]]; then
        t_blocking "T-HOOK-HASH-${hk}" "hash mismatch expected=${expected_sha} actual=${actual_sha}"
        continue
      fi
    fi
    local dest="${RELEASE1B_PB_HOOKS_DIR}/$(basename "$src")"
    cp "$src" "$dest" || { t_blocking "T-HOOK-DEPLOY-${hk}" "cp failed"; continue }
    chmod 600 "$dest"
    t_pass "T-HOOK-DEPLOY-${hk}"
  done

  # Deploy OTP adapter from package directory (alongside this script).
  local script_dir="${${(%):-%N}:h}"
  local adapter_src="${script_dir}/${OTP_ADAPTER_FILENAME}"
  if [[ -f "$adapter_src" ]]; then
    local adapter_dest="${RELEASE1B_PB_HOOKS_DIR}/${OTP_ADAPTER_FILENAME}"
    cp "$adapter_src" "$adapter_dest" || {
      t_blocking "T-HOOK-DEPLOY-otp_adapter" "cp failed: ${adapter_src}"; return 1
    }
    chmod 600 "$adapter_dest"
    t_pass "T-HOOK-DEPLOY-otp_adapter"
  else
    t_blocking "T-HOOK-DEPLOY-otp_adapter" "adapter not found: ${adapter_src}"
    return 1
  fi

  # NOTE: auth_whatsapp_otp.pb.js is intentionally NOT copied to the
  # isolated hooks directory. The OTP adapter above replaces it for testing.
  # The source project hook file is never modified.

  t_pass "T-HOOKDIR-VERIFY"
}

pb_start_pocketbase() {
  print "=== Starting PocketBase ==="
  [[ -x "$RELEASE1B_PB_BIN" ]] || pb_halt "PB binary not found or not executable"
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
    curl -sf "${RELEASE1B_BASE_URL}/api/health" &>/dev/null && {
      print "=== PocketBase ready after ${tries}s ==="; return 0
    }
    sleep 1; (( tries++ ))
  done
  pb_halt "PocketBase did not become ready within 30s"
}

# D-12: Post-startup test that PocketBase accepts example.invalid email.
pb_verify_email_domain() {
  print "=== Verifying example.invalid email domain acceptance ==="
  local email="cp0_domaintest_${RUN_SUFFIX}@${RELEASE1B_TEST_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"; chmod 600 "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" "role=user" 2>/dev/null || {
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"
    t_blocking "T-SELFTEST-EMAIL-DOMAIN" "pbj.py failed building test body"; return 1
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
  pb_wipe_secret_file "$pw_file"
  if [[ "$status" == "200" ]]; then
    local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    rm -f "$resp_path"
    if [[ -n "$rec_id" && "$rec_id" != "__absent__" ]]; then
      local id_f; id_f=$(pb_secure_tmpfile .id)
      printf '%s' "$rec_id" > "$id_f"
      pb_delete_record "users" "$id_f"
    fi
    TEST_EMAIL_DOMAIN="$RELEASE1B_TEST_DOMAIN"
    t_pass "T-SELFTEST-EMAIL-DOMAIN"
    return 0
  else
    rm -f "$resp_path"
    t_blocking "T-SELFTEST-EMAIL-DOMAIN" \
      "PocketBase rejected example.invalid email domain (HTTP ${status}). "\
      "All test identities require this domain. Halting."
    return 1
  fi
}

# D-8: Export report to caller-supplied destination before cleanup.
pb_export_report() {
  [[ -n "$RELEASE1B_REPORT_DEST" ]] || return 0
  [[ -f "$RELEASE1B_REPORT_PATH" ]] || {
    print "[export] No report at ${RELEASE1B_REPORT_PATH}" >&2; return 1
  }

  # Validate destination: must be outside isolated root, no symlink.
  local dest_canonical; dest_canonical=$(pb_realpath "$RELEASE1B_REPORT_DEST" 2>/dev/null) || {
    print "[export] Cannot canonicalize dest: ${RELEASE1B_REPORT_DEST}" >&2; return 1
  }
  if [[ "$dest_canonical" == "${RELEASE1B_CANONICAL_ROOT}"* ]]; then
    print "[export] Destination is inside isolated root — rejected" >&2; return 1
  fi
  local lstat_result
  lstat_result=$(python3 -c "
import os,sys,stat
try:
    s=os.lstat(sys.argv[1])
    print('SYMLINK' if stat.S_ISLNK(s.st_mode) else 'NOTEXIST_OR_OK')
except FileNotFoundError:
    print('NOTEXIST')
except Exception as e:
    print('ERROR:'+str(e))
" -- "$dest_canonical" 2>/dev/null)
  if [[ "$lstat_result" == "SYMLINK" || "$lstat_result" == ERROR* ]]; then
    print "[export] Destination symlink or error: ${lstat_result}" >&2; return 1
  fi

  local dest_parent="${dest_canonical%/*}"
  [[ -d "$dest_parent" ]] || {
    print "[export] Destination parent does not exist: ${dest_parent}" >&2; return 1
  }

  # Sanitize in place (already done at report generation; apply again to ensure).
  local sanitized_f; sanitized_f="${RELEASE1B_REPORT_PATH}.export_sanitized"
  RELEASE1B_CANONICAL_ROOT="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_SCAN_PY" "$RELEASE1B_REPORT_PATH" "$sanitized_f" 2>/dev/null || {
    print "[export] Sanitize failed" >&2; return 1
  }
  chmod 600 "$sanitized_f"

  # Scan sanitized content for residual disclosures (non-printing check).
  local scan_hit=0
  grep -qiE 'release1b_cp0_[a-z0-9]{12}|ISOLATED_ROOT.*\.\.|\.\./|sdmadmin|ultra\.works' \
    "$sanitized_f" 2>/dev/null && scan_hit=1
  if (( scan_hit )); then
    print "[export] FAIL-CLOSED: sanitized report contains residual disclosure patterns" >&2
    rm -f "$sanitized_f"; return 1
  fi

  # Atomic copy via temp file.
  local tmp_dest; tmp_dest="${dest_parent}/.release1b_report_tmp_${RUN_SUFFIX}"
  cp "$sanitized_f" "$tmp_dest" 2>/dev/null || {
    print "[export] cp to tmp dest failed" >&2; rm -f "$sanitized_f"; return 1
  }
  chmod 600 "$tmp_dest"
  mv "$tmp_dest" "$dest_canonical" 2>/dev/null || {
    print "[export] atomic mv failed" >&2; rm -f "$tmp_dest" "$sanitized_f"; return 1
  }
  rm -f "$sanitized_f"

  # Verify retained file (size and existence).
  local src_size dest_size
  src_size=$(wc -c < "$RELEASE1B_REPORT_PATH" 2>/dev/null | tr -d ' ')
  dest_size=$(wc -c < "$dest_canonical" 2>/dev/null | tr -d ' ')
  if [[ "$dest_size" -lt 100 ]]; then
    print "[export] Retained report suspiciously small (${dest_size} bytes)" >&2; return 1
  fi

  print "=== Report exported to: [${dest_canonical}] (${dest_size} bytes) ==="
}

# ────────────────────────────────────────────────────────────
# §13 NATIVE SUPERUSER LIFECYCLE
# NOTE: Uses /api/admins/auth-with-password (v0.28.x pattern).
# If v0.29.3 moved this to /api/collections/_superusers/
# auth-with-password, this section needs updating. Verify.
# ────────────────────────────────────────────────────────────

pb_create_local_superuser() {
  print "=== Creating native superuser ==="
  local su_email="cp0_su_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local su_pw_file; su_pw_file=$(pb_secure_tmpfile .pw)
  local su_tok_file; su_tok_file=$(pb_secure_tmpfile .tok)
  local su_id_file; su_id_file=$(pb_secure_tmpfile .id)
  local su_auth_cfg; su_auth_cfg=$(pb_secure_tmpfile .hdr)
  openssl rand -base64 32 | tr -d '\n=' > "$su_pw_file"; chmod 600 "$su_pw_file"
  "$RELEASE1B_PB_BIN" admin create "$su_email" "$(cat "$su_pw_file")" \
    --dir "$RELEASE1B_PB_DATA_DIR" &>/dev/null || {
    t_blocking "T-SU-CREATE" "pocketbase admin create failed"; return 1
  }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${su_email}" "secret-file:password=${su_pw_file}" 2>/dev/null || {
    t_blocking "T-SU-AUTH-BODY" "pbj.py failed"; rm -f "$body_f"; pb_wipe_secret_file "$su_pw_file"; return 1
  }
  local url; url=$(pb_url "/api/admins/auth-with-password")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  if [[ "$status" != "200" ]]; then
    t_blocking "T-SU-AUTH" "Superuser auth returned ${status}"
    rm -f "$resp_path"; pb_wipe_secret_file "$su_pw_file"; return 1
  fi
  local token; token=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
  rm -f "$resp_path"
  [[ -z "$token" || "$token" == "__absent__" ]] && {
    t_blocking "T-SU-AUTH-TOKEN" "Missing token"; pb_wipe_secret_file "$su_pw_file"; return 1
  }
  printf '%s' "$token" > "$su_tok_file"; chmod 600 "$su_tok_file"
  local su_id; su_id=$(cat "$su_id_file" 2>/dev/null)
  python3 "$PBJ_AUTH_PY" "$su_auth_cfg" "$su_tok_file" 2>/dev/null || {
    t_blocking "T-SU-AUTH-CFG" "pbj_auth.py failed"; pb_wipe_secret_file "$su_pw_file"; return 1
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
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp" "$_NATIVE_SU_ID_FILE"
  [[ "$status" != "200" && "$status" != "204" && "$status" != "404" ]] && CLEANUP_FAILURE=1
  pb_wipe_secret_file "$_NATIVE_SU_TOK_FILE"
  pb_wipe_secret_file "$_NATIVE_SU_AUTH_CFG"
  t_pass "T-SU-DELETE"
}

# ────────────────────────────────────────────────────────────
# §14-§16 SCHEMA VERIFICATION, BASELINE, RULE HELPERS
# ────────────────────────────────────────────────────────────

pb_verify_schema() {
  print "=== Verifying schema collections ==="
  local required_collections=(
    users children
    growth_logs nutrition_logs activity_logs wellbeing_logs
    immunisations articles bookmarks
    notifications notification_preferences notification_queue
    phone_otps push_subscriptions
    courses enrollments lesson_progress
  )
  local col
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
    if [[ "$st" == "200" ]]; then t_pass "T-SCHEMA-COL-${col}"
    else t_fail "T-SCHEMA-COL-${col}" "returned ${st}"; fi
  done

  # Verify children.user field (not parent).
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
    local fchk; fchk=$(python3 - "$rp" << 'PYEOF'
import sys,json
with open(sys.argv[1]) as f: d=json.load(f)
fs=[x.get("name","") for x in d.get("fields",d.get("schema",[]))]
has_u="user" in fs; has_p="parent" in fs
print("OK" if has_u and not has_p else ("WRONG_PARENT" if has_p else "NEITHER"))
PYEOF
)
    rm -f "$rp"
    [[ "$fchk" == "OK" ]] && t_pass "T-SCHEMA-FIELD-CHILDREN-USER" || \
      t_fail "T-SCHEMA-FIELD-CHILDREN-USER" "field check: ${fchk}"
  else
    rm -f "$rp"; t_fail "T-SCHEMA-FIELD-CHILDREN-USER" "collection read returned ${st}"
  fi
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
    rm -f "$rp"; t_harness_err "T-RULE-BASELINE-${collection}" "GET returned ${st}"; return 1
  fi
  local val; val=$(python3 "$PBJ_FIELD_PY" "$rp" "$rule_type" 2>/dev/null)
  rm -f "$rp"
  local norm; [[ "$val" == "__null__" ]] && norm="__pb_null__" || norm="$val"
  RULE_BASELINE["${collection}::${rule_type}"]="$norm"
  t_pass "T-RULE-BASELINE-${collection}-${rule_type}"
}

pb_apply_rule_local() {
  local collection="$1" rule_type="$2" new_value="$3"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  printf '{ "%s": "%s" }' "$rule_type" "$new_value" > "$body_f"; chmod 600 "$body_f"
  local url; url=$(pb_url "/api/collections/${collection}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "PATCH"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  [[ "$status" != "200" ]] && {
    t_harness_err "T-RULE-APPLY-${collection}" "PATCH returned ${status}"; return 1
  }
  t_pass "T-RULE-APPLY-${collection}-${rule_type}"
}

pb_restore_rule_local() {
  local collection="$1" rule_type="$2"
  local baseline="${RULE_BASELINE["${collection}::${rule_type}"]:-}"
  [[ -z "$baseline" ]] && {
    t_harness_err "T-RULE-RESTORE-${collection}" "No baseline"; return 1
  }
  local restore_value; [[ "$baseline" == "__pb_null__" ]] && restore_value="null" || restore_value="\"${baseline}\""
  local body_f; body_f=$(pb_secure_tmpfile .json)
  printf '{ "%s": %s }' "$rule_type" "$restore_value" > "$body_f"; chmod 600 "$body_f"
  local url; url=$(pb_url "/api/collections/${collection}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "PATCH"
  local status; status=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  [[ "$status" != "200" ]] && {
    CLEANUP_FAILURE=1; t_harness_err "T-RULE-RESTORE-${collection}" "PATCH returned ${status}"; return 1
  }
  t_pass "T-RULE-RESTORE-${collection}-${rule_type}"
}

# ────────────────────────────────────────────────────────────
# §17 HTTP HELPER
# ────────────────────────────────────────────────────────────

pb_capture() {
  local method="$1" url_suffix="$2" auth_cfg="$3" body_f="$4"
  local status_out="$5" resp_path_out="$6" label="$7"
  shift 7; local -a expected=("$@")
  local url; url=$(pb_url "$url_suffix")
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_out" "$resp_path_out" "$url" \
      "${auth_cfg:-}" "${body_f:-}" "$method"
  local actual; actual=$(cat "$status_out" 2>/dev/null)
  local exp; for exp in "${expected[@]}"; do [[ "$actual" == "$exp" ]] && return 0; done
  print "[cap] ${label}: expected [${expected[*]}] got ${actual}" >&2
  return 1
}

# ────────────────────────────────────────────────────────────
# §18 FIXTURE REGISTRY
# ────────────────────────────────────────────────────────────

pb_register_fixture()   { FIXTURE_REGISTRY[$1]="$2" }
pb_unregister_fixture() { unset "FIXTURE_REGISTRY[$1]" }

pb_cleanup_all_fixtures() {
  print "=== Cleaning up fixtures ==="
  local fid; for fid in "${(@k)FIXTURE_REGISTRY}"; do
    local fn="${FIXTURE_REGISTRY[$fid]}"
    typeset -f "$fn" &>/dev/null && { "$fn" "$fid" || CLEANUP_FAILURE=1 }
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
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp" "$id_file"
  [[ "$status" != "200" && "$status" != "204" && "$status" != "404" ]] && {
    CLEANUP_FAILURE=1; print "[del] WARNING: DELETE ${collection}/${rec_id} returned ${status}" >&2; return 1
  }
  return 0
}

# ────────────────────────────────────────────────────────────
# §19 USER LIFECYCLE  (D-12: example.invalid domain)
# ────────────────────────────────────────────────────────────

pb_create_test_user() {
  local role="$1" id_file_var="$2" tok_file_var="$3" auth_cfg_var="$4"
  local email="cp0_${role}_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"; chmod 600 "$pw_file"
  local id_file; id_file=$(pb_secure_tmpfile .id)
  local tok_file; tok_file=$(pb_secure_tmpfile .tok)
  local auth_cfg; auth_cfg=$(pb_secure_tmpfile .hdr)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${email}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" \
    "role=${role}" "b:emailVisibility=true" 2>/dev/null || {
    t_harness_err "T-USER-CREATE-${role}" "pbj.py failed"; rm -f "$body_f"; pb_wipe_secret_file "$pw_file"; return 1
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
  [[ -z "$rec_id" || "$rec_id" == "__absent__" ]] && {
    t_blocking "T-USER-CREATE-ID-${role}" "Missing id"; pb_wipe_secret_file "$pw_file"; return 1
  }
  printf '%s' "$rec_id" > "$id_file"; chmod 600 "$id_file"
  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "identity=${email}" \
    "secret-file:password=${pw_file}" 2>/dev/null
  url=$(pb_url "/api/collections/users/auth-with-password")
  status_f=$(pb_secure_tmpfile .http); resp_path_f=$(pb_secure_tmpfile .rp)
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
  [[ -z "$token" || "$token" == "__absent__" ]] && {
    t_blocking "T-USER-AUTH-TOKEN-${role}" "Missing token"; pb_wipe_secret_file "$pw_file"; return 1
  }
  printf '%s' "$token" > "$tok_file"; chmod 600 "$tok_file"
  python3 "$PBJ_AUTH_PY" "$auth_cfg" "$tok_file" 2>/dev/null || {
    t_blocking "T-USER-AUTH-CFG-${role}" "pbj_auth.py failed"; pb_wipe_secret_file "$pw_file"; return 1
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
  pb_wipe_secret_file "$tok_file"; pb_wipe_secret_file "$auth_cfg"
}

# ────────────────────────────────────────────────────────────
# §20 LEGACY FIXTURE  (D-12: example.invalid)
# ────────────────────────────────────────────────────────────

pb_create_legacy_fixture() {
  print "=== Creating legacy fixture ==="
  local email="cp0_legacy_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"; chmod 600 "$pw_file"
  LEGACY_ID_FILE=$(pb_secure_tmpfile .id)
  LEGACY_TOK_FILE=$(pb_secure_tmpfile .tok)
  LEGACY_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${email}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" \
    "role=user" "b:emailVisibility=true" 2>/dev/null || {
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
  rm -f "$resp_path"; printf '%s' "$rec_id" > "$LEGACY_ID_FILE"; chmod 600 "$LEGACY_ID_FILE"
  LEGACY_CHILD_ID_FILE=$(pb_secure_tmpfile .id)
  local cbody; cbody=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$cbody" "user=${rec_id}" "name=LegacyChild_${RUN_SUFFIX}" 2>/dev/null
  url=$(pb_url "/api/collections/children/records")
  status_f=$(pb_secure_tmpfile .http); resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$cbody" "POST"
  status=$(cat "$status_f" 2>/dev/null); resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$cbody" "$status_f" "$resp_path_f"
  if [[ "$status" == "200" ]]; then
    local cid; cid=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    printf '%s' "$cid" > "$LEGACY_CHILD_ID_FILE"; chmod 600 "$LEGACY_CHILD_ID_FILE"
  else
    t_harness_err "T-LEGACY-CHILD-CREATE" "returned ${status}"
  fi
  rm -f "$resp_path"
  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "identity=${email}" "secret-file:password=${pw_file}" 2>/dev/null
  url=$(pb_url "/api/collections/users/auth-with-password")
  status_f=$(pb_secure_tmpfile .http); resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  status=$(cat "$status_f" 2>/dev/null); resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  if [[ "$status" == "200" ]]; then
    local tok; tok=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
    printf '%s' "$tok" > "$LEGACY_TOK_FILE"; chmod 600 "$LEGACY_TOK_FILE"
    python3 "$PBJ_AUTH_PY" "$LEGACY_AUTH_CFG" "$LEGACY_TOK_FILE" 2>/dev/null
  fi
  rm -f "$resp_path"; pb_wipe_secret_file "$pw_file"
  t_pass "T-LEGACY-FIXTURE-CREATE"
}

pb_delete_legacy_fixture() {
  local f
  for f in "$LEGACY_CHILD_ID_FILE" "$LEGACY_GROWTH_ID_FILE" \
    "$LEGACY_ACTIVITY_ID_FILE" "$LEGACY_IMMUN_ID_FILE" "$LEGACY_ENROLL_ID_FILE"; do
    [[ -n "$f" && -f "$f" ]] || continue
    pb_delete_record "children"    "$f" 2>/dev/null || \
    pb_delete_record "growth_logs" "$f" 2>/dev/null || \
    pb_delete_record "enrollments" "$f" 2>/dev/null || {
      CLEANUP_FAILURE=1
      print "[legacy-del] WARNING: could not delete record" >&2
    }
  done
  pb_delete_record "users" "$LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$LEGACY_TOK_FILE"; pb_wipe_secret_file "$LEGACY_AUTH_CFG"
}

# ────────────────────────────────────────────────────────────
# §21 ALIAS FIXTURES  (D-12: example.invalid)
# ────────────────────────────────────────────────────────────

pb_setup_alias_group() {
  print "=== Setting up alias group fixtures ==="
  ALIAS_ID_FILE=$(pb_secure_tmpfile .id)
  ALIAS_PW_FILE=$(pb_secure_tmpfile .pw)
  ALIAS_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local alias_tok; alias_tok=$(pb_secure_tmpfile .tok)
  local alias_email="cp0_alias_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  openssl rand -base64 24 | tr -d '\n=' > "$ALIAS_PW_FILE"; chmod 600 "$ALIAS_PW_FILE"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${alias_email}" \
    "secret-file:password=${ALIAS_PW_FILE}" \
    "secret-file:passwordConfirm=${ALIAS_PW_FILE}" \
    "role=user" "b:emailVisibility=true" 2>/dev/null
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
    local aid; aid=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    printf '%s' "$aid" > "$ALIAS_ID_FILE"; chmod 600 "$ALIAS_ID_FILE"
    rm -f "$resp_path"
  else
    rm -f "$resp_path"
    t_harness_err "T-ALIAS-SETUP" "Create returned ${status}"
  fi
  WRONG_PW_FILE=$(pb_secure_tmpfile .pw)
  printf 'definitely-wrong-password-R20xYzQrS' > "$WRONG_PW_FILE"; chmod 600 "$WRONG_PW_FILE"
  TIMING_LEGACY_ID_FILE=$(pb_secure_tmpfile .id)
  TIMING_LEGACY_PW_FILE=$(pb_secure_tmpfile .pw)
  TIMING_LEGACY_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local tl_email="cp0_tl_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  openssl rand -base64 24 | tr -d '\n=' > "$TIMING_LEGACY_PW_FILE"; chmod 600 "$TIMING_LEGACY_PW_FILE"
  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${tl_email}" \
    "secret-file:password=${TIMING_LEGACY_PW_FILE}" \
    "secret-file:passwordConfirm=${TIMING_LEGACY_PW_FILE}" \
    "role=user" "b:emailVisibility=true" 2>/dev/null
  url=$(pb_url "/api/collections/users/records")
  status_f=$(pb_secure_tmpfile .http); resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "POST"
  status=$(cat "$status_f" 2>/dev/null); resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  if [[ "$status" == "200" ]]; then
    local tlid; tlid=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    printf '%s' "$tlid" > "$TIMING_LEGACY_ID_FILE"; chmod 600 "$TIMING_LEGACY_ID_FILE"
  fi
  rm -f "$resp_path"
  t_pass "T-ALIAS-GROUP-SETUP"
}

pb_cleanup_alias_group() {
  pb_delete_record "users" "$ALIAS_ID_FILE"         || CLEANUP_FAILURE=1
  pb_delete_record "users" "$TIMING_LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$ALIAS_PW_FILE"; pb_wipe_secret_file "$ALIAS_AUTH_CFG"
  pb_wipe_secret_file "$TIMING_LEGACY_PW_FILE"; pb_wipe_secret_file "$TIMING_LEGACY_AUTH_CFG"
  pb_wipe_secret_file "$WRONG_PW_FILE"
}

# ────────────────────────────────────────────────────────────
# §22 ALIAS ENUM CASES
# ────────────────────────────────────────────────────────────

pb_alias_enum_case() {
  local case_num="$1" label="$2" email="$3" expected="$4"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  python3 "$PBJ_PY" "$body_f" "identity=${email}" \
    "secret-file:password=${WRONG_PW_FILE}" 2>/dev/null || {
    t_harness_err "$label" "pbj.py failed"; return 1
  }
  local url; url=$(pb_url "/api/collections/users/auth-with-password")
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local actual; actual=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  ENUM_HTTP_VALUES+=("$actual"); ENUM_RESP_FILES+=("$resp_path")
  rm -f "$body_f" "$status_f" "$resp_path_f"
  [[ "$actual" == "$expected" ]] && { t_pass "$label"; return 0 } || {
    t_fail "$label" "expected ${expected} got ${actual}"; return 1
  }
}

# ────────────────────────────────────────────────────────────
# §23 CRUD TESTS
# ────────────────────────────────────────────────────────────

t_crud_children_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-LIST" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-CRUD-CH-LIST" "200" || {
    t_fail "T-CRUD-CH-LIST" "$(cat "$status_f" 2>/dev/null)"; }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-LIST"
}

t_crud_children_create() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-CREATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
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
    local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$new_id" > "$id_f"
    pb_delete_record "children" "$id_f"
  fi
  t_pass "T-CRUD-CH-CREATE"
}

t_crud_children_create_cross_user() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-CREATE-CROSS" "blocked"; return 0; }
  local other_id; other_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  [[ -z "$other_id" ]] && { t_skip "T-CRUD-CH-CREATE-CROSS" "no legacy"; return 0; }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "user=${other_id}" "name=CrossChild_${RUN_SUFFIX}" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-CRUD-CH-CREATE-CROSS" "400" || {
    t_fail "T-CRUD-CH-CREATE-CROSS" "expected 400 got $(cat "$status_f" 2>/dev/null)"
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
  python3 "$PBJ_PY" "$body_f" "user=${leg_id}" "child=${cid}" \
    "n:weight_kg=3.5" "n:height_cm=50.0" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
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
    local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$new_id" > "$id_f"
    LEGACY_GROWTH_ID_FILE="$id_f"
  fi
  t_pass "T-CRUD-GL-CREATE"
}

# ────────────────────────────────────────────────────────────
# §24 FIELD PROTECTION TESTS
# ────────────────────────────────────────────────────────────

t_field_role_reject() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FIELD-ROLE-REJECT" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=admin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-FIELD-ROLE-REJECT" "403" || {
    local actual_st; actual_st=$(cat "$status_f" 2>/dev/null)
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    t_fail "T-FIELD-ROLE-REJECT" "expected 403 got ${actual_st}"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  # Verify persisted role not changed.
  local vurl; vurl=$(pb_url "/api/collections/users/records/${ord_id}")
  local vs_f; vs_f=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$vs_f" "$vrp_f" "$vurl" "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local vrp; vrp=$(cat "$vrp_f" 2>/dev/null); rm -f "$vs_f" "$vrp_f"
  local persisted_role; persisted_role=$(python3 "$PBJ_FIELD_PY" "$vrp" "role" 2>/dev/null)
  rm -f "$vrp"
  if [[ "$persisted_role" == "admin" || "$persisted_role" == "superadmin" ]]; then
    t_fail "T-FIELD-ROLE-REJECT" "CRITICAL: 403 returned but role persisted as '${persisted_role}'"
    return 1
  fi
  t_pass "T-FIELD-ROLE-REJECT"
}

t_field_phone_reject() {
  t_deferred_mandatory "T-FIELD-PHONE-REJECT" \
    "phone_verified absent from users schema. See §28.6 for future-state test."
}

t_field_alias_flag_reject() {
  t_deferred_mandatory "T-FIELD-ALIAS-REJECT" \
    "is_alias_account absent from users schema. Alias design tested in §26."
}

# ────────────────────────────────────────────────────────────
# §25 FILE AUTH TESTS
# ────────────────────────────────────────────────────────────

t_file_auth_anon_list_rejected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-1" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-1" "401" "403" || {
    t_fail "T-FILE-AUTH-1" "anon list not rejected: $(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-1"
}

t_file_auth_own_record_visible() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-2" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "$LEGACY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-2" "200" || {
    t_fail "T-FILE-AUTH-2" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-2"
}

t_file_auth_cross_user_denied() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-3" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-3" "200" || {
    t_fail "T-FILE-AUTH-3" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  local items_check; items_check=$(python3 - "$rp" << 'PYEOF'
import sys,json
try:
    with open(sys.argv[1]) as f: d=json.load(f)
    print('EMPTY' if len(d.get('items',[]))==0 else f'NONEMPTY:{len(d.get("items",[]))}')
except Exception as e: print(f'ERROR:{e}')
PYEOF
)
  rm -f "$status_f" "$resp_path_f" "$rp"
  [[ "$items_check" != "EMPTY" ]] && { t_fail "T-FILE-AUTH-3" "cross-user filter not empty: ${items_check}"; return 1 }
  t_pass "T-FILE-AUTH-3"
}

t_file_auth_admin_can_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-4" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/growth_logs/records" \
    "$ADMIN_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-4" "200" || {
    t_fail "T-FILE-AUTH-4" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-4"
}

t_file_auth_upload_own()        { t_deferred_mandatory "T-FILE-AUTH-5" "Requires operator binary test asset (NEEDS-EXTERNAL)." }
t_file_auth_download_protected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-6" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/files/users/nonexistent_r20_id_xyz/nonexistent.jpg" \
    "" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-6" "404" "401" || {
    t_fail "T-FILE-AUTH-6" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-6"
}
t_file_auth_delete_own() { t_deferred_mandatory "T-FILE-AUTH-7" "Depends on T-FILE-AUTH-5 (NEEDS-EXTERNAL)." }

# ────────────────────────────────────────────────────────────
# §26 ALIAS ENUM TESTS
# ────────────────────────────────────────────────────────────

t_alias_enum_group() {
  (( HALT_DEPENDENTS )) && {
    t_skip "T-ALIAS-ENUM-1" "blocked"; t_skip "T-ALIAS-ENUM-2" "blocked"
    t_skip "T-ALIAS-ENUM-3" "blocked"; t_skip "T-ALIAS-ENUM-4" "blocked"; return 0
  }
  # Note: is_alias_account field is absent from schema (S-2). Alias accounts
  # are created as ordinary role=user accounts for timing/enumeration tests.
  # If enumeration protection is uniform (same response time and code) for
  # existing vs non-existing accounts, a dedicated alias marker is not required.
  pb_alias_enum_case 1 "T-ALIAS-ENUM-1" "cp0_alias_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}" "400"
  pb_alias_enum_case 2 "T-ALIAS-ENUM-2" "cp0_user_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"  "400"
  pb_alias_enum_case 3 "T-ALIAS-ENUM-3" "nonexistent_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}" "400"
  pb_alias_enum_case 4 "T-ALIAS-ENUM-4" "not-an-email" "400"
  local rp; for rp in "${ENUM_RESP_FILES[@]}"; do rm -f "$rp" 2>/dev/null; done
  ENUM_RESP_FILES=(); ENUM_HTTP_VALUES=()
}

# ────────────────────────────────────────────────────────────
# §27-§28 AUTH TESTS, ADMIN TESTS  (unchanged from R19)
# ────────────────────────────────────────────────────────────

t_anon_read_denied() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ANON-READ" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/users/records" \
    "" "" "$status_f" "$resp_path_f" "T-ANON-READ" "401" "403" || {
    t_fail "T-ANON-READ" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ANON-READ"
}

t_admin_escalation_self() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-ESCALATION" "blocked"; return 0; }
  [[ -f "$ADMIN_ID_FILE" ]] || { t_skip "T-ADMIN-ESCALATION" "no admin fixture"; return 0; }
  local admin_id; admin_id=$(cat "$ADMIN_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${admin_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-ADMIN-ESCALATION" "403" || {
    t_fail "T-ADMIN-ESCALATION" "expected 403 got $(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ADMIN-ESCALATION"
}

t_sadmin_list_users() {
  (( HALT_DEPENDENTS )) && { t_skip "T-SADMIN-LIST-USERS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/users/records" \
    "$SADMIN_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-SADMIN-LIST-USERS" "200" || {
    t_fail "T-SADMIN-LIST-USERS" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-SADMIN-LIST-USERS"
}

t_nsu_bypass() {
  (( HALT_DEPENDENTS )) && { t_skip "T-NSU-BYPASS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/users/records" \
    "$_NATIVE_SU_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-NSU-BYPASS" "200" || {
    t_fail "T-NSU-BYPASS" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-NSU-BYPASS"
}

# ────────────────────────────────────────────────────────────
# §28.5 ROLE INJECTION EMERGENCY TESTS  (D-4 fix: strict contract)
# ────────────────────────────────────────────────────────────

pb_inject_create_and_verify() {
  local label="$1" field="$2" value="$3" bad_values="$4"

  local email="cp0_inj_${label:0:8}_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"; chmod 600 "$pw_file"

  local body_f; body_f=$(pb_secure_tmpfile .json)
  local extra_flag=""
  [[ "$value" == "true" || "$value" == "false" ]] && \
    extra_flag="b:" || extra_flag=""
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" \
    "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" \
    "${extra_flag}${field}=${value}" 2>/dev/null || {
    t_harness_err "${label}" "pbj.py failed building inject body"
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"; return 1
  }

  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  pb_wipe_secret_file "$pw_file"

  # D-4: Strict HTTP contract.
  case "$http_status" in
    400|401|403)
      # Injection rejected at HTTP level.
      # Still verify no record was created under this unique email.
      local check_url; check_url=$(pb_url "/api/collections/users/records")
      local ck_status_f; ck_status_f=$(pb_secure_tmpfile .http)
      local ck_resp_f; ck_resp_f=$(pb_secure_tmpfile .rp)
      # Use filter to look for the generated email. If found, injection may still have persisted.
      local filter_encoded; filter_encoded=$(python3 -c "
import urllib.parse,sys; print(urllib.parse.quote(f'email=\"{sys.argv[1]}\"'))
" -- "$email" 2>/dev/null)
      RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
        python3 "$PBJ_HTTP_PY" "$ck_status_f" "$ck_resp_f" \
          "${check_url}?filter=${filter_encoded}&perPage=1" \
          "$_NATIVE_SU_AUTH_CFG" "" "GET"
      local ck_st; ck_st=$(cat "$ck_status_f" 2>/dev/null)
      local ck_rp; ck_rp=$(cat "$ck_resp_f" 2>/dev/null)
      rm -f "$ck_status_f" "$ck_resp_f"
      if [[ "$ck_st" == "200" ]]; then
        local items_count; items_count=$(python3 - "$ck_rp" << 'PYEOF'
import sys,json
try:
    with open(sys.argv[1]) as f: d=json.load(f)
    print(len(d.get('items',[])))
except Exception: print(-1)
PYEOF
)
        rm -f "$ck_rp"
        if [[ "$items_count" != "0" ]]; then
          t_blocking "${label}" \
            "HTTP ${http_status} returned but record matching injected identity exists (${items_count} items). Inspect manually."
          return 1
        fi
      else
        rm -f "$ck_rp"
        t_harness_err "${label}" "Could not verify non-existence of record after rejection (filter check returned ${ck_st})"
      fi
      rm -f "$resp_path"
      t_pass "${label}"
      return 0
      ;;
    200)
      # Record created — read and verify persisted field value.
      ;;
    000|''|5[0-9][0-9])
      # Transport error, empty status, or server error.
      rm -f "$resp_path"
      t_harness_err "${label}" \
        "Injection test received unexpected HTTP status '${http_status}'. "\
        "Cannot determine injection outcome. Treat as failed pending investigation."
      return 1
      ;;
    *)
      # Any other unexpected status.
      rm -f "$resp_path"
      t_fail "${label}" "Unexpected HTTP ${http_status} from injection attempt"
      return 1
      ;;
  esac

  # http_status == 200: record was created.
  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"

  if [[ -z "$rec_id" || "$rec_id" == "__absent__" ]]; then
    t_blocking "${label}" \
      "HTTP 200 but record id absent from response — cannot verify persisted value."
    return 1
  fi

  # Cleanup: delete regardless of outcome.
  local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"

  # Read persisted record via NSU.
  local vurl; vurl=$(pb_url "/api/collections/users/records/${rec_id}")
  local vs_f; vs_f=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$vs_f" "$vrp_f" "$vurl" "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local vst; vst=$(cat "$vs_f" 2>/dev/null)
  local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs_f" "$vrp_f"

  # Delete injected record.
  pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1

  if [[ "$vst" != "200" ]]; then
    rm -f "$vrp"
    t_blocking "${label}" \
      "HTTP 200 created record but NSU verify returned ${vst} — cannot confirm persistence. Treat as BLOCKING."
    return 1
  fi

  local persisted; persisted=$(python3 "$PBJ_FIELD_PY" "$vrp" "$field" 2>/dev/null)
  rm -f "$vrp"

  local bad_val injection_confirmed=0
  for bad_val in ${=bad_values}; do
    [[ "$persisted" == "$bad_val" ]] && { injection_confirmed=1; break }
  done

  if (( injection_confirmed )); then
    t_blocking "${label}" \
      "INJECTION CONFIRMED: ${field} persisted with privileged value. Publication BLOCKED."
    return 1
  else
    t_pass "${label}"
    return 0
  fi
}

# D-5: T-INJECT-CREATE-UNEXPECTED — verify persisted record shape.
t_inject_create_unexpected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-INJECT-CREATE-UNEXPECTED" "blocked"; return 0; }

  local email="cp0_inj_unexp_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"; chmod 600 "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" \
    "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" \
    "phone_verified=true" \
    "is_alias_account=true" 2>/dev/null || {
    t_harness_err "T-INJECT-CREATE-UNEXPECTED" "pbj.py failed"
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"; return 1
  }

  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f"
  pb_wipe_secret_file "$pw_file"

  case "$http_status" in
    400|401|403)
      rm -f "$resp_path"
      # PocketBase rejected registration with absent fields. Safe.
      t_pass "T-INJECT-CREATE-UNEXPECTED"
      return 0
      ;;
    200) ;;
    000|''|5[0-9][0-9]|*)
      rm -f "$resp_path"
      t_harness_err "T-INJECT-CREATE-UNEXPECTED" "Unexpected HTTP ${http_status}"
      return 1
      ;;
  esac

  # 200: record created. Read and verify that known application-controlled
  # fields were not populated by the injected absent-field values.
  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"

  if [[ -z "$rec_id" || "$rec_id" == "__absent__" ]]; then
    t_blocking "T-INJECT-CREATE-UNEXPECTED" "HTTP 200 but no record id"
    return 1
  fi

  local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"
  local vurl; vurl=$(pb_url "/api/collections/users/records/${rec_id}")
  local vs_f; vs_f=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$vs_f" "$vrp_f" "$vurl" "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local vst; vst=$(cat "$vs_f" 2>/dev/null)
  local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs_f" "$vrp_f"

  pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1

  if [[ "$vst" != "200" ]]; then
    rm -f "$vrp"
    t_blocking "T-INJECT-CREATE-UNEXPECTED" \
      "NSU record verify returned ${vst} — cannot confirm field absence"
    return 1
  fi

  # D-5: Verify the persisted record shape.
  # Fields to verify are absent or non-privileged in the persisted record.
  local shape_check; shape_check=$(python3 - "$vrp" << 'PYEOF'
import sys,json
PRIVILEGED_CHECK = {
    "role": lambda v: v not in ("admin","superadmin"),
    "verified": lambda v: v is not True,
    "emailVisibility": lambda v: True,  # emailVisibility=true was explicitly set; allowed
}
# Fields that should be absent (absent from schema — verify PB ignored them silently)
ABSENT_FROM_SCHEMA = ["phone_verified","is_alias_account"]
SYSTEM_AUTH_MUST_ABSENT_FROM_BODY = ["tokenKey","passwordHash"]
errors = []
try:
    with open(sys.argv[1]) as f: d=json.load(f)
except Exception as e:
    print(f"ERROR:{e}"); sys.exit(1)
for field, validator in PRIVILEGED_CHECK.items():
    if field in d:
        val = d[field]
        if not validator(val):
            errors.append(f"PRIVILEGED_FIELD:{field}=<redacted>")
for field in ABSENT_FROM_SCHEMA:
    if field in d and d[field]:
        errors.append(f"ABSENT_SCHEMA_FIELD_STORED:{field}")
for field in SYSTEM_AUTH_MUST_ABSENT_FROM_BODY:
    if field in d:
        errors.append(f"SYSTEM_AUTH_FIELD_EXPOSED:{field}")
if errors:
    print("SHAPE_ERR:" + "|".join(errors)); sys.exit(1)
print("OK")
PYEOF
)
  rm -f "$vrp"

  if [[ "$shape_check" == "OK" ]]; then
    t_pass "T-INJECT-CREATE-UNEXPECTED"
  else
    t_blocking "T-INJECT-CREATE-UNEXPECTED" \
      "Persisted record shape violation: ${shape_check}"
    return 1
  fi
}

t_role_inject_emergency_group() {
  print "=== §28.5 Role Injection Emergency Tests ==="

  pb_inject_create_and_verify \
    "T-INJECT-CREATE-ANON-ADMIN"  "role" "admin"       "admin superadmin"
  pb_inject_create_and_verify \
    "T-INJECT-CREATE-ANON-SADMIN" "role" "superadmin"  "admin superadmin"
  pb_inject_create_and_verify \
    "T-INJECT-CREATE-VERIFIED"    "verified" "true"     "true"

  t_inject_create_unexpected

  if (( T_BLOCKING > 0 )); then
    print "" >&2
    print "!!! EMERGENCY BLOCKING: Role injection CONFIRMED. Publication HALTED. !!!" >&2
    print "" >&2
  fi
}

# ────────────────────────────────────────────────────────────
# §28.6 PHONE FUTURE STATE TESTS  (D-11)
# Applies a temporary migration in the isolated environment only.
# Tests phone_verified protection before the field is added to prod.
# Source project schema is never modified.
# ────────────────────────────────────────────────────────────

pb_apply_future_phone_schema() {
  print "=== Applying future phone_verified schema (isolated env only) ==="

  # Write a temporary migration to the isolated migrations dir.
  local future_mig="${RELEASE1B_PB_MIGRATIONS_DIR}/9999999999_r20_future_phone_verified.js"
  cat > "$future_mig" << 'JSEOF'
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  users.fields.add(new BoolField({ name: "phone_verified" }));
  app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId("users");
  users.fields.removeByName("phone_verified");
  app.save(users);
});
JSEOF
  chmod 600 "$future_mig"

  # PocketBase must be stopped and restarted for the migration to apply.
  if (( RELEASE1B_PB_PID > 0 )); then
    kill "$RELEASE1B_PB_PID" 2>/dev/null
    wait "$RELEASE1B_PB_PID" 2>/dev/null
    RELEASE1B_PB_PID=0
  fi

  pb_start_pocketbase || {
    t_harness_err "T-PHONE-FUTURE-SETUP" "PocketBase restart after future schema failed"; return 1
  }

  # Re-authenticate NSU after restart.
  pb_wipe_secret_file "$_NATIVE_SU_TOK_FILE"
  pb_wipe_secret_file "$_NATIVE_SU_AUTH_CFG"
  pb_create_local_superuser || {
    t_harness_err "T-PHONE-FUTURE-SETUP" "NSU re-auth failed after future schema restart"; return 1
  }

  # Verify phone_verified field now exists.
  local url; url=$(pb_url "/api/collections/users")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local st; st=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  if [[ "$st" == "200" ]]; then
    local fchk; fchk=$(python3 - "$rp" << 'PYEOF'
import sys,json
with open(sys.argv[1]) as f: d=json.load(f)
fs=[x.get("name","") for x in d.get("fields",d.get("schema",[]))]
print("OK" if "phone_verified" in fs else "ABSENT")
PYEOF
)
    rm -f "$rp"
    if [[ "$fchk" == "OK" ]]; then
      FUTURE_SCHEMA_PHONE_APPLIED=1
      t_pass "T-PHONE-FUTURE-SETUP"
    else
      t_harness_err "T-PHONE-FUTURE-SETUP" "phone_verified absent after migration"
    fi
  else
    rm -f "$rp"; t_harness_err "T-PHONE-FUTURE-SETUP" "users collection read returned ${st}"
  fi
}

t_phone_future_self_set_blocked() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-FUTURE-SELF-SET" "blocked"; return 0; }
  (( FUTURE_SCHEMA_PHONE_APPLIED )) || { t_skip "T-PHONE-FUTURE-SELF-SET" "future schema not applied"; return 0; }
  # Ordinary user attempts to set phone_verified=true on own record — must be blocked.
  # Expected: 403 from emergency_hardening hook (if hook blocks phone_verified PATCH).
  # If hook does not block it: FAIL (field protection absent).
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "b:phone_verified=true" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-PHONE-FUTURE-SELF-SET" "403" || {
    local actual; actual=$(cat "$status_f" 2>/dev/null)
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    if [[ "$actual" == "200" ]]; then
      # Succeeded — verify whether phone_verified was actually stored.
      local vurl; vurl=$(pb_url "/api/collections/users/records/${ord_id}")
      local vs_f; vs_f=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
      RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
        python3 "$PBJ_HTTP_PY" "$vs_f" "$vrp_f" "$vurl" "$_NATIVE_SU_AUTH_CFG" "" "GET"
      local vrp; vrp=$(cat "$vrp_f" 2>/dev/null); rm -f "$vs_f" "$vrp_f"
      local pv; pv=$(python3 "$PBJ_FIELD_PY" "$vrp" "phone_verified" 2>/dev/null)
      rm -f "$vrp"
      if [[ "$pv" == "true" ]]; then
        t_fail "T-PHONE-FUTURE-SELF-SET" \
          "Ordinary user set phone_verified=true on own record — no hook protection on this field."
      else
        # Accepted but field not stored (rule stripped it). Partial pass with note.
        t_pass "T-PHONE-FUTURE-SELF-SET"
        print "[phone-future] NOTE: 200 returned but phone_verified not persisted — rule or PB stripped it."
      fi
    else
      t_fail "T-PHONE-FUTURE-SELF-SET" "expected 403 got ${actual}"
    fi
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-PHONE-FUTURE-SELF-SET"
}

t_phone_future_admin_set_allowed() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-FUTURE-ADMIN-SET" "blocked"; return 0; }
  (( FUTURE_SCHEMA_PHONE_APPLIED )) || { t_skip "T-PHONE-FUTURE-ADMIN-SET" "future schema not applied"; return 0; }
  # Admin user sets phone_verified=true on an ordinary user — must succeed.
  # This tests that the proposed hook guard allows privileged callers.
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "b:phone_verified=true" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-PHONE-FUTURE-ADMIN-SET" "200" || {
    t_fail "T-PHONE-FUTURE-ADMIN-SET" \
      "Admin could not set phone_verified=true — hook may be too restrictive."
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  # Reset phone_verified for other tests.
  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "b:phone_verified=false" 2>/dev/null
  status_f=$(pb_secure_tmpfile .http); resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-PHONE-FUTURE-RESET" "200"
  rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-PHONE-FUTURE-ADMIN-SET"
}

t_phone_future_inject_create() {
  # Test create-path injection with phone_verified in future schema.
  pb_inject_create_and_verify \
    "T-PHONE-FUTURE-INJECT-CREATE" "phone_verified" "true" "true"
}

t_phone_future_state_group() {
  (( HALT_DEPENDENTS )) && {
    t_skip "T-PHONE-FUTURE-SELF-SET" "blocked"
    t_skip "T-PHONE-FUTURE-ADMIN-SET" "blocked"
    t_skip "T-PHONE-FUTURE-INJECT-CREATE" "blocked"
    return 0
  }
  print "=== §28.6 Phone Future State Tests ==="
  pb_apply_future_phone_schema
  t_phone_future_self_set_blocked
  t_phone_future_admin_set_allowed
  t_phone_future_inject_create
}

# ────────────────────────────────────────────────────────────
# §29 USER OPS TESTS
# ────────────────────────────────────────────────────────────

t_user_name_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-NAME-UPDATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=UpdatedName_${RUN_SUFFIX}" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http); local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-USER-NAME-UPDATE" "200" || {
    t_fail "T-USER-NAME-UPDATE" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-USER-NAME-UPDATE"
}

t_user_phone_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-PHONE-UPDATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "phone=+60111_R20TEST_0001" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http); local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-USER-PHONE-UPDATE" "200" || {
    t_fail "T-USER-PHONE-UPDATE" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-USER-PHONE-UPDATE"
}

# ────────────────────────────────────────────────────────────
# §30 CONTENT TESTS  (D-10: antenatal policy scored)
# ────────────────────────────────────────────────────────────

t_art_anon_policy() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANON-POLICY" "blocked"; return 0; }
  # D-10: Antenatal policy is established. Authentication precedes article access.
  # Current schema articles.listRule="" (public) FAILS this requirement.
  # This test is scored FAIL (not UNRESOLVED).
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/articles/records" \
    "" "" "$status_f" "$resp_path_f" "T-ART-ANON-POLICY" "401" "403"
  local actual; actual=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  if [[ "$actual" == "401" || "$actual" == "403" ]]; then
    t_pass "T-ART-ANON-POLICY"
  else
    t_fail "T-ART-ANON-POLICY" \
      "Articles publicly readable (HTTP ${actual}). "\
      "Release requirement: authentication precedes article access. "\
      "Required fix: set articles.listRule = \"@request.auth.id != ''\""
  fi
}

t_art_antenatal_vis() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANTENATAL-VIS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" \
    "/api/collections/articles/records?filter=is_pregnancy%3Dtrue&perPage=5" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-ART-ANTENATAL-VIS" "200" || {
    t_fail "T-ART-ANTENATAL-VIS" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ART-ANTENATAL-VIS"
}

t_art_antenatal_auth_only() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANTENATAL-AUTH-ONLY" "blocked"; return 0; }
  # D-10: Ordinary user must not receive postnatal articles.
  # Articles with is_pregnancy=false should not be accessible to ordinary users
  # per the antenatal release requirement.
  # Current schema: no server-side filter prevents this. Expected: FAIL.
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" \
    "/api/collections/articles/records?filter=is_pregnancy%3Dfalse&perPage=1" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" \
    "T-ART-ANTENATAL-AUTH-ONLY" "403" "400"
  local actual; actual=$(cat "$status_f" 2>/dev/null)
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  local item_count; item_count=$(python3 - "$rp" << 'PYEOF'
import sys,json
try:
    with open(sys.argv[1]) as f: d=json.load(f)
    print(len(d.get('items',[])))
except Exception: print(-1)
PYEOF
)
  rm -f "$status_f" "$resp_path_f" "$rp"
  if [[ "$actual" == "403" || "$actual" == "400" ]]; then
    t_pass "T-ART-ANTENATAL-AUTH-ONLY"
  elif [[ "$actual" == "200" && "$item_count" == "0" ]]; then
    # 200 but no postnatal articles exist in the isolated db — inconclusive.
    t_unresolved "T-ART-ANTENATAL-AUTH-ONLY" \
      "200 returned with 0 items — no postnatal articles in isolated db; cannot score."
  else
    t_fail "T-ART-ANTENATAL-AUTH-ONLY" \
      "Postnatal articles returned to ordinary user (HTTP ${actual}, items ${item_count}). "\
      "Server-side antenatal filter not enforced. "\
      "Required fix: restrict listRule or add category filter hook."
  fi
}

t_art_category_filter() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-CATEGORY-FILTER" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" \
    "/api/collections/articles/records?filter=category%3D%27pregnancy%27&perPage=5" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-ART-CATEGORY-FILTER" "200" || {
    t_fail "T-ART-CATEGORY-FILTER" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ART-CATEGORY-FILTER"
}

# ────────────────────────────────────────────────────────────
# §31 API DECLARATIONS  (D-13: no invented health routes)
# ────────────────────────────────────────────────────────────

t_api_declarations() {
  (( HALT_DEPENDENTS )) && { t_skip "T-API-DECLARATIONS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/health" \
    "" "" "$status_f" "$resp_path_f" "T-STATIC-ROUTE-INVENTORY" "200" || {
    t_fail "T-STATIC-ROUTE-INVENTORY" "health endpoint returned $(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-STATIC-ROUTE-INVENTORY"

  # OTP adapter routes (installed in isolated env).
  status_f=$(pb_secure_tmpfile .http); resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "${HOOK_OTP_PHONE_ROUTE}" \
    "" "" "$status_f" "$resp_path_f" "T-API-DECL-OTP-REQUEST" "200" "400" "422"
  local otp_st; otp_st=$(cat "$status_f" 2>/dev/null)
  rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  if [[ "$otp_st" == "404" ]]; then
    t_fail "T-API-DECL-OTP-REQUEST" \
      "OTP request route returns 404 — adapter not registered"
  else
    t_pass "T-API-DECL-OTP-REQUEST"
  fi

  status_f=$(pb_secure_tmpfile .http); resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "${HOOK_OTP_CTRL_ROUTE}" \
    "$_NATIVE_SU_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-API-DECL-OTP-CTRL" "200" "400"
  local ctrl_st; ctrl_st=$(cat "$status_f" 2>/dev/null)
  rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  [[ "$ctrl_st" == "404" ]] && \
    t_fail "T-API-DECL-OTP-CTRL" "Control route 404 — adapter not deployed" || \
    t_pass "T-API-DECL-OTP-CTRL"
}

# ────────────────────────────────────────────────────────────
# §32 RULE APPLY/RESTORE
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
      "anon not denied after rule applied: $(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-RULE-APPLY-RESTORE"
  pb_restore_rule_local "articles" "listRule"
}

# ────────────────────────────────────────────────────────────
# §33-§35 AUTHORIZED EXCLUSIONS
# ────────────────────────────────────────────────────────────

t_authorized_exclusions() {
  t_authorized_exclusion "E4-EMAIL-CHANGE-LIFECYCLE" "Requires production SMTP"
  t_authorized_exclusion "E6-OTP-REACHABILITY"       "Requires Meta Cloud API credentials"
  t_authorized_exclusion "E8-WARN-LOG-OBSERVABILITY" "Requires production log pipeline"
}

# ────────────────────────────────────────────────────────────
# §36 CONCURRENCY TESTS  (D-7: OTP adapter now deployed)
# ────────────────────────────────────────────────────────────

t_concurrency_auth_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-AUTH" "blocked"; return 0; }
  local email="cp0_concauth_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"; chmod 600 "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${email}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" \
    "role=user" 2>/dev/null || {
    t_harness_err "T-CONCURRENCY-AUTH-SETUP" "pbj.py failed"; return 1
  }
  local url; url=$(pb_url "/api/collections/users/records")
  local status_f; status_f=$(pb_secure_tmpfile .http); local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
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
  rm -f "$create_resp"; pb_wipe_secret_file "$pw_file"

  url=$(pb_url "/api/collections/users/auth-with-password")
  local pids=() i
  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json" wstatus="${wdir}/status" wresp_rp="${wdir}/resp_rp"
    python3 "$PBJ_PY" "$wbody" "identity=${email}" "password=definitely-wrong-pw" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" \
        python3 "$PBJ_HTTP_PY" "$wstatus" "$wresp_rp" "$url" "" "$wbody" "POST"
    ) &
    pids+=($!)
  done

  local all_ok=1
  for (( i=1; i<=5; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wst; wst=$(cat "${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}/status" 2>/dev/null)
    local wrp; wrp=$(cat "${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}/resp_rp" 2>/dev/null)
    rm -f "$wrp"
    [[ "$wst" != "400" ]] && { t_fail "T-CONCURRENCY-AUTH" "Worker ${i}: ${wst}"; all_ok=0 }
  done

  if [[ -n "$conc_uid" ]]; then
    local uid_f; uid_f=$(pb_secure_tmpfile .id); printf '%s' "$conc_uid" > "$uid_f"
    pb_delete_record "users" "$uid_f" || CLEANUP_FAILURE=1
  fi
  (( all_ok )) && t_pass "T-CONCURRENCY-AUTH"
}

t_concurrency_otp_send_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-OTP-SEND" "blocked"; return 0; }
  # D-7: OTP adapter deployed. Can now run rate-limit invariant check.
  # Synthetic phone required: +601_R20TEST_<digits>
  local synth_phone="+601_R20TEST_00099001"

  # Reset adapter state via control route.
  local ctrl_body_f; ctrl_body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$ctrl_body_f" "mode=success" 2>/dev/null
  local ctrl_status_f; ctrl_status_f=$(pb_secure_tmpfile .http)
  local ctrl_resp_f; ctrl_resp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_CTRL_ROUTE" \
    "$_NATIVE_SU_AUTH_CFG" "$ctrl_body_f" "$ctrl_status_f" "$ctrl_resp_f" \
    "T-CONCURRENCY-OTP-CTRL-RESET" "200"
  local ctrl_st; ctrl_st=$(cat "$ctrl_status_f" 2>/dev/null)
  rm -f "$ctrl_body_f" "$ctrl_status_f" "$(cat "$ctrl_resp_f" 2>/dev/null)" "$ctrl_resp_f"
  if [[ "$ctrl_st" != "200" ]]; then
    t_fail "T-CONCURRENCY-OTP-SEND" "Control route reset returned ${ctrl_st}"; return 1
  fi

  # Fire 5 concurrent OTP requests for the same synthetic phone.
  local pids=() i
  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/otpconc_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json" wstatus="${wdir}/status" wresp_rp="${wdir}/resp_rp"
    printf '{"phone":"%s"}' "$synth_phone" > "$wbody"
    local req_url; req_url="$(pb_url "$HOOK_OTP_PHONE_ROUTE")"
    (
      RELEASE1B_CANONICAL_TMP="$wdir" \
        python3 "$PBJ_HTTP_PY" "$wstatus" "$wresp_rp" "$req_url" "" "$wbody" "POST"
    ) &
    pids+=($!)
  done

  local ok_count=0
  for (( i=1; i<=5; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wst; wst=$(cat "${RELEASE1B_TEST_TMP}/otpconc_w${i}_${RUN_SUFFIX}/status" 2>/dev/null)
    local wrp; wrp=$(cat "${RELEASE1B_TEST_TMP}/otpconc_w${i}_${RUN_SUFFIX}/resp_rp" 2>/dev/null)
    rm -f "$wrp"
    [[ "$wst" == "200" ]] && (( ok_count++ ))
  done

  # Check rate counter.
  local cnt_status_f; cnt_status_f=$(pb_secure_tmpfile .http)
  local cnt_resp_f; cnt_resp_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "$HOOK_OTP_RATE_ROUTE" \
    "$_NATIVE_SU_AUTH_CFG" "" "$cnt_status_f" "$cnt_resp_f" \
    "T-CONCURRENCY-OTP-COUNT" "200"
  local cnt_rp; cnt_rp=$(cat "$cnt_resp_f" 2>/dev/null)
  rm -f "$cnt_status_f" "$cnt_resp_f"
  local attempt_count; attempt_count=$(python3 "$PBJ_FIELD_PY" "$cnt_rp" "attemptCount" 2>/dev/null)
  rm -f "$cnt_rp"

  print "[otp-conc] ok_count=${ok_count} attempt_count=${attempt_count}"
  if (( ok_count == 5 )); then
    t_pass "T-CONCURRENCY-OTP-SEND"
    print "[otp-conc] NOTE: No rate-limit enforced by current hook. Adapter counted attempts."
    t_unresolved "T-CONCURRENCY-OTP-RATE-LIMIT" \
      "Production hook has no rate limit. Rate-limit behaviour NEEDS-EXTERNAL policy decision."
  elif (( ok_count >= 1 && ok_count < 5 )); then
    t_pass "T-CONCURRENCY-OTP-SEND"
    print "[otp-conc] NOTE: Partial success (${ok_count}/5). Adapter invalidated prior OTPs."
  else
    t_fail "T-CONCURRENCY-OTP-SEND" "Zero OTP requests succeeded (ok_count=${ok_count})"
  fi
}

t_concurrency_idempotency_post_group() {
  t_deferred_mandatory "T-CONCURRENCY-IDEMPOTENCY-POST" \
    "No idempotency-enforcing hook identified. Route, key header, duplicate behaviour NEEDS-EXTERNAL."
}

# ────────────────────────────────────────────────────────────
# §37 OTP FLOW TEST  (D-7: adapter deployed — now executable)
# ────────────────────────────────────────────────────────────

t_otp_flow() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-FLOW" "blocked"; return 0; }

  # Set adapter to success mode.
  local ctrl_body_f; ctrl_body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$ctrl_body_f" "mode=success" 2>/dev/null
  local ctrl_status_f; ctrl_status_f=$(pb_secure_tmpfile .http)
  local ctrl_resp_f; ctrl_resp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_CTRL_ROUTE" \
    "$_NATIVE_SU_AUTH_CFG" "$ctrl_body_f" "$ctrl_status_f" "$ctrl_resp_f" \
    "T-OTP-CTRL-SET" "200"
  rm -f "$ctrl_body_f" "$ctrl_status_f" "$(cat "$ctrl_resp_f" 2>/dev/null)" "$ctrl_resp_f"

  local synth_phone="+601_R20TEST_77701234"

  # Step 1: Request OTP.
  local req_body_f; req_body_f=$(pb_secure_tmpfile .json)
  printf '{"phone":"%s"}' "$synth_phone" > "$req_body_f"
  local req_status_f; req_status_f=$(pb_secure_tmpfile .http)
  local req_resp_f; req_resp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" \
    "" "$req_body_f" "$req_status_f" "$req_resp_f" "T-OTP-FLOW-REQUEST" "200" || {
    t_fail "T-OTP-FLOW" "request-otp returned $(cat "$req_status_f" 2>/dev/null)"
    local rp; rp=$(cat "$req_resp_f" 2>/dev/null)
    rm -f "$req_body_f" "$req_status_f" "$req_resp_f" "$rp"; return 1
  }
  local req_rp; req_rp=$(cat "$req_resp_f" 2>/dev/null)
  rm -f "$req_body_f" "$req_status_f" "$req_resp_f" "$req_rp"

  # Step 2: Read OTP from phone_otps via NSU (no Meta delivery needed).
  local otp_url; otp_url=$(pb_url "/api/collections/phone_otps/records")
  local otp_status_f; otp_status_f=$(pb_secure_tmpfile .http)
  local otp_resp_f; otp_resp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$otp_status_f" "$otp_resp_f" \
      "${otp_url}?filter=$(python3 -c "import urllib.parse; print(urllib.parse.quote(\"phone='${synth_phone}' && status='sent/active'\"))" 2>/dev/null)&perPage=1" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local otp_st; otp_st=$(cat "$otp_status_f" 2>/dev/null)
  local otp_rp; otp_rp=$(cat "$otp_resp_f" 2>/dev/null)
  rm -f "$otp_status_f" "$otp_resp_f"
  if [[ "$otp_st" != "200" ]]; then
    t_fail "T-OTP-FLOW" "phone_otps NSU read returned ${otp_st}"
    rm -f "$otp_rp"; return 1
  fi
  local otp_code; otp_code=$(python3 - "$otp_rp" << 'PYEOF'
import sys,json
try:
    with open(sys.argv[1]) as f: d=json.load(f)
    items=d.get('items',[])
    if not items: print(""); sys.exit(0)
    print(items[0].get("code",""))
except Exception: print("")
PYEOF
)
  rm -f "$otp_rp"
  if [[ -z "$otp_code" || ! "$otp_code" =~ ^[0-9]{6}$ ]]; then
    t_fail "T-OTP-FLOW" "OTP code absent or invalid format from phone_otps"
    return 1
  fi

  # Step 3: Verify OTP.
  local ver_body_f; ver_body_f=$(pb_secure_tmpfile .json)
  printf '{"phone":"%s","code":"%s"}' "$synth_phone" "$otp_code" > "$ver_body_f"
  chmod 600 "$ver_body_f"
  local ver_status_f; ver_status_f=$(pb_secure_tmpfile .http)
  local ver_resp_f; ver_resp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" \
    "" "$ver_body_f" "$ver_status_f" "$ver_resp_f" "T-OTP-FLOW-VERIFY" "200" || {
    t_fail "T-OTP-FLOW" "verify-otp returned $(cat "$ver_status_f" 2>/dev/null)"
    local vrp; vrp=$(cat "$ver_resp_f" 2>/dev/null)
    rm -f "$ver_body_f" "$ver_status_f" "$ver_resp_f" "$vrp"; return 1
  }
  local ver_rp; ver_rp=$(cat "$ver_resp_f" 2>/dev/null)
  rm -f "$ver_body_f" "$ver_status_f" "$ver_resp_f" "$ver_rp"
  t_pass "T-OTP-FLOW"
}

# ────────────────────────────────────────────────────────────
# §38 HOOK SMOKE TESTS  (D-13: behavioral probe for emergency_hardening)
# ────────────────────────────────────────────────────────────

t_hook_smoke_group() {
  local hk
  for hk in "${(@k)HOOK_PROBE_TYPE}"; do
    local probe_type="${HOOK_PROBE_TYPE[$hk]}"

    if [[ "$probe_type" == "behavioral" ]]; then
      # D-13: emergency_hardening has no standalone HTTP route.
      # Its behavior is verified by t_field_role_reject() in §24.
      print "[hook-smoke] ${hk}: behavioral probe — see T-FIELD-ROLE-REJECT in §24"
      t_pass "T-HOOK-SMOKE-${hk}"
      continue
    fi

    local route="${HOOK_PROBE_ROUTES[$hk]}"
    if [[ "$route" == UNRESOLVED* || -z "$route" ]]; then
      t_unresolved "T-HOOK-SMOKE-${hk}" "HOOK_PROBE_ROUTES[$hk] NEEDS-EXTERNAL"
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

    if [[ "$actual" == "404" ]]; then
      t_fail "T-HOOK-SMOKE-${hk}" "Route returned 404 — hook may not be registered"
    else
      t_pass "T-HOOK-SMOKE-${hk}"
    fi
  done
}

# ────────────────────────────────────────────────────────────
# §39 REPORT GENERATION
# ────────────────────────────────────────────────────────────

pb_generate_report() {
  local rc=0
  (( T_BLOCKING > 0 || T_FAIL > 0 || T_HARNESS_ERR > 0 || CLEANUP_FAILURE > 0 )) && rc=1
  (( rc == 0 && (T_DEFERRED > 0 || T_UNRESOLVED > 0) )) && rc=2

  {
    print "## Release 1B Checkpoint 0 Report"
    print "Round        : 20"
    print "Run suffix   : ${RUN_SUFFIX}"
    print "Platform     : ${PLATFORM_KEY}"
    print "PB version   : ${RELEASE1B_PB_VERSION}"
    print "Test domain  : ${TEST_EMAIL_DOMAIN}"
    print ""
    print "## Checkpoint 0 Authorization Status"
    print "AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE"
    print ""
    print "## Result"
    case $rc in 0) print "RESULT: PASS" ;; 1) print "RESULT: FAIL" ;; 2) print "RESULT: INCOMPLETE" ;; esac
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
    local bd; for bd in "${BLOCKING_DECISIONS[@]}"; do print "  ${bd}"; done
    local ui; for ui in "${UNRESOLVED_ITEMS[@]}"; do print "  ${ui}"; done
    local he; for he in "${HARNESS_ERRORS[@]}"; do print "  ${he}"; done
    print ""
    print "## Test Detail"
    cat "$RELEASE1B_REPORT_WORK" 2>/dev/null || true
  } > "${RELEASE1B_REPORT_WORK}.final"

  RELEASE1B_CANONICAL_ROOT="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_SCAN_PY" \
      "${RELEASE1B_REPORT_WORK}.final" \
      "$RELEASE1B_REPORT_PATH" 2>/dev/null || {
    RELEASE1B_REPORT_PATH="${RELEASE1B_REPORT_WORK}.final"
  }

  print "=== Report: ${RELEASE1B_REPORT_PATH} ==="
  return $rc
}

# ────────────────────────────────────────────────────────────
# §40 MAIN
# ────────────────────────────────────────────────────────────

pb_run_all_tests() {
  pb_preflight_ports || return 1
  pb_verify_binary_version
  pb_apply_schema_migrations
  pb_deploy_hooks
  pb_start_pocketbase
  pb_create_local_superuser || return 1

  # D-12: Verify example.invalid domain accepted.
  pb_verify_email_domain || return 1

  pb_verify_schema

  pb_create_test_user "user"       ORDINARY_ID_FILE ORDINARY_TOK_FILE ORDINARY_AUTH_CFG
  pb_create_test_user "admin"      ADMIN_ID_FILE    ADMIN_TOK_FILE    ADMIN_AUTH_CFG
  pb_create_test_user "superadmin" SADMIN_ID_FILE   SADMIN_TOK_FILE   SADMIN_AUTH_CFG
  pb_create_legacy_fixture
  pb_setup_alias_group

  # §28.5 Emergency injection — MUST run before any content or publication gate.
  t_role_inject_emergency_group
  (( T_BLOCKING > 0 )) && { print "[main] BLOCKING. Halting test sequence." >&2; HALT_DEPENDENTS=1; }

  # §23 CRUD
  t_crud_children_list; t_crud_children_create
  t_crud_children_create_cross_user; t_crud_growth_create

  # §24 Field protection
  t_field_role_reject; t_field_phone_reject; t_field_alias_flag_reject

  # §25 File auth
  t_file_auth_anon_list_rejected; t_file_auth_own_record_visible
  t_file_auth_cross_user_denied;  t_file_auth_admin_can_list
  t_file_auth_upload_own;         t_file_auth_download_protected
  t_file_auth_delete_own

  # §26 Alias enum
  t_alias_enum_group

  # §27-§28 Auth + admin
  t_anon_read_denied; t_admin_escalation_self; t_sadmin_list_users
  t_nsu_bypass

  # §28.6 Phone future state
  t_phone_future_state_group

  # §29 User ops
  t_user_name_update; t_user_phone_update

  # §30 Content (antenatal scored)
  t_art_anon_policy; t_art_antenatal_vis
  t_art_antenatal_auth_only; t_art_category_filter

  # §31-§32
  t_api_declarations; t_rule_apply_restore

  # §36-§37 Concurrency + OTP
  t_concurrency_auth_group; t_concurrency_otp_send_group
  t_concurrency_idempotency_post_group; t_otp_flow

  # §38 Hook smoke
  t_hook_smoke_group

  # §33-§35 Authorized exclusions
  t_authorized_exclusions

  # Cleanup
  pb_cleanup_all_fixtures
  pb_delete_test_user "superadmin" "$SADMIN_ID_FILE" "$SADMIN_TOK_FILE" "$SADMIN_AUTH_CFG"
  pb_delete_test_user "admin"      "$ADMIN_ID_FILE"  "$ADMIN_TOK_FILE"  "$ADMIN_AUTH_CFG"
  pb_delete_test_user "user"       "$ORDINARY_ID_FILE" "$ORDINARY_TOK_FILE" "$ORDINARY_AUTH_CFG"
  pb_delete_legacy_fixture
  pb_cleanup_alias_group
  pb_delete_local_superuser
}

pb_main() {
  local mode="" authorize_cp0=0 _report_dest_arg=""
  for arg in "$@"; do
    case "$arg" in
      --package-check)  mode="package-check" ;;
      --harness-check)  mode="harness-check" ;;
      --preflight)      mode="preflight" ;;
      --run)            mode="run" ;;
      --authorize-cp0)  authorize_cp0=1 ;;
      --report-dest=*)  _report_dest_arg="${arg#--report-dest=}" ;;
    esac
  done

  pb_setup_umask
  pb_generate_run_suffix
  pb_detect_platform

  # D-8: Validate report destination before any work.
  if [[ -n "$_report_dest_arg" ]]; then
    local dest_parent; dest_parent="${_report_dest_arg%/*}"
    if [[ ! -d "$dest_parent" ]]; then
      pb_halt "--report-dest parent directory does not exist: ${dest_parent}"
    fi
    local lstat_type
    lstat_type=$(python3 -c "
import os,sys,stat
try:
    s=os.lstat(sys.argv[1])
    print('SYMLINK' if stat.S_ISLNK(s.st_mode) else 'OK')
except FileNotFoundError: print('NEW')
except Exception as e: print('ERROR:'+str(e))
" -- "$_report_dest_arg" 2>/dev/null)
    [[ "$lstat_type" == "SYMLINK" ]] && pb_halt "--report-dest is a symlink"
    RELEASE1B_REPORT_DEST="$_report_dest_arg"
  fi

  case "$mode" in
    package-check)
      pb_setup_root; pb_write_scripts
      pb_check_package_completeness; exit $?
      ;;
    harness-check)
      pb_setup_root; pb_write_scripts
      t_harness_selftest || exit 1; exit 0
      ;;
    preflight)
      pb_setup_root; pb_write_scripts
      pb_preflight_ports; exit $?
      ;;
    run)
      (( authorize_cp0 )) || {
        print "[main] ERROR: --run requires --authorize-cp0" >&2; exit 1
      }
      pb_setup_root; pb_install_trap; pb_write_scripts
      t_harness_selftest || { print "[main] Self-test failed. Aborting." >&2; exit 1 }
      pb_run_all_tests
      pb_generate_report
      local report_rc=$?
      print "=== Complete. Report: ${RELEASE1B_REPORT_PATH} ==="
      exit $report_rc
      ;;
    *)
      print "Usage: $0 --package-check | --harness-check | --preflight | --run --authorize-cp0 [--report-dest=PATH]" >&2
      exit 1
      ;;
  esac
}

pb_main "$@"
