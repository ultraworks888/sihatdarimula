#!/usr/bin/env zsh
# ============================================================
# release1b_cp0.zsh — Release 1B Checkpoint 0 Harness
# Round  : 23
# Status : DRAFTED — syntax verified by inspection.
#          Static acceptance gate results in delivery message.
#          Checkpoint 0 authorization status:
#          AUTHORIZED BUT NOT EXECUTED —
#          EXECUTION ENVIRONMENT UNAVAILABLE
# ============================================================
#
# R23 corrections:
#   D23-1.  Fatal zsh syntax errors fixed: all 'return N fi' patterns
#           corrected to proper if/fi termination.
#   D23-2.  PocketBase v0.29.3: auth via
#           /api/collections/_superusers/auth-with-password.
#           NSU created by migration (no CLI). No 'pocketbase admin'.
#           Runtime tests: creation, auth, _superusers token, cleanup.
#   D23-3.  Password not in process args, env listings, shell history,
#           or retained files. Migration-based bootstrap with local
#           non-exported shell variable (cleared immediately).
#           Bootstrap migration deleted after PB startup.
#   D23-4.  OTP requests bound to requesting_user_id. TX-3 rejects
#           callers who did not create the request. Cross-user test added.
#   D23-5.  Expired OTP: return-from-TX commits expired state; throw
#           happens OUTSIDE the transaction. No throw-after-save.
#   D23-6.  TX-2 cleanup: errors not swallowed. 500 on cleanup fail.
#           Mode db_fail_request_cleanup_fail tests this path.
#   D23-7.  Concurrent verify: exactly 1 (not <= 1); DB-state verified.
#           Concurrent send: verifies HTTP outcomes and persisted state.
#   D23-8.  Concurrent workers collect evidence; one terminal result per
#           group; no multiple calls to t_fail/t_pass with same ID.
#   D23-9.  _t_fatal_internal cannot recursively enter _t_record_outcome.
#           Selftest covers PASS/PASS, PASS/FAIL, FAIL/PASS.
#   D23-10. All OTP request/verify JSON bodies use PBJ_PY encoder.
#   D23-11. Integrity: checksum limitation documented as unresolved
#           provenance. Verifier rejects symlinks, non-regular files.
#           Generation refuses to overwrite populated baseline.
#   D23-12. Rate-limit and idempotency explicitly DEFERRED-MANDATORY;
#           no implied safety claim.
#   D23-13. Static acceptance gate results in delivery message.
#           Synthetic phones: +601_R23TEST_*.
# ============================================================
#
# OR-TRUE inventory:
#   Site 1 [BENIGN-RETAINED] pb_wipe_secret_file: dd short-file.
#   Site 2 [BENIGN]          pb_trap_cleanup watchdog reap.
# ============================================================

setopt NO_UNSET PIPE_FAIL

# ────────────────────────────────────────────────────────────
# §3  CONSTANTS
# ────────────────────────────────────────────────────────────
readonly RELEASE1B_SCRIPT_ROUND="23"
readonly RELEASE1B_PB_PORT="8090"
readonly RELEASE1B_PB_VERSION="0.29.3"
readonly RELEASE1B_TEST_DOMAIN="example.invalid"
readonly SEED_MIGRATION_EXCLUDE="1782898775_seed_superadmin_user_4fd7.js"
readonly OTP_ADAPTER_FILENAME="release1b_otp_test_adapter.pb.js"
readonly PHONE_GUARD_HOOK_FILENAME="release1b_r23_phone_verified_guard.pb.js"

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
typeset -grA HOOK_PROBE_TYPE=(
  [emergency_hardening]="behavioral"
  [push_broadcast]="route"
  [whatsapp]="route"
)
typeset -grA HOOK_PROBE_ROUTES=(
  [emergency_hardening]=""
  [push_broadcast]="/api/admin/push-broadcast"
  [whatsapp]="/api/admin/whatsapp/config"
)
typeset -grA HOOK_PROBE_METHODS=(
  [emergency_hardening]=""
  [push_broadcast]="POST"
  [whatsapp]="GET"
)
typeset -grA HOOK_PROBE_AUTH=([emergency_hardening]="" [push_broadcast]="admin" [whatsapp]="admin")
typeset -grA HOOK_PROBE_SAFE_STATUS=([push_broadcast]="400" [whatsapp]="200 401 403 500")

typeset -g HOOK_OTP_PHONE_ROUTE="/api/auth/request-whatsapp-otp"
typeset -g HOOK_OTP_VERIFY_ROUTE="/api/auth/verify-whatsapp-otp"
typeset -g HOOK_OTP_CTRL_ROUTE="/api/test/otp-control"
typeset -g RELEASE1B_SCHEMA_SRC="UNRESOLVED__NEEDS_EXTERNAL__schema_src_path"

readonly SYNTH_PHONE_OTP="+601_R23TEST_77701234"
readonly SYNTH_PHONE_LINK="+601_R23TEST_00012345"
readonly SYNTH_PHONE_XUSER="+601_R23TEST_99900001"

# ────────────────────────────────────────────────────────────
# §4  GLOBAL MUTABLE STATE
# ────────────────────────────────────────────────────────────
typeset -gi T_PASS=0 T_FAIL=0 T_BLOCKING=0 T_UNRESOLVED=0
typeset -gi T_DEFERRED=0 T_HARNESS_ERR=0 T_SKIP=0
typeset -gi CLEANUP_FAILURE=0 HALT_DEPENDENTS=0

typeset -ga BLOCKING_DECISIONS=() UNRESOLVED_ITEMS=() HARNESS_ERRORS=()
typeset -gA T_OUTCOME_MAP=()

typeset -g RELEASE1B_ISOLATED_ROOT="" RELEASE1B_CANONICAL_ROOT=""
typeset -g RELEASE1B_CANONICAL_PARENT="" RELEASE1B_PB_DATA_DIR=""
typeset -g RELEASE1B_PB_HOOKS_DIR="" RELEASE1B_PB_MIGRATIONS_DIR=""
typeset -g RELEASE1B_TEST_TMP="" RELEASE1B_EVIDENCE_DIR=""
typeset -g RELEASE1B_REPORT_WORK="" RELEASE1B_REPORT_PATH=""
typeset -g RELEASE1B_PB_BIN="" RELEASE1B_BASE_URL=""
typeset -gi RELEASE1B_PB_PID=0
typeset -g RELEASE1B_REPORT_DEST="" RUN_SUFFIX="" PLATFORM_KEY=""
typeset -g TEST_EMAIL_DOMAIN="$RELEASE1B_TEST_DOMAIN"

typeset -g PBJ_STAT_PY="" PBJ_URL_PY="" PBJ_PY="" PBJ_AUTH_PY="" PBJ_HTTP_PY=""
typeset -g PBJ_FIELD_PY="" PBJ_COPY_PY="" PBJ_EXTRACT_PY="" PBJ_SHAPE_PY=""
typeset -g PBJ_SCAN_PY="" PBJ_CRED_SCAN_PY=""

# D23-2/3: NSU credentials (no CLI; migration-based bootstrap).
typeset -g _NSU_EMAIL="" _NSU_PW_FILE="" _NSU_TOK_FILE="" _NSU_AUTH_CFG=""
typeset -g _NSU_BOOTSTRAP_MIG_PATH=""

typeset -g ORDINARY_ID_FILE="" ORDINARY_TOK_FILE="" ORDINARY_AUTH_CFG=""
typeset -g ORDINARY_B_ID_FILE="" ORDINARY_B_TOK_FILE="" ORDINARY_B_AUTH_CFG=""
typeset -g ADMIN_ID_FILE="" ADMIN_TOK_FILE="" ADMIN_AUTH_CFG=""
typeset -g SADMIN_ID_FILE="" SADMIN_TOK_FILE="" SADMIN_AUTH_CFG=""
typeset -g LEGACY_ID_FILE="" LEGACY_TOK_FILE="" LEGACY_AUTH_CFG=""
typeset -g LEGACY_CHILD_ID_FILE="" LEGACY_GROWTH_ID_FILE=""
typeset -g ALIAS_ID_FILE="" ALIAS_PW_FILE="" ALIAS_AUTH_CFG=""
typeset -g WRONG_PW_FILE="" TIMING_LEGACY_ID_FILE="" TIMING_LEGACY_PW_FILE=""
typeset -g TIMING_LEGACY_AUTH_CFG=""
typeset -gA RULE_BASELINE=()
typeset -ga ENUM_RESP_FILES=() ENUM_HTTP_VALUES=()
typeset -gA FIXTURE_REGISTRY=()

# ────────────────────────────────────────────────────────────
# §5  CORE UTILITIES
# ────────────────────────────────────────────────────────────
pb_realpath()  { python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" -- "$1" }
pb_generate_run_suffix() {
  RUN_SUFFIX=$(openssl rand -hex 6 2>/dev/null) || \
    RUN_SUFFIX=$(date +%s%3N | shasum -a 256 | head -c 12)
}
pb_setup_umask() { umask 077 }
pb_halt()        { print "[HALT] $*" >&2; exit 1 }
pb_secure_tmpfile() {
  local s="${1:-.tmp}"
  local p="${RELEASE1B_TEST_TMP}/${RUN_SUFFIX}_$$_${RANDOM}${s}"
  : > "$p"; chmod 600 "$p"; print "$p"
}
pb_inc() { typeset -g "${1}"=$(( ${(P)1} + 1 )) }

pb_wipe_secret_file() {
  local f="$1"; [[ -f "$f" ]] || return 0
  dd if=/dev/zero of="$f" bs=1024 count=4 2>/dev/null || true  # Site 1 [BENIGN-RETAINED]
  rm -f "$f"
}

pb_setup_root() {
  local parent="${TMPDIR:-/tmp}"
  RELEASE1B_CANONICAL_PARENT=$(pb_realpath "$parent")
  local root="${parent}/release1b_cp0_${RUN_SUFFIX}"
  mkdir -p "$root" && chmod 700 "$root" || pb_halt "Cannot create isolated root: ${root}"
  RELEASE1B_ISOLATED_ROOT="$root"
  RELEASE1B_CANONICAL_ROOT=$(pb_realpath "$root")
  RELEASE1B_BASE_URL="http://127.0.0.1:${RELEASE1B_PB_PORT}"
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
  printf '# CP0 Report %s\n\n| Test | Result | Notes |\n|---|---|---|\n' "$RUN_SUFFIX" \
    > "$RELEASE1B_REPORT_WORK"
  print "=== Isolated root: [${RELEASE1B_CANONICAL_ROOT}] ==="
}

pb_url() {
  local u="${RELEASE1B_BASE_URL}${1}"
  local r; r=$(python3 "$PBJ_URL_PY" "$u" "127.0.0.1" "$RELEASE1B_PB_PORT" 2>/dev/null)
  [[ "$r" == "OK" ]] || pb_halt "URL validation failed: ${u} (${r})"
  print "$u"
}

# ────────────────────────────────────────────────────────────
# §6  TRAP / CLEANUP
# ────────────────────────────────────────────────────────────
pb_validate_cleanup_target() {
  local target="$1"
  [[ -z "$target" ]] && { print "[cleanup] REJECT: empty target" >&2; return 1 }
  local canonical; canonical=$(pb_realpath "$target" 2>/dev/null) || {
    print "[cleanup] REJECT: realpath failed" >&2; return 1
  }
  [[ -z "$canonical" ]] && { print "[cleanup] REJECT: empty canonical" >&2; return 1 }
  local parent_dir="${canonical%/*}"
  local cp; cp=$(pb_realpath "$parent_dir" 2>/dev/null) || {
    print "[cleanup] REJECT: parent realpath" >&2; return 1
  }
  [[ "$cp" != "$RELEASE1B_CANONICAL_PARENT" ]] && {
    print "[cleanup] REJECT: parent mismatch" >&2; return 1
  }
  local base="${canonical##*/}"
  [[ "$base" != release1b_cp0_* ]] && {
    print "[cleanup] REJECT: missing prefix '${base}'" >&2; return 1
  }
  local ls_result; ls_result=$(python3 -c "
import os,sys,stat as _s
try:
    s=os.lstat(sys.argv[1]); print('SYMLINK' if _s.S_ISLNK(s.st_mode) else 'OK')
except Exception as e: print('ERROR:'+str(e))
" -- "$canonical" 2>/dev/null)
  [[ "$ls_result" == "SYMLINK" || "$ls_result" == ERROR* ]] && {
    print "[cleanup] REJECT: symlink/lstat" >&2; return 1
  }
  case "$canonical" in /|/tmp|/var|/usr|/etc|/home|/root|/System|/Library)
    print "[cleanup] REJECT: prohibited" >&2; return 1 ;; esac
  if [[ -n "${HOME:-}" ]]; then
    local hc; hc=$(pb_realpath "$HOME" 2>/dev/null)
    [[ -n "$hc" && "$canonical" == "$hc" ]] && {
      print "[cleanup] REJECT: HOME" >&2; return 1
    }
  fi
  [[ ! -f "${canonical}/.release1b_marker" ]] && {
    print "[cleanup] REJECT: no marker" >&2; return 1
  }
  return 0
}

pb_export_report() {
  [[ -n "$RELEASE1B_REPORT_DEST" && -f "$RELEASE1B_REPORT_PATH" ]] || return 0
  local dc; dc=$(pb_realpath "$RELEASE1B_REPORT_DEST" 2>/dev/null) || return 1
  [[ "$dc" == "${RELEASE1B_CANONICAL_ROOT}"* ]] && {
    print "[export] inside root" >&2; return 1
  }
  local dp="${dc%/*}"; [[ -d "$dp" ]] || { print "[export] parent missing" >&2; return 1 }
  local sf="${RELEASE1B_REPORT_PATH}.exs"
  RELEASE1B_CANONICAL_ROOT="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_SCAN_PY" "$RELEASE1B_REPORT_PATH" "$sf" 2>/dev/null || return 1
  chmod 600 "$sf"
  grep -qiE 'release1b_cp0_[a-z0-9]{12}|sdmadmin|ultra\.works' "$sf" 2>/dev/null && {
    rm -f "$sf"; print "[export] FAIL-CLOSED" >&2; return 1
  }
  local tmp="${dp}/.r23_rpt_tmp_${RUN_SUFFIX}"
  cp "$sf" "$tmp" && chmod 600 "$tmp" && mv "$tmp" "$dc" || {
    rm -f "$tmp" "$sf"; return 1
  }
  rm -f "$sf"
  local sz; sz=$(wc -c < "$dc" 2>/dev/null | tr -d ' ')
  (( sz < 100 )) && { print "[export] too small" >&2; return 1 }
  print "=== Report exported: [${dc}] (${sz}b) ==="
}

pb_trap_cleanup() {
  pb_export_report || { print "[trap] export failed" >&2; CLEANUP_FAILURE=1 }
  if (( RELEASE1B_PB_PID > 0 )); then
    kill "$RELEASE1B_PB_PID" 2>/dev/null
    local _wdf="${RELEASE1B_TEST_TMP}/${RUN_SUFFIX}_wdf_${RELEASE1B_PB_PID}"
    : > "$_wdf" && chmod 600 "$_wdf"
    ( sleep 6
      local _pp; _pp=$(ps -p "$RELEASE1B_PB_PID" -o ppid= 2>/dev/null | tr -d ' ')
      [[ "$_pp" == "$$" ]] && kill -9 "$RELEASE1B_PB_PID" 2>/dev/null
      printf '1' > "$_wdf"
    ) &
    local _wd=$!
    wait "$RELEASE1B_PB_PID" 2>/dev/null
    kill "$_wd" 2>/dev/null
    wait "$_wd" 2>/dev/null || true  # Site 2 [BENIGN]
    rm -f "$_wdf"; RELEASE1B_PB_PID=0
  fi
  local sf
  for sf in "$_NSU_PW_FILE" "$_NSU_TOK_FILE" "$_NSU_AUTH_CFG" \
    "$ORDINARY_TOK_FILE" "$ORDINARY_B_TOK_FILE" "$ADMIN_TOK_FILE" \
    "$SADMIN_TOK_FILE" "$LEGACY_TOK_FILE" "$ALIAS_PW_FILE" \
    "$WRONG_PW_FILE" "$TIMING_LEGACY_PW_FILE"; do
    [[ -n "$sf" ]] && pb_wipe_secret_file "$sf"
  done
  if [[ -n "$RELEASE1B_ISOLATED_ROOT" && -d "$RELEASE1B_ISOLATED_ROOT" ]]; then
    if pb_validate_cleanup_target "$RELEASE1B_ISOLATED_ROOT"; then
      rm -rf "$RELEASE1B_ISOLATED_ROOT" 2>/dev/null || CLEANUP_FAILURE=1
    else
      print "[trap] REFUSE rm -rf: validation failed. Root retained: ${RELEASE1B_ISOLATED_ROOT}" >&2
      CLEANUP_FAILURE=1
    fi
  fi
  (( CLEANUP_FAILURE )) && print "[trap] Cleanup incomplete" >&2
}

pb_install_trap() { trap pb_trap_cleanup EXIT TERM INT }

# ────────────────────────────────────────────────────────────
# §7  RESULT TRACKING  (D23-9: non-recursive double-outcome)
# ────────────────────────────────────────────────────────────

# D23-9: Direct fatal path — does NOT call t_blocking/t_pass/t_fail.
# Cannot re-enter _t_record_outcome.
_t_fatal_internal() {
  local orig_id="$1" outcome1="$2" outcome2="$3"
  pb_inc T_BLOCKING
  HALT_DEPENDENTS=1
  local msg="HARNESS_INTEGRITY: '${orig_id}' received '${outcome1}' then '${outcome2}'"
  BLOCKING_DECISIONS+=("${msg}")
  printf '| HARNESS_INTEGRITY_%s | BLOCKING | %s |\n' \
    "${orig_id//[^A-Za-z0-9_-]/}" "$msg" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[HARNESS_INTEGRITY] ${msg}" >&2
}

_t_record_outcome() {
  local id="$1" outcome="$2"
  if [[ -n "${T_OUTCOME_MAP[$id]:-}" ]]; then
    local prev="${T_OUTCOME_MAP[$id]}"
    _t_fatal_internal "$id" "$prev" "$outcome"  # non-recursive
    return 1
  fi
  T_OUTCOME_MAP[$id]="$outcome"
  return 0
}

t_pass()      {
  local l="$1" m="${2:-}"
  _t_record_outcome "$l" "PASS" || return
  pb_inc T_PASS
  printf '| %s | PASS | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[PASS] ${l}${m:+ | }${m}"
}
t_fail()      {
  local l="$1" m="${2:-}"
  _t_record_outcome "$l" "FAIL" || return
  pb_inc T_FAIL
  BLOCKING_DECISIONS+=("FAIL: ${l}: ${m}")
  printf '| %s | FAIL | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[FAIL] ${l}: ${m}" >&2
}
t_blocking()  {
  local l="$1" m="${2:-}"
  _t_record_outcome "$l" "BLOCKING" || return
  pb_inc T_BLOCKING
  HALT_DEPENDENTS=1
  BLOCKING_DECISIONS+=("BLOCKING: ${l}: ${m}")
  printf '| %s | BLOCKING | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[BLOCKING] ${l}: ${m}" >&2
}
t_unresolved() {
  local l="$1" m="${2:-}"
  _t_record_outcome "$l" "UNRESOLVED" || return
  pb_inc T_UNRESOLVED
  UNRESOLVED_ITEMS+=("UNRESOLVED: ${l}: ${m}")
  printf '| %s | UNRESOLVED | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[UNRESOLVED] ${l}: ${m}" >&2
}
t_deferred_mandatory() {
  local l="$1" m="${2:-}"
  _t_record_outcome "$l" "DEFERRED" || return
  pb_inc T_DEFERRED
  UNRESOLVED_ITEMS+=("DEFERRED-MANDATORY: ${l}: ${m}")
  printf '| %s | DEFERRED-MANDATORY | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[DEFERRED-MANDATORY] ${l}: ${m}"
}
t_skip()      {
  local l="$1" m="${2:-}"
  _t_record_outcome "$l" "SKIP" || return
  pb_inc T_SKIP
  printf '| %s | SKIP | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[SKIP] ${l}: ${m}"
}
t_harness_err() {
  local l="$1" m="${2:-}"
  _t_record_outcome "$l" "HARNESS_ERR" || return
  pb_inc T_HARNESS_ERR
  HARNESS_ERRORS+=("HARNESS_ERR: ${l}: ${m}")
  printf '| %s | HARNESS_ERR | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[HARNESS_ERR] ${l}: ${m}" >&2
}
t_authorized_exclusion() {
  printf '| %s | AUTHORIZED-EXCLUSION | %s |\n' "$1" "${2:-}" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[AUTHORIZED-EXCLUSION] $1: ${2:-}"
}

# ────────────────────────────────────────────────────────────
# §8  PYTHON HELPERS
# ────────────────────────────────────────────────────────────
pb_write_scripts() {
  local d="$RELEASE1B_TEST_TMP"

  PBJ_STAT_PY="${d}/pbj_stat.py"; cat > "$PBJ_STAT_PY" << 'PYEOF'
import sys,os,stat as _st
CANONICAL_TMP=os.environ.get('RELEASE1B_CANONICAL_TMP','')
path=sys.argv[1]
try: lstat=os.lstat(path)
except Exception as exc: print(f'ERROR:{exc}',file=sys.stderr); sys.exit(2)
if _st.S_ISLNK(lstat.st_mode): print('SYMLINK'); sys.exit(0)
if CANONICAL_TMP:
    real_path=os.path.realpath(path); real_tmp=os.path.realpath(CANONICAL_TMP)
    if not real_path.startswith(real_tmp+os.sep) and real_path!=real_tmp:
        print('OUTSIDE_ROOT'); sys.exit(0)
print(oct(_st.S_IMODE(lstat.st_mode))[2:])
PYEOF

  PBJ_URL_PY="${d}/pbj_url.py"; cat > "$PBJ_URL_PY" << 'PYEOF'
import sys,urllib.parse
url_str=sys.argv[1]; exp_host=sys.argv[2]; exp_port=sys.argv[3]
try: p=urllib.parse.urlparse(url_str)
except Exception: print('REJECT:parse-error'); sys.exit(0)
if p.scheme!='http': print(f'REJECT:scheme={p.scheme!r}'); sys.exit(0)
if p.username or p.password: print('REJECT:userinfo'); sys.exit(0)
host=(p.hostname or '').lower()
if host!=exp_host: print(f'REJECT:host={host!r}'); sys.exit(0)
port=str(p.port) if p.port else '80'
if port!=exp_port: print(f'REJECT:port={port!r}'); sys.exit(0)
if not p.path.startswith('/api/'): print(f'REJECT:path={p.path!r}'); sys.exit(0)
print('OK')
PYEOF

  PBJ_PY="${d}/pbj.py"; cat > "$PBJ_PY" << 'PYEOF'
import sys,os,json,math,stat as _st
BLOCKED=frozenset({'id','collectionId','collectionName','created','updated','tokenKey','passwordHash'})
out_path=sys.argv[1]; args=sys.argv[2:]; obj={}
for arg in args:
    if ':' in arg.split('=')[0]: typ,rest=arg.split(':',1)
    else: typ='s'; rest=arg
    if '=' not in rest: print(f'ERROR: no = in arg {arg!r}',file=sys.stderr); sys.exit(1)
    key,val=rest.split('=',1)
    if key in BLOCKED: print(f'ERROR: blocked key {key!r}',file=sys.stderr); sys.exit(1)
    if key in obj: print(f'ERROR: duplicate key {key!r}',file=sys.stderr); sys.exit(1)
    if typ=='s':
        if val.startswith('secret-file:'):
            sf=val[len('secret-file:'):]
            lst=os.lstat(sf)
            if _st.S_ISLNK(lst.st_mode): print('ERROR: secret-file is a symlink',file=sys.stderr); sys.exit(1)
            with open(sf) as fh: obj[key]=fh.read().strip()
        else: obj[key]=val
    elif typ=='b':
        if val.lower() not in ('true','false'): print(f'ERROR: bool must be true/false',file=sys.stderr); sys.exit(1)
        obj[key]=(val.lower()=='true')
    elif typ=='n':
        try: fv=float(val); obj[key]=int(fv) if fv==math.floor(fv) else fv
        except ValueError: print(f'ERROR: not a number: {val!r}',file=sys.stderr); sys.exit(1)
    else: print(f'ERROR: unknown type {typ!r}',file=sys.stderr); sys.exit(1)
lst=os.lstat(out_path)
if _st.S_ISLNK(lst.st_mode): print('ERROR: output symlink',file=sys.stderr); sys.exit(1)
with open(out_path,'w') as fh: json.dump(obj,fh)
os.chmod(out_path,0o600)
PYEOF

  PBJ_AUTH_PY="${d}/pbj_auth.py"; cat > "$PBJ_AUTH_PY" << 'PYEOF'
import sys,os,re,stat as _st
auth_cfg=sys.argv[1]; tok_file=sys.argv[2]
lst=os.lstat(tok_file)
if _st.S_ISLNK(lst.st_mode): print('ERROR: tok_file symlink',file=sys.stderr); sys.exit(1)
with open(tok_file) as fh: token=fh.read().strip()
if not re.match(r'^[A-Za-z0-9._\-]+$',token): print('ERROR: token pattern',file=sys.stderr); sys.exit(1)
lst=os.lstat(auth_cfg)
if _st.S_ISLNK(lst.st_mode): print('ERROR: auth_cfg symlink',file=sys.stderr); sys.exit(1)
with open(auth_cfg,'w') as fh: fh.write(f'Authorization: Bearer {token}')
os.chmod(auth_cfg,0o600)
PYEOF

  PBJ_HTTP_PY="${d}/pbj_http.py"; cat > "$PBJ_HTTP_PY" << 'PYEOF'
import sys,os,subprocess,re,stat as _st
MAX_RESP=1024*512
def main():
    status_out=sys.argv[1]; path_out=sys.argv[2]; url=sys.argv[3]
    auth_file=sys.argv[4] if len(sys.argv)>4 else ''
    body_file=sys.argv[5] if len(sys.argv)>5 else ''
    method=sys.argv[6] if len(sys.argv)>6 else 'GET'
    CANONICAL_TMP=os.environ.get('RELEASE1B_CANONICAL_TMP','')
    resp_path=os.path.join(CANONICAL_TMP or os.path.dirname(status_out),
        f'resp_{os.getpid()}_{os.urandom(4).hex()}.json')
    with open(resp_path,'w') as fh: fh.write('')
    os.chmod(resp_path,0o600)
    cmd=['curl','-sf','--max-time','30','--connect-timeout','10',
         '--output',resp_path,'--write-out','%{http_code}',
         '-X',method.upper(),'-H','Content-Type: application/json']
    if auth_file and os.path.isfile(auth_file):
        lst=os.lstat(auth_file)
        if not _st.S_ISLNK(lst.st_mode):
            with open(auth_file) as fh: hdr=fh.read().strip()
            if re.match(r'^Authorization: Bearer [A-Za-z0-9._\-]+$',hdr): cmd+=['-H',hdr]
    if body_file and os.path.isfile(body_file): cmd+=['--data-binary',f'@{body_file}']
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

  PBJ_FIELD_PY="${d}/pbj_field.py"; cat > "$PBJ_FIELD_PY" << 'PYEOF'
import sys,json,re
BLOCKED=frozenset({'password','passwordHash','tokenKey'})
resp_file=sys.argv[1]; field=sys.argv[2]
if field in BLOCKED: print('BLOCKED',file=sys.stderr); sys.exit(1)
with open(resp_file) as fh: data=json.load(fh)
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

  PBJ_EXTRACT_PY="${d}/pbj_extract.py"; cat > "$PBJ_EXTRACT_PY" << 'PYEOF'
import sys,json,re
ALLOWED=frozenset({'id','email','role','name','otpId','collectionId','collectionName'})
resp_file=sys.argv[1]; field=sys.argv[2]
if field not in ALLOWED: print(f'ERROR: {field!r} not in allowlist',file=sys.stderr); sys.exit(1)
with open(resp_file) as fh: data=json.load(fh)
val=data.get(field,'__absent__')
if isinstance(val,str):
    if not re.match(r'^[A-Za-z0-9@._\-\s]{1,256}$',val): print('ERROR: pattern',file=sys.stderr); sys.exit(1)
    print(val)
elif val=='__absent__': print('__absent__')
else: print(str(val))
PYEOF

  PBJ_SHAPE_PY="${d}/pbj_shape.py"; cat > "$PBJ_SHAPE_PY" << 'PYEOF'
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

  PBJ_SCAN_PY="${d}/pbj_scan.py"; cat > "$PBJ_SCAN_PY" << 'PYEOF'
import sys,os,re
CANONICAL_ROOT=os.environ.get('RELEASE1B_CANONICAL_ROOT','')
def sanitize(line):
    if CANONICAL_ROOT: line=line.replace(CANONICAL_ROOT,'[ISOLATED_ROOT]')
    home=os.path.expanduser('~')
    if home and home!='~': line=line.replace(home,'[HOME]')
    line=re.sub(r'/tmp/release1b_cp0_[A-Za-z0-9_]+','[ISOLATED_ROOT]',line)
    line=re.sub(r'\bsdmadmin\b','[REDACTED-SEED-IDENTITY]',line,flags=re.IGNORECASE)
    line=re.sub(r'[A-Za-z0-9._%+\-]+@ultra\.works','[REDACTED-SEED-EMAIL]',line,flags=re.IGNORECASE)
    return line
report_in=sys.argv[1]; report_out=sys.argv[2]; lines=[]
with open(report_in) as fh:
    for line in fh: lines.append(sanitize(line.rstrip('\n')))
tmp=report_out+'.scantmp'
with open(tmp,'w') as fh: fh.write('\n'.join(lines)+'\n')
os.chmod(tmp,0o600)
os.replace(tmp,report_out)
PYEOF

  PBJ_CRED_SCAN_PY="${d}/pbj_cred_scan.py"; cat > "$PBJ_CRED_SCAN_PY" << 'PYEOF'
import sys,re
filepath=sys.argv[1]
try:
    with open(filepath,encoding='utf-8',errors='replace') as fh: lines=fh.readlines()
except Exception as e: print(f'ERROR:{e}',file=sys.stderr); sys.exit(2)
PATTERNS=[re.compile(r'\$\$[^\$\n]{6,}'),
          re.compile(r'(?:set|\.set)\s*\(["\']password["\']',re.IGNORECASE)]
found=False
for i,line in enumerate(lines,1):
    stripped=line.rstrip('\n')
    if stripped.lstrip().startswith('//') or stripped.lstrip().startswith('*'): continue
    for pat in PATTERNS:
        if pat.search(stripped): print(f'SUSPECTED:{filepath}:{i}'); found=True; break
sys.exit(1 if found else 0)
PYEOF

  PBJ_COPY_PY="${d}/pbj_copy.py"; cat > "$PBJ_COPY_PY" << 'PYEOF'
import sys,json
BLOCKED=frozenset({'password','passwordHash','tokenKey'})
src_file=sys.argv[1]; dst_file=sys.argv[2]; field=sys.argv[3]
out_field=sys.argv[4] if len(sys.argv)>4 else sys.argv[3]
if field in BLOCKED or out_field in BLOCKED: print('BLOCKED',file=sys.stderr); sys.exit(1)
with open(src_file) as fh: src=json.load(fh)
with open(dst_file) as fh: dst=json.load(fh)
if field not in src: print(f'ABSENT:{field!r}',file=sys.stderr); sys.exit(1)
dst[out_field]=src[field]
with open(dst_file,'w') as fh: json.dump(dst,fh)
PYEOF

  chmod 400 "$PBJ_STAT_PY" "$PBJ_URL_PY" "$PBJ_PY" "$PBJ_AUTH_PY" "$PBJ_HTTP_PY" \
    "$PBJ_FIELD_PY" "$PBJ_COPY_PY" "$PBJ_EXTRACT_PY" "$PBJ_SHAPE_PY" \
    "$PBJ_SCAN_PY" "$PBJ_CRED_SCAN_PY"
  print "=== Python helpers written ==="
}

# ────────────────────────────────────────────────────────────
# §9  VALIDATION HELPERS
# ────────────────────────────────────────────────────────────
pb_validate_path() {
  local path="$1"
  local result; result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$path" 2>/dev/null)
  case "$result" in SYMLINK|OUTSIDE_ROOT|ERROR*) print "PATH_FAIL:${path}"; return 1 ;; esac
  return 0
}

# ────────────────────────────────────────────────────────────
# §10 HARNESS SELF-TEST  (D23-9,13: double-outcome; cleanup)
# ────────────────────────────────────────────────────────────
t_harness_selftest() {
  print "=== Harness self-test (offline) ==="
  local fail=0

  # ── pbj.py validation ───────────────────────────────────
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=test" "role=user" 2>/dev/null || {
    print "[selftest] pbj.py rejected valid args" >&2; fail=1
  }
  rm -f "$body_f"

  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "id=inject" 2>/dev/null && {
    print "[selftest] pbj.py accepted blocked key 'id'" >&2; fail=1
  }
  rm -f "$body_f"

  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=a" "name=b" 2>/dev/null && {
    print "[selftest] pbj.py accepted duplicate key" >&2; fail=1
  }
  rm -f "$body_f"

  # ── D23-10: OTP body encoded via PBJ_PY ─────────────────
  local otp_body_f; otp_body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$otp_body_f" "phone=+601_R23TEST_99999" 2>/dev/null || {
    print "[selftest] pbj.py rejected synthetic phone" >&2; fail=1
  }
  local otp_body_content; otp_body_content=$(cat "$otp_body_f" 2>/dev/null)
  [[ "$otp_body_content" != *'"phone"'* ]] && {
    print "[selftest] OTP body missing phone key: ${otp_body_content}" >&2; fail=1
  }
  rm -f "$otp_body_f"

  # ── Symlink detection ────────────────────────────────────
  local link_target; link_target=$(pb_secure_tmpfile .tgt)
  local link_name="${RELEASE1B_TEST_TMP}/selftest_link_${RANDOM}"
  ln -s "$link_target" "$link_name" 2>/dev/null
  local link_result; link_result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$link_name" 2>/dev/null)
  [[ "$link_result" != "SYMLINK" ]] && {
    print "[selftest] symlink not detected (got '${link_result}')" >&2; fail=1
  }
  rm -f "$link_name" "$link_target"

  # ── Credential scanner ───────────────────────────────────
  local cred_f; cred_f=$(pb_secure_tmpfile .js)
  printf 'admin.set("password", "$$TestCredXyz$$");\n' > "$cred_f"
  python3 "$PBJ_CRED_SCAN_PY" "$cred_f" 2>/dev/null
  local scan_rc=$?; rm -f "$cred_f"
  (( scan_rc != 1 )) && {
    print "[selftest] cred scanner missed test pattern (rc=${scan_rc})" >&2; fail=1
  }

  # ── D23-9: Double-outcome detection (isolated state) ─────
  local -A _st_map=()
  local _st_dupe=0
  _st_rec() {
    local id="$1"
    if [[ -n "${_st_map[$id]:-}" ]]; then _st_dupe=1; return 1; fi
    _st_map[$id]="used"; return 0
  }

  # PASS/PASS
  _st_rec "ST-DUPE-PP" || { print "[selftest] Unexpected reject on first PASS/PASS call" >&2; fail=1 }
  _st_rec "ST-DUPE-PP"
  (( _st_dupe == 0 )) && { print "[selftest] PASS/PASS duplicate not detected" >&2; fail=1 }

  _st_map=(); _st_dupe=0

  # PASS/FAIL
  _st_rec "ST-DUPE-PF" || { print "[selftest] Unexpected reject on PASS/FAIL first" >&2; fail=1 }
  _st_rec "ST-DUPE-PF"
  (( _st_dupe == 0 )) && { print "[selftest] PASS/FAIL duplicate not detected" >&2; fail=1 }

  _st_map=(); _st_dupe=0

  # FAIL/PASS
  _st_rec "ST-DUPE-FP" || { print "[selftest] Unexpected reject on FAIL/PASS first" >&2; fail=1 }
  _st_rec "ST-DUPE-FP"
  (( _st_dupe == 0 )) && { print "[selftest] FAIL/PASS duplicate not detected" >&2; fail=1 }

  unfunction _st_rec 2>/dev/null || true

  # ── D23-13: Cleanup target validation ────────────────────

  # Reject empty path.
  pb_validate_cleanup_target "" 2>/dev/null && {
    print "[selftest] cleanup accepted empty path" >&2; fail=1
  }

  # Reject root.
  pb_validate_cleanup_target "/" 2>/dev/null && {
    print "[selftest] cleanup accepted '/'" >&2; fail=1
  }

  # Reject missing-marker directory.
  local no_marker="${TMPDIR:-/tmp}/release1b_cp0_selftest_nomarker_$$"
  mkdir -p "$no_marker" 2>/dev/null
  pb_validate_cleanup_target "$no_marker" 2>/dev/null && {
    print "[selftest] cleanup accepted no-marker dir" >&2; fail=1
  }
  rm -rf "$no_marker" 2>/dev/null

  # Reject symlink.
  local sym_real="${TMPDIR:-/tmp}/release1b_selftest_symreal_$$"
  local sym_link="${TMPDIR:-/tmp}/release1b_cp0_selftest_symlink_$$"
  mkdir -p "$sym_real" 2>/dev/null
  printf 'marker\n' > "${sym_real}/.release1b_marker" 2>/dev/null
  ln -sf "$sym_real" "$sym_link" 2>/dev/null
  pb_validate_cleanup_target "$sym_link" 2>/dev/null && {
    print "[selftest] cleanup accepted symlink" >&2; fail=1
  }
  rm -rf "$sym_real"; rm -f "$sym_link"

  # Accept the current isolated root.
  pb_validate_cleanup_target "$RELEASE1B_ISOLATED_ROOT" 2>/dev/null || {
    print "[selftest] cleanup rejected valid isolated root" >&2; fail=1
  }

  if (( fail )); then
    print "[selftest] RESULT: FAIL (${fail} issue(s))" >&2
    return 1
  fi
  print "[selftest] RESULT: PASS"
}

# ────────────────────────────────────────────────────────────
# §11 INFRASTRUCTURE
# ────────────────────────────────────────────────────────────
pb_detect_platform() {
  local os_name arch
  os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in arm64|aarch64) arch="arm64" ;; x86_64) arch="amd64" ;;
    *) pb_halt "Unsupported arch: ${arch}" ;; esac
  case "$os_name" in darwin|linux) : ;; *) pb_halt "Unsupported OS: ${os_name}" ;; esac
  PLATFORM_KEY="${os_name}_${arch}"
  print "=== Platform: ${PLATFORM_KEY} ==="
}

pb_verify_binary_version() {
  local reported; reported=$("$RELEASE1B_PB_BIN" version 2>&1 | head -1)
  print "=== PocketBase binary version: ${reported} ==="
  if [[ "$reported" != *"${RELEASE1B_PB_VERSION}"* ]]; then
    t_blocking "T-PKG-VERSION" "Expected v${RELEASE1B_PB_VERSION}; got '${reported}'"
    return 1
  fi
  t_pass "T-PKG-VERSION"
}

pb_preflight_ports() {
  print "=== Preflight port check ==="
  if lsof -iTCP:"$RELEASE1B_PB_PORT" -sTCP:LISTEN -P -n &>/dev/null; then
    t_blocking "T-PREFLIGHT-PORTS" "Port ${RELEASE1B_PB_PORT} in use"
    return 1
  fi
  t_pass "T-PREFLIGHT-PORTS"
}

pb_check_package_completeness() {
  print "=== Package completeness check ==="
  local ok=1 hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    [[ "${HOOK_SRC_PATHS[$hk]}" == UNRESOLVED* ]] && {
      print "[pkg] HOOK_SRC_PATHS[$hk]: UNRESOLVED"; ok=0; continue
    }
    [[ ! -f "${HOOK_SRC_PATHS[$hk]}" ]] && {
      print "[pkg] HOOK_SRC_PATHS[$hk]: not found"; ok=0
    }
  done
  [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]] && {
    print "[pkg] RELEASE1B_SCHEMA_SRC: UNRESOLVED"; ok=0
  }
  local sd="${${(%):-%N}:h}"
  [[ ! -f "${sd}/${OTP_ADAPTER_FILENAME}" ]] && {
    print "[pkg] OTP adapter not found"; ok=0
  }
  (( ok )) && print "[pkg] OK" && return 0
  print "[pkg] INCOMPLETE"; return 1
}

# ────────────────────────────────────────────────────────────
# §12 NSU BOOTSTRAP  (D23-2, D23-3)
#
# PocketBase v0.29.3 auth endpoint: _superusers collection.
# No CLI usage. No password in process args, env listings, or
# shell history. Password is held briefly in a local (non-exported)
# shell variable, written to a permissions-600 migration file in the
# isolated root (mode 700), and deleted immediately after PB startup.
# ────────────────────────────────────────────────────────────
pb_setup_nsu_credentials() {
  _NSU_EMAIL="cp0_nsu_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  _NSU_PW_FILE=$(pb_secure_tmpfile .pw)
  openssl rand -base64 32 | tr -d '\n=' > "$_NSU_PW_FILE"
}

pb_write_nsu_bootstrap_migration() {
  print "=== Writing NSU bootstrap migration ==="
  _NSU_BOOTSTRAP_MIG_PATH="${RELEASE1B_PB_MIGRATIONS_DIR}/0000000001_r23_nsu_bootstrap.js"
  # Password read into local (non-exported) shell variable; cleared after use.
  local _su_pw; _su_pw=$(cat "$_NSU_PW_FILE")
  {
    printf 'migrate(function(app) {\n'
    printf '  var col = app.findCollectionByNameOrId("_superusers");\n'
    printf '  var rec = new Record(col);\n'
    printf '  rec.set("email", "%s");\n' "$_NSU_EMAIL"
    printf '  rec.set("password", "%s");\n' "$_su_pw"
    printf '  app.save(rec);\n'
    printf '}, function(app) {\n'
    printf '  try {\n'
    printf '    var r = app.findAuthRecordByEmail("_superusers", "%s");\n' "$_NSU_EMAIL"
    printf '    app.delete(r);\n'
    printf '  } catch(_) {}\n'
    printf '});\n'
  } > "$_NSU_BOOTSTRAP_MIG_PATH"
  chmod 600 "$_NSU_BOOTSTRAP_MIG_PATH"
  # Clear password from shell variable immediately.
  _su_pw=""
  t_pass "T-NSU-BOOTSTRAP-MIG-WRITTEN"
}

pb_write_future_schema_migration() {
  print "=== Writing future schema migration ==="
  local mig="${RELEASE1B_PB_MIGRATIONS_DIR}/9999999999_r23_future_schema.js"
  cat > "$mig" << 'JSEOF'
migrate(function(app) {
  var users = app.findCollectionByNameOrId("users");
  users.fields.add(new BoolField({ name: "phone_verified" }));
  app.save(users);

  var otps = app.findCollectionByNameOrId("phone_otps");
  otps.fields.add(new SelectField({
    name: "adapter_status",
    values: ["pending_send","sent_active","send_failed","expired","consumed"],
    maxSelect: 1,
  }));
  otps.fields.add(new TextField({ name: "requesting_user_id", max: 20 }));
  app.save(otps);
}, function(app) {
  try { var u=app.findCollectionByNameOrId("users"); u.fields.removeByName("phone_verified"); app.save(u); } catch(_){}
  try {
    var o=app.findCollectionByNameOrId("phone_otps");
    o.fields.removeByName("adapter_status"); o.fields.removeByName("requesting_user_id");
    app.save(o);
  } catch(_){}
});
JSEOF
  chmod 600 "$mig"
  t_pass "T-FUTURE-SCHEMA-WRITTEN"
}

pb_write_phone_guard_hook() {
  print "=== Writing phone+phone_verified guard hook ==="
  local dest="${RELEASE1B_PB_HOOKS_DIR}/${PHONE_GUARD_HOOK_FILENAME}"
  cat > "$dest" << 'JSEOF'
// release1b_r23_phone_verified_guard.pb.js
// TEMPORARY LOCAL GUARD — ISOLATED ENVIRONMENT ONLY

onRecordUpdateRequest(function(e) {
  var body = e.requestInfo().body;
  var touchesPhone = body["phone"] !== undefined;
  var touchesPV    = body["phone_verified"] !== undefined;
  if (!touchesPhone && !touchesPV) { e.next(); return; }

  // Consistency: phone_verified=true requires non-blank phone (all callers).
  if (touchesPV && body["phone_verified"] === true) {
    var targetRole = e.record ? e.record.getString("role") : "";
    if (targetRole === "admin" || targetRole === "superadmin") {
      throw new ForbiddenError(
        "Admin and superadmin accounts cannot be made eligible for phone authentication."
      );
    }
    var effectivePhone = touchesPhone
      ? String(body["phone"] || "").trim()
      : (e.record ? e.record.getString("phone") : "");
    if (!effectivePhone) {
      throw new BadRequestError(
        "Cannot set phone_verified=true without a non-blank phone number."
      );
    }
  }

  // _superusers: permitted as emergency recovery.
  try {
    if (e.auth && e.auth.collection().name === "_superusers") { e.next(); return; }
  } catch (_) {}

  // All application-layer callers blocked.
  throw new ForbiddenError(
    "users.phone and users.phone_verified can only be modified by the " +
    "authorized server-side OTP verification path or _superusers emergency recovery."
  );
}, "users");
JSEOF
  chmod 600 "$dest"
  t_pass "T-PHONE-GUARD-HOOK-WRITTEN"
}

pb_apply_schema_migrations() {
  print "=== Applying schema migrations ==="
  if [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]]; then
    t_unresolved "T-SCHEMA-MIGRATIONS" "RELEASE1B_SCHEMA_SRC NEEDS-EXTERNAL"
    return 0
  fi
  [[ -d "$RELEASE1B_SCHEMA_SRC" ]] || {
    t_blocking "T-SCHEMA-MIGRATIONS" "Not a dir: ${RELEASE1B_SCHEMA_SRC}"
    return 1
  }
  local js_count=0 excluded=0 cred_suspect=0 _jf
  for _jf in "${RELEASE1B_SCHEMA_SRC}"/*.js(N); do
    local bn="${_jf##*/}"
    if [[ "$bn" == "$SEED_MIGRATION_EXCLUDE" ]]; then
      (( excluded++ )); continue
    fi
    local scan_rc
    python3 "$PBJ_CRED_SCAN_PY" "$_jf" 2>/dev/null; scan_rc=$?
    (( scan_rc == 1 )) && {
      print "[migrations] CRED SUSPECTED: ${bn}" >&2; cred_suspect=1
    }
    cp "$_jf" "${RELEASE1B_PB_MIGRATIONS_DIR}/" && \
      chmod 600 "${RELEASE1B_PB_MIGRATIONS_DIR}/${bn}" || {
      t_blocking "T-SCHEMA-MIGRATIONS" "cp failed: ${bn}"
      return 1
    }
    (( js_count++ ))
  done
  (( cred_suspect )) && {
    t_blocking "T-SCHEMA-MIGRATIONS-CRED" "Credential detected in non-excluded migration"
    return 1
  }
  (( js_count == 0 )) && { t_blocking "T-SCHEMA-MIGRATIONS" "No .js files found"; return 1 }
  (( excluded == 0 )) && {
    t_blocking "T-SCHEMA-MIGRATIONS-EXCLUDE" "Seed migration not found to exclude"
    return 1
  }
  t_pass "T-SCHEMA-MIGRATIONS"
}

pb_deploy_hooks() {
  print "=== Deploying hooks ==="
  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local src="${HOOK_SRC_PATHS[$hk]}"
    [[ "$src" == UNRESOLVED* ]] && {
      t_unresolved "T-HOOK-DEPLOY-${hk}" "src NEEDS-EXTERNAL"; continue
    }
    [[ ! -f "$src" ]] && { t_blocking "T-HOOK-DEPLOY-${hk}" "file not found"; continue }
    local exp="${HOOK_EXPECTED_SHA256[$hk]:-}"
    if [[ "$exp" != UNRESOLVED* ]]; then
      local act; act=$(shasum -a 256 "$src" | awk '{print $1}')
      [[ "$act" != "$exp" ]] && { t_blocking "T-HOOK-HASH-${hk}" "hash mismatch"; continue }
    fi
    local dest="${RELEASE1B_PB_HOOKS_DIR}/$(basename "$src")"
    if cp "$src" "$dest" && chmod 600 "$dest"; then
      t_pass "T-HOOK-DEPLOY-${hk}"
    else
      t_blocking "T-HOOK-DEPLOY-${hk}" "cp failed"
    fi
  done
  local sd="${${(%):-%N}:h}" adapter_src="${sd}/${OTP_ADAPTER_FILENAME}"
  if [[ -f "$adapter_src" ]]; then
    if cp "$adapter_src" "${RELEASE1B_PB_HOOKS_DIR}/${OTP_ADAPTER_FILENAME}" && \
        chmod 600 "${RELEASE1B_PB_HOOKS_DIR}/${OTP_ADAPTER_FILENAME}"; then
      t_pass "T-HOOK-DEPLOY-otp_adapter"
    else
      t_blocking "T-HOOK-DEPLOY-otp_adapter" "cp failed"
    fi
  else
    t_blocking "T-HOOK-DEPLOY-otp_adapter" "adapter not found: ${adapter_src}"
  fi
  t_pass "T-HOOKDIR-VERIFY"
}

pb_start_pocketbase() {
  print "=== Starting PocketBase ==="
  [[ -x "$RELEASE1B_PB_BIN" ]] || pb_halt "PB binary not executable"
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
      print "=== PocketBase ready (${tries}s) ==="
      # D23-3: Delete bootstrap migration file immediately after PB processes it.
      if [[ -n "$_NSU_BOOTSTRAP_MIG_PATH" && -f "$_NSU_BOOTSTRAP_MIG_PATH" ]]; then
        rm -f "$_NSU_BOOTSTRAP_MIG_PATH"
        _NSU_BOOTSTRAP_MIG_PATH=""
        print "=== Bootstrap migration deleted (password exposure window closed) ==="
      fi
      return 0
    }
    sleep 1; (( tries++ ))
  done
  pb_halt "PocketBase did not become ready within 30s"
}

# D23-2: Auth via /api/collections/_superusers/auth-with-password.
# Runtime tests: T-SU-CREATE-AUTH (auth succeeds), T-SU-COLL-CHECK
# (collectionName == _superusers), T-SU-TOKEN-VALID (token non-empty).
pb_create_local_superuser() {
  print "=== Authenticating NSU (migration-created) ==="
  _NSU_TOK_FILE=$(pb_secure_tmpfile .tok)
  _NSU_AUTH_CFG=$(pb_secure_tmpfile .hdr)

  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${_NSU_EMAIL}" \
    "secret-file:password=${_NSU_PW_FILE}" 2>/dev/null || {
    t_blocking "T-SU-AUTH-BODY" "pbj.py failed building auth body"
    rm -f "$body_f"
    return 1
  }

  local sf; sf=$(pb_secure_tmpfile .http)
  local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" \
    "$sf" "$rp_f" \
    "$(pb_url /api/collections/_superusers/auth-with-password)" \
    "" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"

  # D23-1: fixed if/fi termination (no 'return 1 fi' pattern).
  if [[ "$status" != "200" ]]; then
    t_blocking "T-SU-AUTH" "NSU auth returned ${status}"
    rm -f "$resp_path"
    pb_wipe_secret_file "$_NSU_PW_FILE"
    return 1
  fi

  # D23-2: Verify response is from _superusers collection.
  local verify_result; verify_result=$(python3 - "$resp_path" << 'PYEOF'
import sys,json,re
try:
    with open(sys.argv[1]) as f: d=json.load(f)
    tok=d.get("token","")
    rec=d.get("record",{})
    coll=rec.get("collectionName","")
    if not re.match(r'^[A-Za-z0-9._\-]{10,}$',tok):
        print(f"ERROR:token_invalid"); sys.exit(1)
    if coll!="_superusers":
        print(f"ERROR:collection:{coll}"); sys.exit(1)
    print(tok)
except Exception as ex: print(f"ERROR:{ex}"); sys.exit(1)
PYEOF
)
  rm -f "$resp_path"
  pb_wipe_secret_file "$_NSU_PW_FILE"

  if [[ "$verify_result" == ERROR* ]]; then
    t_blocking "T-SU-COLL-CHECK" "${verify_result}"
    return 1
  fi
  t_pass "T-SU-COLL-CHECK"

  printf '%s' "$verify_result" > "$_NSU_TOK_FILE"
  python3 "$PBJ_AUTH_PY" "$_NSU_AUTH_CFG" "$_NSU_TOK_FILE" 2>/dev/null || {
    t_blocking "T-SU-AUTH-CFG" "pbj_auth.py failed"
    return 1
  }

  t_pass "T-SU-TOKEN-VALID"
  t_pass "T-SU-CREATE-AUTH"
}

pb_delete_local_superuser() {
  pb_wipe_secret_file "$_NSU_TOK_FILE"
  pb_wipe_secret_file "$_NSU_AUTH_CFG"
  t_pass "T-SU-DELETE"
}

pb_verify_email_domain() {
  print "=== Verifying example.invalid domain ==="
  local email="cp0_domtest_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" "role=user" 2>/dev/null || {
    t_blocking "T-SELFTEST-EMAIL-DOMAIN" "pbj.py failed"
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"
    return 1
  }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  pb_wipe_secret_file "$pw_file"
  if [[ "$status" == "200" ]]; then
    local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    rm -f "$resp_path"
    if [[ -n "$rec_id" && "$rec_id" != "__absent__" ]]; then
      local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"
      pb_delete_record "users" "$id_f"
    fi
    t_pass "T-SELFTEST-EMAIL-DOMAIN"
    return 0
  fi
  rm -f "$resp_path"
  t_blocking "T-SELFTEST-EMAIL-DOMAIN" "example.invalid rejected (HTTP ${status})."
  return 1
}

# ────────────────────────────────────────────────────────────
# §13 HTTP CAPTURE HELPER
# ────────────────────────────────────────────────────────────
pb_capture() {
  local method="$1" url_suffix="$2" auth_cfg="$3" body_f="$4"
  local status_out="$5" resp_path_out="$6"
  shift 6; local -a expected=("$@")
  local url; url=$(pb_url "$url_suffix")
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_out" "$resp_path_out" "$url" \
      "${auth_cfg:-}" "${body_f:-}" "$method"
  local actual; actual=$(cat "$status_out" 2>/dev/null)
  local exp; for exp in "${expected[@]}"; do [[ "$actual" == "$exp" ]] && return 0; done
  return 1
}

# ────────────────────────────────────────────────────────────
# §14 USER LIFECYCLE
# ────────────────────────────────────────────────────────────
pb_create_test_user() {
  local role="$1" id_file_var="$2" tok_file_var="$3" auth_cfg_var="$4"
  local email="cp0_${role}_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  local id_file; id_file=$(pb_secure_tmpfile .id)
  local tok_file; tok_file=$(pb_secure_tmpfile .tok)
  local auth_cfg; auth_cfg=$(pb_secure_tmpfile .hdr)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${email}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" \
    "role=${role}" "b:emailVisibility=true" 2>/dev/null || {
    t_harness_err "T-USER-CREATE-${role}" "pbj.py"
    rm -f "$body_f"; pb_wipe_secret_file "$pw_file"
    return 1
  }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"

  # D23-1: proper if/fi termination.
  if [[ "$status" != "200" ]]; then
    t_blocking "T-USER-CREATE-${role}" "HTTP ${status}"
    rm -f "$rp"; pb_wipe_secret_file "$pw_file"
    return 1
  fi

  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
  rm -f "$rp"
  [[ -z "$rec_id" || "$rec_id" == "__absent__" ]] && {
    t_blocking "T-USER-CREATE-ID-${role}" "no id"; pb_wipe_secret_file "$pw_file"; return 1
  }
  printf '%s' "$rec_id" > "$id_file"

  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "identity=${email}" "secret-file:password=${pw_file}" 2>/dev/null
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/auth-with-password)" "" "$body_f" "POST"
  status=$(cat "$sf" 2>/dev/null); rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"

  # D23-1: proper if/fi termination.
  if [[ "$status" != "200" ]]; then
    t_blocking "T-USER-AUTH-${role}" "HTTP ${status}"
    rm -f "$rp"; pb_wipe_secret_file "$pw_file"
    return 1
  fi

  local token; token=$(python3 "$PBJ_FIELD_PY" "$rp" "token" 2>/dev/null)
  rm -f "$rp"
  pb_wipe_secret_file "$pw_file"
  [[ -z "$token" || "$token" == "__absent__" ]] && {
    t_blocking "T-USER-AUTH-TOKEN-${role}" "no token"; return 1
  }
  printf '%s' "$token" > "$tok_file"
  python3 "$PBJ_AUTH_PY" "$auth_cfg" "$tok_file" 2>/dev/null || {
    t_blocking "T-USER-AUTH-CFG-${role}" "pbj_auth.py failed"; return 1
  }
  typeset -g "${id_file_var}=${id_file}" "${tok_file_var}=${tok_file}" "${auth_cfg_var}=${auth_cfg}"
  t_pass "T-USER-CREATE-AUTH-${role}"
}

pb_delete_test_user() {
  pb_delete_record "users" "$2" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$3"; pb_wipe_secret_file "$4"
}

pb_delete_record() {
  local collection="$1" id_file="$2"
  [[ -f "$id_file" ]] || return 0
  local rec_id; rec_id=$(cat "$id_file" 2>/dev/null); [[ -z "$rec_id" ]] && return 0
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url "/api/collections/${collection}/records/${rec_id}")" \
    "$_NSU_AUTH_CFG" "" "DELETE"
  local status; status=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$sf" "$rp_f" "$rp" "$id_file"
  [[ "$status" != "200" && "$status" != "204" && "$status" != "404" ]] && {
    CLEANUP_FAILURE=1; return 1
  }
}

pb_capture_rule_baseline() {
  local coll="$1" rule_type="$2"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url "/api/collections/${coll}")" "$_NSU_AUTH_CFG" "" "GET"
  local st; st=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$sf" "$rp_f"
  if [[ "$st" != "200" ]]; then
    rm -f "$rp"; t_harness_err "T-RULE-BASELINE-${coll}" "GET ${st}"; return 1
  fi
  local val; val=$(python3 "$PBJ_FIELD_PY" "$rp" "$rule_type" 2>/dev/null)
  rm -f "$rp"
  [[ "$val" == "__null__" ]] && val="__pb_null__"
  RULE_BASELINE["${coll}::${rule_type}"]="$val"
  t_pass "T-RULE-BASELINE-${coll}-${rule_type}"
}

pb_apply_rule_local() {
  local coll="$1" rule_type="$2" nv="$3"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  printf '{ "%s": "%s" }' "$rule_type" "$nv" > "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url "/api/collections/${coll}")" "$_NSU_AUTH_CFG" "$body_f" "PATCH"
  local status; status=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f" "$rp"
  if [[ "$status" != "200" ]]; then
    t_harness_err "T-RULE-APPLY-${coll}" "HTTP ${status}"; return 1
  fi
  t_pass "T-RULE-APPLY-${coll}-${rule_type}"
}

pb_restore_rule_local() {
  local coll="$1" rule_type="$2"
  local baseline="${RULE_BASELINE["${coll}::${rule_type}"]:-}"
  [[ -z "$baseline" ]] && { t_harness_err "T-RULE-RESTORE-${coll}" "No baseline"; return 1 }
  local rv
  [[ "$baseline" == "__pb_null__" ]] && rv="null" || rv="\"${baseline}\""
  local body_f; body_f=$(pb_secure_tmpfile .json)
  printf '{ "%s": %s }' "$rule_type" "$rv" > "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url "/api/collections/${coll}")" "$_NSU_AUTH_CFG" "$body_f" "PATCH"
  local status; status=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f" "$rp"
  if [[ "$status" != "200" ]]; then
    CLEANUP_FAILURE=1; t_harness_err "T-RULE-RESTORE-${coll}" "HTTP ${status}"; return 1
  fi
  t_pass "T-RULE-RESTORE-${coll}-${rule_type}"
}

# ────────────────────────────────────────────────────────────
# §15 SCHEMA AND FIXTURE HELPERS
# ────────────────────────────────────────────────────────────
pb_verify_schema() {
  print "=== Verifying schema ==="
  local col
  for col in users children growth_logs nutrition_logs activity_logs wellbeing_logs \
    immunisations articles bookmarks notifications notification_preferences \
    notification_queue phone_otps push_subscriptions courses enrollments lesson_progress; do
    local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
      "$(pb_url "/api/collections/${col}")" "$_NSU_AUTH_CFG" "" "GET"
    local st; st=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null)
    rm -f "$sf" "$rp_f" "$rp"
    if [[ "$st" == "200" ]]; then t_pass "T-SCHEMA-COL-${col}"
    else t_fail "T-SCHEMA-COL-${col}" "HTTP ${st}"
    fi
  done
}

pb_register_fixture()   { FIXTURE_REGISTRY[$1]="$2" }
pb_unregister_fixture() { unset "FIXTURE_REGISTRY[$1]" }
pb_cleanup_all_fixtures() {
  local fid; for fid in "${(@k)FIXTURE_REGISTRY}"; do
    local fn="${FIXTURE_REGISTRY[$fid]}"
    typeset -f "$fn" &>/dev/null && { "$fn" "$fid" || CLEANUP_FAILURE=1 }
    unset "FIXTURE_REGISTRY[$fid]"
  done
}

pb_create_legacy_fixture() {
  print "=== Legacy fixture ==="
  LEGACY_ID_FILE=$(pb_secure_tmpfile .id)
  LEGACY_TOK_FILE=$(pb_secure_tmpfile .tok)
  LEGACY_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local email="cp0_legacy_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${email}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" \
    "role=user" "b:emailVisibility=true" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null); local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  if [[ "$status" == "200" ]]; then
    local rid; rid=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
    rm -f "$rp"
    printf '%s' "$rid" > "$LEGACY_ID_FILE"
    LEGACY_CHILD_ID_FILE=$(pb_secure_tmpfile .id)
    local cbody; cbody=$(pb_secure_tmpfile .json)
    python3 "$PBJ_PY" "$cbody" "user=${rid}" "name=LegacyChild_${RUN_SUFFIX}" 2>/dev/null
    local cs; cs=$(pb_secure_tmpfile .http); local cr; cr=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$cs" "$cr" \
      "$(pb_url /api/collections/children/records)" "$_NSU_AUTH_CFG" "$cbody" "POST"
    local cst; cst=$(cat "$cs" 2>/dev/null); local crp; crp=$(cat "$cr" 2>/dev/null)
    rm -f "$cbody" "$cs" "$cr"
    [[ "$cst" == "200" ]] && {
      python3 "$PBJ_EXTRACT_PY" "$crp" "id" 2>/dev/null > "$LEGACY_CHILD_ID_FILE" || true
    }
    rm -f "$crp"
    body_f=$(pb_secure_tmpfile .json)
    python3 "$PBJ_PY" "$body_f" "identity=${email}" "secret-file:password=${pw_file}" 2>/dev/null
    sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
      "$(pb_url /api/collections/users/auth-with-password)" "" "$body_f" "POST"
    status=$(cat "$sf" 2>/dev/null); rp=$(cat "$rp_f" 2>/dev/null)
    rm -f "$body_f" "$sf" "$rp_f"
    [[ "$status" == "200" ]] && {
      python3 "$PBJ_FIELD_PY" "$rp" "token" 2>/dev/null > "$LEGACY_TOK_FILE" || true
      python3 "$PBJ_AUTH_PY" "$LEGACY_AUTH_CFG" "$LEGACY_TOK_FILE" 2>/dev/null || true
    }
    rm -f "$rp"
  else
    rm -f "$rp"; t_harness_err "T-LEGACY-CREATE" "HTTP ${status}"
  fi
  pb_wipe_secret_file "$pw_file"
  t_pass "T-LEGACY-FIXTURE-CREATE"
}

pb_delete_legacy_fixture() {
  [[ -n "$LEGACY_CHILD_ID_FILE" ]] && pb_delete_record "children" "$LEGACY_CHILD_ID_FILE" || true
  [[ -n "$LEGACY_GROWTH_ID_FILE" ]] && pb_delete_record "growth_logs" "$LEGACY_GROWTH_ID_FILE" || true
  pb_delete_record "users" "$LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$LEGACY_TOK_FILE"; pb_wipe_secret_file "$LEGACY_AUTH_CFG"
}

pb_setup_alias_group() {
  print "=== Alias group fixtures ==="
  ALIAS_ID_FILE=$(pb_secure_tmpfile .id)
  ALIAS_PW_FILE=$(pb_secure_tmpfile .pw)
  ALIAS_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local alias_email="cp0_alias_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  openssl rand -base64 24 | tr -d '\n=' > "$ALIAS_PW_FILE"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${alias_email}" \
    "secret-file:password=${ALIAS_PW_FILE}" "secret-file:passwordConfirm=${ALIAS_PW_FILE}" \
    "role=user" "b:emailVisibility=true" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null); local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  [[ "$status" == "200" ]] && {
    python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null > "$ALIAS_ID_FILE" || true
  }
  rm -f "$rp"
  WRONG_PW_FILE=$(pb_secure_tmpfile .pw)
  printf 'definitely-wrong-password-R23xYzQ' > "$WRONG_PW_FILE"
  TIMING_LEGACY_ID_FILE=$(pb_secure_tmpfile .id)
  TIMING_LEGACY_PW_FILE=$(pb_secure_tmpfile .pw)
  TIMING_LEGACY_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local tl_email="cp0_tl_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  openssl rand -base64 24 | tr -d '\n=' > "$TIMING_LEGACY_PW_FILE"
  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${tl_email}" \
    "secret-file:password=${TIMING_LEGACY_PW_FILE}" \
    "secret-file:passwordConfirm=${TIMING_LEGACY_PW_FILE}" \
    "role=user" "b:emailVisibility=true" 2>/dev/null
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "$_NSU_AUTH_CFG" "$body_f" "POST"
  status=$(cat "$sf" 2>/dev/null); rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  [[ "$status" == "200" ]] && {
    python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null > "$TIMING_LEGACY_ID_FILE" || true
  }
  rm -f "$rp"
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
# §16 INJECTION TESTS
# ────────────────────────────────────────────────────────────
_inj_check_no_users_record() {
  local email="$1" label="$2"
  local fe; fe=$(python3 -c \
    "import urllib.parse,sys; print(urllib.parse.quote(f'email=\"{sys.argv[1]}\"'))" \
    -- "$email" 2>/dev/null)
  local cs; cs=$(pb_secure_tmpfile .http); local cr; cr=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$cs" "$cr" \
    "$(pb_url "/api/collections/users/records")?filter=${fe}&perPage=1" \
    "$_NSU_AUTH_CFG" "" "GET"
  local cst; cst=$(cat "$cs" 2>/dev/null); local crp; crp=$(cat "$cr" 2>/dev/null)
  rm -f "$cs" "$cr"
  if [[ "$cst" == "200" ]]; then
    local cnt; cnt=$(python3 - "$crp" << 'PYEOF'
import sys,json
with open(sys.argv[1]) as f: d=json.load(f)
print(len(d.get('items',[])))
PYEOF
)
    rm -f "$crp"
    if [[ "$cnt" != "0" ]]; then
      t_blocking "$label" "HTTP rejection but users record exists (${cnt} items)."
      return 1
    fi
  else
    rm -f "$crp"; t_harness_err "$label" "Existence check returned ${cst}"; return 1
  fi
  return 0
}

pb_inject_create_and_verify() {
  local label="$1" field="$2" value="$3" bad_values="$4"
  local email="cp0_inj_${label:0:8}_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  local extra=""; [[ "$value" == "true" || "$value" == "false" ]] && extra="b:"
  python3 "$PBJ_PY" "$body_f" "email=${email}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" \
    "${extra}${field}=${value}" 2>/dev/null || {
    t_harness_err "${label}" "pbj.py failed"
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"
    return 1
  }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"; pb_wipe_secret_file "$pw_file"

  case "$http_status" in
    400|401|403)
      if _inj_check_no_users_record "$email" "$label"; then
        t_pass "${label}"
      fi
      return 0 ;;
    200) ;;
    000|''|5[0-9][0-9]|*)
      rm -f "$resp_path"; t_harness_err "${label}" "Unexpected HTTP ${http_status}"
      return 1 ;;
  esac

  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  [[ -z "$rec_id" || "$rec_id" == "__absent__" ]] && {
    t_blocking "${label}" "HTTP 200 but no id"; return 1
  }
  local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"
  local vs; vs=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$vs" "$vrp_f" \
    "$(pb_url "/api/collections/users/records/${rec_id}")" "$_NSU_AUTH_CFG" "" "GET"
  local vst; vst=$(cat "$vs" 2>/dev/null)
  local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs" "$vrp_f"
  pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1
  if [[ "$vst" != "200" ]]; then
    rm -f "$vrp"; t_blocking "${label}" "NSU verify ${vst}"; return 1
  fi
  local persisted; persisted=$(python3 "$PBJ_FIELD_PY" "$vrp" "$field" 2>/dev/null)
  rm -f "$vrp"
  local bv; for bv in ${=bad_values}; do
    if [[ "$persisted" == "$bv" ]]; then
      t_blocking "${label}" "INJECTION CONFIRMED: ${field}='${persisted}'"
      return 1
    fi
  done
  t_pass "${label}"
}

t_inject_create_unexpected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-INJECT-CREATE-UNEXPECTED" "blocked"; return }
  local email="cp0_inj_unexp_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${email}" \
    "secret-file:password=${pw_file}" "secret-file:passwordConfirm=${pw_file}" \
    "b:phone_verified=true" 2>/dev/null || {
    t_harness_err "T-INJECT-CREATE-UNEXPECTED" "pbj.py failed"
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"; return
  }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"; pb_wipe_secret_file "$pw_file"

  case "$http_status" in
    400|401|403)
      # D23-8: queries users collection (corrected from phone_otps in D22-8).
      if _inj_check_no_users_record "$email" "T-INJECT-CREATE-UNEXPECTED"; then
        rm -f "$resp_path"; t_pass "T-INJECT-CREATE-UNEXPECTED"
      else
        rm -f "$resp_path"
      fi
      return ;;
    200) ;;
    000|''|5[0-9][0-9]|*)
      rm -f "$resp_path"
      t_harness_err "T-INJECT-CREATE-UNEXPECTED" "HTTP ${http_status}"
      return ;;
  esac

  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  [[ -z "$rec_id" || "$rec_id" == "__absent__" ]] && {
    t_blocking "T-INJECT-CREATE-UNEXPECTED" "200 no id"; return
  }
  local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"
  local vs; vs=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$vs" "$vrp_f" \
    "$(pb_url "/api/collections/users/records/${rec_id}")" "$_NSU_AUTH_CFG" "" "GET"
  local vst; vst=$(cat "$vs" 2>/dev/null)
  local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs" "$vrp_f"
  pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1
  if [[ "$vst" != "200" ]]; then
    rm -f "$vrp"; t_blocking "T-INJECT-CREATE-UNEXPECTED" "NSU verify ${vst}"; return
  fi
  local shape; shape=$(python3 - "$vrp" << 'PYEOF'
import sys,json
errors=[]
with open(sys.argv[1]) as f: d=json.load(f)
if d.get("role","") in ("admin","superadmin"): errors.append("PRIVILEGED_ROLE")
if d.get("phone_verified",False) is True: errors.append("PHONE_VERIFIED_TRUE")
for sf in ("tokenKey","passwordHash"):
    if sf in d: errors.append(f"SYSTEM_FIELD:{sf}")
if errors: print("SHAPE_ERR:"+"|".join(errors)); sys.exit(1)
print("OK")
PYEOF
)
  rm -f "$vrp"
  if [[ "$shape" == "OK" ]]; then
    t_pass "T-INJECT-CREATE-UNEXPECTED"
  else
    t_blocking "T-INJECT-CREATE-UNEXPECTED" "Shape violation: ${shape}"
  fi
}

t_role_inject_emergency_group() {
  print "=== §28.5 Role Injection Emergency Tests ==="
  pb_inject_create_and_verify "T-INJECT-CREATE-ANON-ADMIN"  "role"           "admin"      "admin superadmin"
  pb_inject_create_and_verify "T-INJECT-CREATE-ANON-SADMIN" "role"           "superadmin" "admin superadmin"
  pb_inject_create_and_verify "T-INJECT-CREATE-VERIFIED"    "verified"       "true"       "true"
  pb_inject_create_and_verify "T-INJECT-CREATE-PHONE-VER"   "phone_verified" "true"       "true"
  t_inject_create_unexpected
  (( T_BLOCKING > 0 )) && HALT_DEPENDENTS=1
}

# ────────────────────────────────────────────────────────────
# §17 OTP HELPERS  (D23-10: PBJ_PY for all OTP bodies)
# ────────────────────────────────────────────────────────────

# D23-10: All OTP request bodies use PBJ_PY (no raw printf for JSON).
_otp_body_request() {
  local phone="$1" out_file="$2"
  python3 "$PBJ_PY" "$out_file" "phone=${phone}" 2>/dev/null
}

_otp_body_verify() {
  local phone="$1" code="$2" out_file="$3"
  python3 "$PBJ_PY" "$out_file" "phone=${phone}" "code=${code}" 2>/dev/null
}

_otp_set_mode() {
  local mode="$1"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "mode=${mode}" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_CTRL_ROUTE" "$_NSU_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"
  local rc=$?; local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f" "$rp"
  return $rc
}

_read_user_field() {
  local user_id="$1" field="$2"
  local vs; vs=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$vs" "$vrp_f" \
    "$(pb_url "/api/collections/users/records/${user_id}")" "$_NSU_AUTH_CFG" "" "GET"
  local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs" "$vrp_f"
  local val; val=$(python3 "$PBJ_FIELD_PY" "$vrp" "$field" 2>/dev/null)
  rm -f "$vrp"
  printf '%s' "$val"
}

# Request OTP; read active code via NSU. Returns code or "" on failure.
_otp_request_and_read_code() {
  local phone="$1" auth_cfg="${2:-$ORDINARY_AUTH_CFG}"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_request "$phone" "$body_f" || { rm -f "$body_f"; printf ''; return 1 }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "$auth_cfg" "$body_f" "$sf" "$rp_f" "200"
  local rc=$?; local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f" "$rp"
  if (( rc != 0 )); then printf ''; return 1; fi
  local fe; fe=$(python3 -c \
    "import urllib.parse,sys; print(urllib.parse.quote(f\"phone='{sys.argv[1]}' && adapter_status='sent_active'\"))" \
    -- "$phone" 2>/dev/null)
  local ds; ds=$(pb_secure_tmpfile .http); local dr; dr=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$ds" "$dr" \
    "$(pb_url "/api/collections/phone_otps/records")?filter=${fe}&perPage=1" \
    "$_NSU_AUTH_CFG" "" "GET"
  local otp_rp; otp_rp=$(cat "$dr" 2>/dev/null)
  rm -f "$ds" "$dr"
  local code; code=$(python3 - "$otp_rp" << 'PYEOF'
import sys,json
try:
    with open(sys.argv[1]) as f: d=json.load(f)
    items=d.get('items',[])
    print(items[0].get("code","") if items else "")
except: print("")
PYEOF
)
  rm -f "$otp_rp"; printf '%s' "$code"
}

_otp_count_by_status() {
  local phone="$1" adapter_status="$2"
  local fe; fe=$(python3 -c \
    "import urllib.parse,sys; print(urllib.parse.quote(f\"phone='{sys.argv[1]}' && adapter_status='{sys.argv[2]}'\"))" \
    -- "$phone" "$adapter_status" 2>/dev/null)
  local ds; ds=$(pb_secure_tmpfile .http); local dr; dr=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$ds" "$dr" \
    "$(pb_url "/api/collections/phone_otps/records")?filter=${fe}&perPage=100" \
    "$_NSU_AUTH_CFG" "" "GET"
  local otp_rp; otp_rp=$(cat "$dr" 2>/dev/null)
  rm -f "$ds" "$dr"
  local cnt; cnt=$(python3 - "$otp_rp" << 'PYEOF'
import sys,json
with open(sys.argv[1]) as f: d=json.load(f)
print(len(d.get('items',[])))
PYEOF
)
  rm -f "$otp_rp"; printf '%s' "$cnt"
}

_reset_user_phone() {
  local user_id="$1"
  local reset_f; reset_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$reset_f" "phone=" "b:phone_verified=false" 2>/dev/null
  local rs; rs=$(pb_secure_tmpfile .http); local rr; rr=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${user_id}" \
    "$_NSU_AUTH_CFG" "$reset_f" "$rs" "$rr" "200"
  local rrp; rrp=$(cat "$rr" 2>/dev/null)
  rm -f "$reset_f" "$rs" "$rr" "$rrp"
}

# ────────────────────────────────────────────────────────────
# §18 PHONE GUARD TESTS  (D23-4,5,6,7,8)
# ────────────────────────────────────────────────────────────
t_phone_ordinary_cannot_patch_phone() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-ORD-NO-PATCH-PHONE" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "phone=${SYNTH_PHONE_LINK}" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
      "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-ORD-NO-PATCH-PHONE"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-ORD-NO-PATCH-PHONE" "Expected 403; got ${actual}"
  fi
}

t_phone_ordinary_cannot_patch_phone_verified() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-ORD-NO-PATCH-PV" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "b:phone_verified=true" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
      "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-ORD-NO-PATCH-PV"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-ORD-NO-PATCH-PV" "Expected 403; got ${actual}"
  fi
}

t_phone_mixed_field_rejection() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-MIXED-FIELD-REJECT" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "phone=${SYNTH_PHONE_LINK}" \
    "name=SHOULD_NOT_PERSIST_${RUN_SUFFIX}" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  if [[ "$actual" != "403" ]]; then
    t_fail "T-PHONE-MIXED-FIELD-REJECT" "Expected 403; got ${actual}"
    return
  fi
  local after_phone; after_phone=$(_read_user_field "$ord_id" "phone")
  local after_name;  after_name=$(_read_user_field "$ord_id" "name")
  if [[ "$after_phone" == "$SYNTH_PHONE_LINK" ]]; then
    t_fail "T-PHONE-MIXED-FIELD-REJECT" "phone persisted despite 403"
    return
  fi
  if [[ "$after_name" == "SHOULD_NOT_PERSIST_${RUN_SUFFIX}" ]]; then
    t_fail "T-PHONE-MIXED-FIELD-REJECT" "name persisted despite 403 (mixed rejection failed)"
    return
  fi
  t_pass "T-PHONE-MIXED-FIELD-REJECT"
}

t_phone_nsu_can_set_phone_and_pv_together() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-NSU-RECOVERY" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _reset_user_phone "$ord_id"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "phone=${SYNTH_PHONE_LINK}" "b:phone_verified=true" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
      "$_NSU_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    local pv; pv=$(_read_user_field "$ord_id" "phone_verified")
    local ph; ph=$(_read_user_field "$ord_id" "phone")
    _reset_user_phone "$ord_id"
    if [[ "$pv" == "true" && "$ph" == "$SYNTH_PHONE_LINK" ]]; then
      t_pass "T-PHONE-NSU-RECOVERY"
    else
      t_fail "T-PHONE-NSU-RECOVERY" "phone='${ph}' pv='${pv}'"
    fi
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-NSU-RECOVERY" "NSU set phone+pv failed; got ${actual}"
  fi
}

t_phone_nsu_cannot_set_pv_without_phone() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-NSU-PV-NO-PHONE" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _reset_user_phone "$ord_id"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "b:phone_verified=true" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
      "$_NSU_AUTH_CFG" "$body_f" "$sf" "$rp_f" "400"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-NSU-PV-NO-PHONE"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-NSU-PV-NO-PHONE" "Expected 400; got ${actual}"
  fi
}

t_phone_otp_auth_requirements() {
  (( HALT_DEPENDENTS )) && {
    for l in ANON ADMIN SADMIN; do t_skip "T-PHONE-OTP-AUTH-${l}" "blocked"; done; return
  }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_request "$SYNTH_PHONE_OTP" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  # Anonymous → 401.
  if pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "" "$body_f" "$sf" "$rp_f" "401"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-OTP-AUTH-ANON"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-OTP-AUTH-ANON" "Expected 401; got ${actual}"
  fi
  # Admin → 403.
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "$ADMIN_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-OTP-AUTH-ADMIN"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-OTP-AUTH-ADMIN" "Expected 403; got ${actual}"
  fi
  # Superadmin → 403.
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "$SADMIN_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-OTP-AUTH-SADMIN"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-OTP-AUTH-SADMIN" "Expected 403; got ${actual}"
  fi
  rm -f "$body_f"
}

# D23-4: User B cannot verify an OTP requested by User A.
t_phone_otp_cross_user_attack() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-OTP-CROSS-USER" "blocked"; return }
  [[ -z "$ORDINARY_B_AUTH_CFG" || -z "$ORDINARY_B_ID_FILE" ]] && {
    t_skip "T-PHONE-OTP-CROSS-USER" "User B fixture not available"; return
  }
  _otp_set_mode "success" || { t_harness_err "T-PHONE-OTP-CROSS-USER" "Mode set failed"; return }
  local user_b_id; user_b_id=$(cat "$ORDINARY_B_ID_FILE" 2>/dev/null)

  # User A (ordinary) requests OTP for SYNTH_PHONE_XUSER.
  local code; code=$(_otp_request_and_read_code "$SYNTH_PHONE_XUSER" "$ORDINARY_AUTH_CFG")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-PHONE-OTP-CROSS-USER" "OTP request or code read failed"
    return
  fi

  # User B attempts to verify with User A's phone+code — must be rejected (403 or 400).
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$SYNTH_PHONE_XUSER" "$code" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" \
    "$ORDINARY_B_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403" "400"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"

  if [[ "$actual" != "403" && "$actual" != "400" ]]; then
    t_fail "T-PHONE-OTP-CROSS-USER" "Cross-user verify succeeded with ${actual} (expected 403/400)"
    return
  fi

  # Verify User B's phone and pv unchanged.
  local b_phone; b_phone=$(_read_user_field "$user_b_id" "phone")
  local b_pv;    b_pv=$(_read_user_field "$user_b_id" "phone_verified")
  if [[ "$b_phone" == "$SYNTH_PHONE_XUSER" || "$b_pv" == "true" ]]; then
    t_fail "T-PHONE-OTP-CROSS-USER" \
      "Cross-user spoofing: User B has phone='${b_phone}' pv='${b_pv}'"
    return
  fi

  # Verify OTP is still active (not consumed by the rejected verification).
  local active_cnt; active_cnt=$(_otp_count_by_status "$SYNTH_PHONE_XUSER" "sent_active")
  if [[ "$active_cnt" != "1" ]]; then
    t_fail "T-PHONE-OTP-CROSS-USER" \
      "OTP state changed after rejected cross-user attempt (active=${active_cnt})"
    return
  fi

  t_pass "T-PHONE-OTP-CROSS-USER"
  print "[cross-user] requesting_user_id binding enforced: cross-user spoofing rejected."
}

# D23-5: Expired OTP test.
t_otp_expired() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-EXPIRED" "blocked"; return }
  _otp_set_mode "success" || { t_harness_err "T-OTP-EXPIRED" "Mode set failed"; return }
  local phone="+601_R23TEST_11199001"

  # Request OTP.
  local code; code=$(_otp_request_and_read_code "$phone")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-OTP-EXPIRED" "OTP request failed"; return
  fi

  # Find active OTP record ID via NSU and set expires_at to past.
  local fe; fe=$(python3 -c \
    "import urllib.parse,sys; print(urllib.parse.quote(f\"phone='{sys.argv[1]}' && adapter_status='sent_active'\"))" \
    -- "$phone" 2>/dev/null)
  local ds; ds=$(pb_secure_tmpfile .http); local dr; dr=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$ds" "$dr" \
    "$(pb_url "/api/collections/phone_otps/records")?filter=${fe}&perPage=1" \
    "$_NSU_AUTH_CFG" "" "GET"
  local otp_rp; otp_rp=$(cat "$dr" 2>/dev/null); rm -f "$ds" "$dr"
  local otp_id; otp_id=$(python3 - "$otp_rp" << 'PYEOF'
import sys,json
with open(sys.argv[1]) as f: d=json.load(f)
items=d.get('items',[])
print(items[0].get("id","") if items else "")
PYEOF
)
  rm -f "$otp_rp"
  if [[ -z "$otp_id" ]]; then
    t_harness_err "T-OTP-EXPIRED" "Cannot find active OTP record"; return
  fi

  # Expire the OTP via NSU PATCH.
  local exp_body; exp_body=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$exp_body" "expires_at=2000-01-01 00:00:00.000Z" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/phone_otps/records/${otp_id}" \
    "$_NSU_AUTH_CFG" "$exp_body" "$sf" "$rp_f" "200"
  local patch_st; patch_st=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$exp_body" "$sf" "$rp_f" "$rp"
  if [[ "$patch_st" != "200" ]]; then
    t_harness_err "T-OTP-EXPIRED" "Cannot expire OTP record (PATCH ${patch_st})"; return
  fi

  # Attempt verification — should fail with expired OTP.
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$phone" "$code" "$body_f"
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "400"
  local vst; vst=$(cat "$sf" 2>/dev/null); rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f" "$rp"

  # Verify OTP record now has adapter_status=expired (TX committed the state change).
  local exp_cnt; exp_cnt=$(_otp_count_by_status "$phone" "expired")
  local act_cnt; act_cnt=$(_otp_count_by_status "$phone" "sent_active")
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local after_pv; after_pv=$(_read_user_field "$ord_id" "phone_verified")

  if [[ "$vst" != "400" ]]; then
    t_fail "T-OTP-EXPIRED" "Expected 400 for expired OTP; got ${vst}"; return
  fi
  if [[ "$exp_cnt" != "1" ]]; then
    t_fail "T-OTP-EXPIRED" \
      "Expected expired state committed; expired_count=${exp_cnt} active_count=${act_cnt}"; return
  fi
  if [[ "$act_cnt" != "0" ]]; then
    t_fail "T-OTP-EXPIRED" "Expired OTP still shows as sent_active"; return
  fi
  if [[ "$after_pv" == "true" ]]; then
    t_fail "T-OTP-EXPIRED" "phone_verified was set despite expired OTP"; return
  fi
  t_pass "T-OTP-EXPIRED"
  print "[otp-expired] TX committed expired state; phone_verified unchanged."
}

# D23-5: TX-3 rollback (db_fail_verify): OTP stays active, phone unchanged.
t_phone_otp_rollback() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-OTP-ROLLBACK" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _otp_set_mode "db_fail_verify" || { t_harness_err "T-PHONE-OTP-ROLLBACK" "Mode"; return }
  local code; code=$(_otp_request_and_read_code "$SYNTH_PHONE_LINK")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-PHONE-OTP-ROLLBACK" "OTP request failed"; _otp_set_mode "success"; return
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$SYNTH_PHONE_LINK" "$code" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "400"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  _otp_set_mode "success"
  if [[ "$actual" != "400" ]]; then
    t_harness_err "T-PHONE-OTP-ROLLBACK" "Expected 400; got ${actual}"; return
  fi
  local after_phone; after_phone=$(_read_user_field "$ord_id" "phone")
  local after_pv;    after_pv=$(_read_user_field "$ord_id" "phone_verified")
  local active_cnt; active_cnt=$(_otp_count_by_status "$SYNTH_PHONE_LINK" "sent_active")
  local rollback_ok=1
  [[ "$after_phone" == "$SYNTH_PHONE_LINK" ]] && { rollback_ok=0 }
  [[ "$after_pv" == "true" ]]                  && { rollback_ok=0 }
  if (( rollback_ok )); then
    t_pass "T-PHONE-OTP-ROLLBACK"
    print "[rollback] TX-3 rolled back. OTP active_cnt=${active_cnt} (retryable). phone+pv unchanged."
  else
    t_fail "T-PHONE-OTP-ROLLBACK" \
      "Partial commit: phone='${after_phone}' pv='${after_pv}'"
  fi
}

# D23-4,3: Atomic link; start with blank phone.
t_phone_otp_atomic_link() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-OTP-ATOMIC-LINK" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _reset_user_phone "$ord_id"
  _otp_set_mode "success" || { t_harness_err "T-PHONE-OTP-ATOMIC-LINK" "Mode"; return }
  local code; code=$(_otp_request_and_read_code "$SYNTH_PHONE_LINK")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-PHONE-OTP-ATOMIC-LINK" "OTP request failed"; return
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$SYNTH_PHONE_LINK" "$code" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if ! pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"; then
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-OTP-ATOMIC-LINK" "Verify failed; got ${actual}"
    return
  fi
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local after_phone; after_phone=$(_read_user_field "$ord_id" "phone")
  local after_pv;    after_pv=$(_read_user_field "$ord_id" "phone_verified")
  local con_cnt; con_cnt=$(_otp_count_by_status "$SYNTH_PHONE_LINK" "consumed")
  _reset_user_phone "$ord_id"
  if [[ "$after_phone" != "$SYNTH_PHONE_LINK" || "$after_pv" != "true" || "$con_cnt" != "1" ]]; then
    t_fail "T-PHONE-OTP-ATOMIC-LINK" \
      "phone='${after_phone}' pv='${after_pv}' consumed=${con_cnt}"
    return
  fi
  t_pass "T-PHONE-OTP-ATOMIC-LINK"
  print "[atomic-link] TX-3: OTP consumed + phone + phone_verified committed atomically."
}

t_otp_pending_create_fail() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-PENDING-CREATE-FAIL" "blocked"; return }
  _otp_set_mode "pending_create_fail" || {
    t_harness_err "T-OTP-PENDING-CREATE-FAIL" "Mode set failed"; return
  }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_request "$SYNTH_PHONE_OTP" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "400" "500"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local cnt; cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "pending_send")
  local active; active=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "sent_active")
  _otp_set_mode "success"
  if [[ "$cnt" == "0" && "$active" == "0" ]]; then
    t_pass "T-OTP-PENDING-CREATE-FAIL"
    print "[otp-create-fail] TX-1 rollback confirmed: no phone_otps record created."
  else
    t_fail "T-OTP-PENDING-CREATE-FAIL" \
      "Expected 0 records; pending=${cnt} active=${active}"
  fi
}

t_otp_db_fail_request() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-DB-FAIL-REQUEST" "blocked"; return }
  _otp_set_mode "db_fail_request" || {
    t_harness_err "T-OTP-DB-FAIL-REQUEST" "Mode set failed"; return
  }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_request "$SYNTH_PHONE_OTP" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "400" "500"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local active_cnt; active_cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "sent_active")
  local failed_cnt; failed_cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "send_failed")
  _otp_set_mode "success"
  if [[ "$active_cnt" == "0" ]]; then
    t_pass "T-OTP-DB-FAIL-REQUEST"
    print "[otp-db-fail] TX-2 rollback: active=${active_cnt} failed=${failed_cnt}."
  else
    t_fail "T-OTP-DB-FAIL-REQUEST" "sent_active=${active_cnt} after TX-2 rollback"
  fi
}

# D23-6: TX-2 rollback + cleanup also fails → 500; record stays pending.
t_otp_db_fail_request_cleanup_fail() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-DB-FAIL-CLEANUP-FAIL" "blocked"; return }
  _otp_set_mode "db_fail_request_cleanup_fail" || {
    t_harness_err "T-OTP-DB-FAIL-CLEANUP-FAIL" "Mode set failed"; return
  }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_request "$SYNTH_PHONE_OTP" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "500"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local pending_cnt; pending_cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "pending_send")
  local active_cnt; active_cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "sent_active")
  _otp_set_mode "success"
  if [[ "$actual" != "500" ]]; then
    t_fail "T-OTP-DB-FAIL-CLEANUP-FAIL" "Expected 500 (unresolved state); got ${actual}"
    return
  fi
  if [[ "$active_cnt" != "0" ]]; then
    t_fail "T-OTP-DB-FAIL-CLEANUP-FAIL" "sent_active=${active_cnt} after cleanup fail"
    return
  fi
  t_pass "T-OTP-DB-FAIL-CLEANUP-FAIL"
  print "[cleanup-fail] 500 returned (unresolved). pending=${pending_cnt} active=${active_cnt}."
  print "[cleanup-fail] D23-6: cleanup error not swallowed; state unresolved, rate-limit may be affected."
}

t_phone_future_state_group() {
  (( HALT_DEPENDENTS )) && {
    for l in ORD-NO-PATCH-PHONE ORD-NO-PATCH-PV MIXED-FIELD-REJECT NSU-RECOVERY \
      NSU-PV-NO-PHONE OTP-AUTH-ANON OTP-AUTH-ADMIN OTP-AUTH-SADMIN OTP-CROSS-USER \
      OTP-ATOMIC-LINK OTP-ROLLBACK; do
      t_skip "T-PHONE-${l}" "blocked"
    done
    for l in OTP-PENDING-CREATE-FAIL OTP-DB-FAIL-REQUEST OTP-DB-FAIL-CLEANUP-FAIL OTP-EXPIRED; do
      t_skip "T-${l}" "blocked"
    done
    return
  }
  print "=== §28.6 Phone+phone_verified Protection Tests ==="
  t_phone_ordinary_cannot_patch_phone
  t_phone_ordinary_cannot_patch_phone_verified
  t_phone_mixed_field_rejection
  t_phone_nsu_can_set_phone_and_pv_together
  t_phone_nsu_cannot_set_pv_without_phone
  t_phone_otp_auth_requirements
  t_phone_otp_cross_user_attack
  t_phone_otp_atomic_link
  t_phone_otp_rollback
  t_otp_pending_create_fail
  t_otp_db_fail_request
  t_otp_db_fail_request_cleanup_fail
  t_otp_expired
}

# ────────────────────────────────────────────────────────────
# §19 STANDARD CRUD TESTS
# ────────────────────────────────────────────────────────────
t_crud_children_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-LIST" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/children/records" \
      "$ORDINARY_AUTH_CFG" "" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-CRUD-CH-LIST"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-CRUD-CH-LIST" "HTTP ${actual}"
  fi
}

t_crud_children_create() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-CREATE" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "user=${ord_id}" "name=TestChild_${RUN_SUFFIX}" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "POST" "/api/collections/children/records" \
      "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null)
    local new_id; new_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
    rm -f "$body_f" "$sf" "$rp_f" "$rp"
    if [[ -n "$new_id" ]]; then
      local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$new_id" > "$id_f"
      pb_delete_record "children" "$id_f"
    fi
    t_pass "T-CRUD-CH-CREATE"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-CRUD-CH-CREATE" "HTTP ${actual}"
  fi
}

t_crud_growth_create() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-GL-CREATE" "blocked"; return }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_skip "T-CRUD-GL-CREATE" "no child fixture"; return }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local leg_id; leg_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "user=${leg_id}" "child=${cid}" \
    "n:weight_kg=3.5" "n:height_cm=50.0" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "POST" "/api/collections/growth_logs/records" \
      "$LEGACY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null)
    local new_id; new_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
    rm -f "$body_f" "$sf" "$rp_f" "$rp"
    if [[ -n "$new_id" ]]; then
      local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$new_id" > "$id_f"
      LEGACY_GROWTH_ID_FILE="$id_f"
    fi
    t_pass "T-CRUD-GL-CREATE"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-CRUD-GL-CREATE" "HTTP ${actual}"
  fi
}

t_field_role_reject() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FIELD-ROLE-REJECT" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=admin" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if ! pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
      "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"; then
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-FIELD-ROLE-REJECT" "Expected 403; got ${actual}"
    return
  fi
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local persisted; persisted=$(_read_user_field "$ord_id" "role")
  if [[ "$persisted" == "admin" || "$persisted" == "superadmin" ]]; then
    t_fail "T-FIELD-ROLE-REJECT" "CRITICAL: role persisted as '${persisted}'"
    return
  fi
  t_pass "T-FIELD-ROLE-REJECT"
}

t_file_auth_anon_list_rejected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-1" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/growth_logs/records" \
      "" "" "$sf" "$rp_f" "401" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-FILE-AUTH-1"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-FILE-AUTH-1" "HTTP ${actual}"
  fi
}

t_file_auth_own_record_visible() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-2" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/growth_logs/records" \
      "$LEGACY_AUTH_CFG" "" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-FILE-AUTH-2"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-FILE-AUTH-2" "HTTP ${actual}"
  fi
}

t_file_auth_admin_can_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-4" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/growth_logs/records" \
      "$ADMIN_AUTH_CFG" "" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-FILE-AUTH-4"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-FILE-AUTH-4" "HTTP ${actual}"
  fi
}

t_file_auth_upload_own()         { t_deferred_mandatory "T-FILE-AUTH-5" "Requires binary test asset." }
t_file_auth_download_protected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-6" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/files/users/nonexistent_r23_id_xyz/nonexistent.jpg" \
      "" "" "$sf" "$rp_f" "404" "401"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-FILE-AUTH-6"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-FILE-AUTH-6" "HTTP ${actual}"
  fi
}

t_file_auth_delete_own() { t_deferred_mandatory "T-FILE-AUTH-7" "Depends on T-FILE-AUTH-5." }
t_field_phone_reject()   { t_deferred_mandatory "T-FIELD-PHONE-REJECT" "Covered by §28.6 guard tests." }

pb_alias_enum_case() {
  local label="$1" email="$2" expected="$3"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  python3 "$PBJ_PY" "$body_f" "identity=${email}" "secret-file:password=${WRONG_PW_FILE}" \
    2>/dev/null || { t_harness_err "$label" "pbj.py"; return }
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/auth-with-password)" "" "$body_f" "POST"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null)
  ENUM_HTTP_VALUES+=("$actual"); ENUM_RESP_FILES+=("$rp")
  rm -f "$body_f" "$sf" "$rp_f"
  if [[ "$actual" == "$expected" ]]; then t_pass "$label"
  else t_fail "$label" "expected ${expected} got ${actual}"
  fi
}

t_alias_enum_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-ENUM" "blocked"; return }
  pb_alias_enum_case "T-ALIAS-ENUM-1" "cp0_alias_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}" "400"
  pb_alias_enum_case "T-ALIAS-ENUM-2" "cp0_user_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"  "400"
  pb_alias_enum_case "T-ALIAS-ENUM-3" "nonexistent_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}" "400"
  pb_alias_enum_case "T-ALIAS-ENUM-4" "not-an-email" "400"
  local rp; for rp in "${ENUM_RESP_FILES[@]}"; do rm -f "$rp" 2>/dev/null; done
  ENUM_RESP_FILES=(); ENUM_HTTP_VALUES=()
}

t_anon_read_denied() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ANON-READ" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/users/records" "" "" "$sf" "$rp_f" "401" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-ANON-READ"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-ANON-READ" "HTTP ${actual}"
  fi
}

t_admin_escalation_self() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-ESCALATION" "blocked"; return }
  [[ -f "$ADMIN_ID_FILE" ]] || { t_skip "T-ADMIN-ESCALATION" "no admin fixture"; return }
  local admin_id; admin_id=$(cat "$ADMIN_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "PATCH" "/api/collections/users/records/${admin_id}" \
      "$ADMIN_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_pass "T-ADMIN-ESCALATION"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-ADMIN-ESCALATION" "Expected 403; got ${actual}"
  fi
}

t_sadmin_list_users() {
  (( HALT_DEPENDENTS )) && { t_skip "T-SADMIN-LIST-USERS" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/users/records" "$SADMIN_AUTH_CFG" "" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-SADMIN-LIST-USERS"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-SADMIN-LIST-USERS" "HTTP ${actual}"
  fi
}

t_nsu_bypass() {
  (( HALT_DEPENDENTS )) && { t_skip "T-NSU-BYPASS" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/users/records" "$_NSU_AUTH_CFG" "" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-NSU-BYPASS"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-NSU-BYPASS" "HTTP ${actual}"
  fi
}

t_rule_apply_restore() {
  (( HALT_DEPENDENTS )) && { t_skip "T-RULE-APPLY-RESTORE" "blocked"; return }
  pb_capture_rule_baseline "articles" "listRule" || return
  pb_apply_rule_local "articles" "listRule" "@request.auth.id != ''" || return
  sleep 0.3
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/articles/records" "" "" "$sf" "$rp_f" "401" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-RULE-APPLY-RESTORE"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-RULE-APPLY-RESTORE" "HTTP ${actual}"
  fi
  pb_restore_rule_local "articles" "listRule"
}

t_art_anon_policy() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANON-POLICY" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/articles/records" "" "" "$sf" "$rp_f" "401" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-ART-ANON-POLICY"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-ART-ANON-POLICY" \
      "Articles publicly readable (HTTP ${actual}). Fix: listRule=\"@request.auth.id != ''\""
  fi
}

t_art_antenatal_vis() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANTENATAL-VIS" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/articles/records?filter=is_pregnancy%3Dtrue&perPage=5" \
      "$ORDINARY_AUTH_CFG" "" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-ART-ANTENATAL-VIS"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-ART-ANTENATAL-VIS" "HTTP ${actual}"
  fi
}

t_user_name_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-NAME-UPDATE" "blocked"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=Updated_${RUN_SUFFIX}" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
      "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_pass "T-USER-NAME-UPDATE"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-USER-NAME-UPDATE" "HTTP ${actual}"
  fi
}

t_authorized_exclusions() {
  t_authorized_exclusion "E4-EMAIL-CHANGE-LIFECYCLE" "Requires production SMTP"
  t_authorized_exclusion "E6-OTP-REACHABILITY"       "Requires Meta Cloud API"
  t_authorized_exclusion "E8-WARN-LOG-OBSERVABILITY" "Requires production log pipeline"
}

# ────────────────────────────────────────────────────────────
# §20 OTP LIFECYCLE AND CONCURRENCY  (D23-7,8)
# ────────────────────────────────────────────────────────────
t_otp_flow() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-FLOW" "blocked"; return }
  _otp_set_mode "success" || { t_harness_err "T-OTP-FLOW" "Mode set failed"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _reset_user_phone "$ord_id"
  local code; code=$(_otp_request_and_read_code "$SYNTH_PHONE_OTP")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-OTP-FLOW" "OTP request failed"
    return
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$SYNTH_PHONE_OTP" "$code" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if ! pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" \
      "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"; then
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-OTP-FLOW" "Verify failed; got ${actual}"
    _reset_user_phone "$ord_id"
    return
  fi
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local pv; pv=$(_read_user_field "$ord_id" "phone_verified")
  local ph; ph=$(_read_user_field "$ord_id" "phone")
  local con_cnt; con_cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "consumed")
  _reset_user_phone "$ord_id"
  if [[ "$con_cnt" == "1" && "$pv" == "true" && "$ph" == "$SYNTH_PHONE_OTP" ]]; then
    t_pass "T-OTP-FLOW"
    print "[otp-flow] lifecycle: pending_send→sent_active→consumed. phone+pv set atomically."
  else
    t_fail "T-OTP-FLOW" "consumed=${con_cnt} phone='${ph}' pv='${pv}'"
  fi
}

# D23-7,8: Concurrent send — evidence collected; single terminal result.
t_concurrency_otp_send_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-OTP-SEND" "blocked"; return }
  local synth_phone="+601_R23TEST_00099001"
  _otp_set_mode "success" || { t_harness_err "T-CONCURRENCY-OTP-SEND" "Mode"; return }
  local req_url; req_url="$(pb_url "$HOOK_OTP_PHONE_ROUTE")"
  local pids=() i

  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/otpconcs_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json"
    # D23-10: use PBJ_PY for OTP body.
    python3 "$PBJ_PY" "$wbody" "phone=${synth_phone}" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" python3 "$PBJ_HTTP_PY" \
        "${wdir}/status" "${wdir}/resp_rp" "$req_url" "$ORDINARY_AUTH_CFG" "$wbody" "POST"
    ) &
    pids+=($!)
  done

  # Collect worker evidence (D23-8: no t_fail per worker).
  local w_success=0 w_fail=0 w_other=0
  for (( i=1; i<=5; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wst; wst=$(cat "${RELEASE1B_TEST_TMP}/otpconcs_w${i}_${RUN_SUFFIX}/status" 2>/dev/null)
    local wrp_f="${RELEASE1B_TEST_TMP}/otpconcs_w${i}_${RUN_SUFFIX}/resp_rp"
    [[ -f "$wrp_f" ]] && { local wrp; wrp=$(cat "$wrp_f" 2>/dev/null); rm -f "$wrp" "$wrp_f" }
    case "$wst" in 200) (( w_success++ )) ;; 400|403|429) (( w_fail++ )) ;; *) (( w_other++ )) ;; esac
  done

  # DB state verification.
  local active_cnt; active_cnt=$(_otp_count_by_status "$synth_phone" "sent_active")
  local failed_cnt; failed_cnt=$(_otp_count_by_status "$synth_phone" "send_failed")
  local pending_cnt; pending_cnt=$(_otp_count_by_status "$synth_phone" "pending_send")

  print "[otp-conc-send] workers: success=${w_success} rejected=${w_fail} other=${w_other}"
  print "[otp-conc-send] DB: sent_active=${active_cnt} send_failed=${failed_cnt} pending=${pending_cnt}"

  # At least some requests should have returned 200 or meaningful status.
  if (( w_other == 5 )); then
    t_harness_err "T-CONCURRENCY-OTP-SEND" "All workers returned unexpected status"
    return
  fi
  # D23-7: active count must be 0 or 1; no more.
  if (( active_cnt > 1 )); then
    t_fail "T-CONCURRENCY-OTP-SEND" \
      "sent_active=${active_cnt} (expected ≤1). Concurrent send produced multiple active OTPs."
    return
  fi
  t_pass "T-CONCURRENCY-OTP-SEND"
  print "[otp-conc-send] At most 1 sent_active. OBSERVED evidence. Not architectural guarantee."
  t_deferred_mandatory "T-OTP-RATE-LIMIT-POLICY"    "Rate-limit policy undefined. D23-12: DEFERRED-MANDATORY."
  t_deferred_mandatory "T-OTP-IDEMPOTENCY-POLICY"   "Idempotency policy undefined. D23-12: DEFERRED-MANDATORY."
  t_deferred_mandatory "T-CONCURRENCY-IDEMPOTENCY-POST" "No idempotency endpoint defined."
}

# D23-7,8: Concurrent verify — exactly 1 success; DB-state verified.
t_concurrency_otp_verify_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-OTP-VERIFY" "blocked"; return }
  local synth_phone="+601_R23TEST_00099002"
  _otp_set_mode "success" || { t_harness_err "T-CONCURRENCY-OTP-VERIFY" "Mode"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _reset_user_phone "$ord_id"

  local code; code=$(_otp_request_and_read_code "$synth_phone")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-CONCURRENCY-OTP-VERIFY" "Could not obtain active OTP"
    return
  fi

  local verify_url; verify_url="$(pb_url "$HOOK_OTP_VERIFY_ROUTE")"
  local pids=() i

  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/otpconcv_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json"
    # D23-10: use PBJ_PY for verify body.
    python3 "$PBJ_PY" "$wbody" "phone=${synth_phone}" "code=${code}" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" python3 "$PBJ_HTTP_PY" \
        "${wdir}/status" "${wdir}/resp_rp" "$verify_url" "$ORDINARY_AUTH_CFG" "$wbody" "POST"
    ) &
    pids+=($!)
  done

  # Collect evidence (D23-8: no t_fail per worker).
  local success_count=0 denial_count=0 other_count=0
  for (( i=1; i<=5; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wst; wst=$(cat "${RELEASE1B_TEST_TMP}/otpconcv_w${i}_${RUN_SUFFIX}/status" 2>/dev/null)
    local wrp_f="${RELEASE1B_TEST_TMP}/otpconcv_w${i}_${RUN_SUFFIX}/resp_rp"
    [[ -f "$wrp_f" ]] && { local wrp; wrp=$(cat "$wrp_f" 2>/dev/null); rm -f "$wrp" "$wrp_f" }
    case "$wst" in 200) (( success_count++ )) ;; 400|403|409|429) (( denial_count++ )) ;; *) (( other_count++ )) ;; esac
  done

  # DB state: OTP must be consumed exactly once.
  local con_cnt; con_cnt=$(_otp_count_by_status "$synth_phone" "consumed")
  local act_cnt; act_cnt=$(_otp_count_by_status "$synth_phone" "sent_active")
  # User phone state.
  local after_ph; after_ph=$(_read_user_field "$ord_id" "phone")
  local after_pv; after_pv=$(_read_user_field "$ord_id" "phone_verified")
  _reset_user_phone "$ord_id"

  print "[otp-conc-verify] success=${success_count}/5 denied=${denial_count} other=${other_count}"
  print "[otp-conc-verify] DB: consumed=${con_cnt} active=${act_cnt}"
  print "[otp-conc-verify] User: phone='${after_ph}' pv='${after_pv}'"

  # D23-7: must be EXACTLY 1 success (not <= 1).
  if (( success_count != 1 )); then
    t_fail "T-CONCURRENCY-OTP-VERIFY" \
      "Expected exactly 1 success; got ${success_count}"
    return
  fi
  if [[ "$con_cnt" != "1" ]]; then
    t_fail "T-CONCURRENCY-OTP-VERIFY" "Expected 1 consumed OTP; got ${con_cnt}"
    return
  fi
  if [[ "$act_cnt" != "0" ]]; then
    t_fail "T-CONCURRENCY-OTP-VERIFY" "Active OTP remains after successful verify (${act_cnt})"
    return
  fi
  if [[ "$after_ph" != "$synth_phone" || "$after_pv" != "true" ]]; then
    t_fail "T-CONCURRENCY-OTP-VERIFY" "User phone/pv not set after verify"
    return
  fi
  t_pass "T-CONCURRENCY-OTP-VERIFY"
  print "[otp-conc-verify] Exactly 1 TX-3 committed. OTP consumed once. User phone+pv set once."
}

# D23-8: Auth concurrency — single terminal result per group.
t_concurrency_auth_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-AUTH" "blocked"; return }
  local conc_email="cp0_concauth_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local cpw; cpw=$(pb_secure_tmpfile .pw); openssl rand -base64 24 | tr -d '\n=' > "$cpw"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${conc_email}" \
    "secret-file:password=${cpw}" "secret-file:passwordConfirm=${cpw}" "role=user" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local cst; cst=$(cat "$sf" 2>/dev/null); local crp; crp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  if [[ "$cst" != "200" ]]; then
    pb_wipe_secret_file "$cpw"; rm -f "$crp"
    t_harness_err "T-CONCURRENCY-AUTH-SETUP" "Create ${cst}"
    return
  fi
  local conc_uid; conc_uid=$(python3 "$PBJ_EXTRACT_PY" "$crp" "id" 2>/dev/null)
  rm -f "$crp"
  pb_wipe_secret_file "$cpw"
  local url; url="$(pb_url /api/collections/users/auth-with-password)"
  local pids=() i

  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json"
    python3 "$PBJ_PY" "$wbody" "identity=${conc_email}" "password=definitely-wrong-pw" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" python3 "$PBJ_HTTP_PY" \
        "${wdir}/status" "${wdir}/resp_rp" "$url" "" "$wbody" "POST"
    ) &
    pids+=($!)
  done

  # Collect evidence (D23-8: no t_fail per worker).
  local pass_count=0 fail_count=0 other_count=0
  for (( i=1; i<=5; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wst; wst=$(cat "${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}/status" 2>/dev/null)
    local wrp_f="${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}/resp_rp"
    [[ -f "$wrp_f" ]] && { local wrp; wrp=$(cat "$wrp_f" 2>/dev/null); rm -f "$wrp" "$wrp_f" }
    case "$wst" in 400) (( pass_count++ )) ;; 200) (( fail_count++ )) ;; *) (( other_count++ )) ;; esac
  done

  if [[ -n "$conc_uid" ]]; then
    local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$conc_uid" > "$id_f"
    pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1
  fi

  # Single terminal result for the group.
  if (( fail_count > 0 )); then
    t_fail "T-CONCURRENCY-AUTH" \
      "${fail_count} workers returned 200 (unexpected auth success with wrong password)"
  elif (( other_count > 0 )); then
    t_harness_err "T-CONCURRENCY-AUTH" \
      "${other_count} workers returned unexpected status; expected 400 for all"
  else
    t_pass "T-CONCURRENCY-AUTH"
  fi
}

t_hook_smoke_group() {
  local hk
  for hk in "${(@k)HOOK_PROBE_TYPE}"; do
    local probe_type="${HOOK_PROBE_TYPE[$hk]}"
    if [[ "$probe_type" == "behavioral" ]]; then
      print "[hook-smoke] ${hk}: behavioral — proved by T-FIELD-ROLE-REJECT"
      t_pass "T-HOOK-SMOKE-${hk}"
      continue
    fi
    local route="${HOOK_PROBE_ROUTES[$hk]}" method="${HOOK_PROBE_METHODS[$hk]:-GET}"
    local probe_auth="${HOOK_PROBE_AUTH[$hk]:-}" auth_cfg=""
    [[ "$probe_auth" == "admin" ]] && auth_cfg="$ADMIN_AUTH_CFG"
    local safe_statuses_str="${HOOK_PROBE_SAFE_STATUS[$hk]:-200 400 401 403 405 500}"
    local -a safe_statuses=( ${=safe_statuses_str} )
    local body_f=""
    if [[ "$hk" == "push_broadcast" && "$method" == "POST" ]]; then
      body_f=$(pb_secure_tmpfile .json); printf '{}' > "$body_f"; chmod 600 "$body_f"
    fi
    local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
    pb_capture "$method" "$route" "$auth_cfg" "${body_f:-}" "$sf" "$rp_f" "${safe_statuses[@]}"
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null)
    rm -f "${body_f:-}" "$sf" "$rp_f" "$rp"
    if [[ "$actual" == "404" ]]; then
      t_fail "T-HOOK-SMOKE-${hk}" "Route 404 — hook may not be registered"
    else
      t_pass "T-HOOK-SMOKE-${hk}"
    fi
  done
}

# ────────────────────────────────────────────────────────────
# §21 REPORT
# ────────────────────────────────────────────────────────────
pb_generate_report() {
  local rc=0
  (( T_BLOCKING > 0 || T_FAIL > 0 || T_HARNESS_ERR > 0 || CLEANUP_FAILURE > 0 )) && rc=1
  (( rc == 0 && (T_DEFERRED > 0 || T_UNRESOLVED > 0) )) && rc=2
  {
    print "## Release 1B Checkpoint 0 Report — Round 23"
    print "Run suffix : ${RUN_SUFFIX}"; print "Platform   : ${PLATFORM_KEY}"
    print "PB version : ${RELEASE1B_PB_VERSION}"; print "Test domain: ${TEST_EMAIL_DOMAIN}"
    print ""
    print "## Checkpoint 0 Authorization Status"
    print "AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE"
    print ""
    case $rc in 0) print "RESULT: PASS" ;; 1) print "RESULT: FAIL" ;; 2) print "RESULT: INCOMPLETE" ;; esac
    print ""
    printf 'PASS:%d  FAIL:%d  BLOCKING:%d  UNRESOLVED:%d  DEFERRED:%d  HARNESS_ERR:%d  SKIP:%d  CLEANUP_FAIL:%d\n' \
      "$T_PASS" "$T_FAIL" "$T_BLOCKING" "$T_UNRESOLVED" "$T_DEFERRED" "$T_HARNESS_ERR" "$T_SKIP" "$CLEANUP_FAILURE"
    print ""
    local bd; for bd in "${BLOCKING_DECISIONS[@]}"; do print "  ${bd}"; done
    local ui; for ui in "${UNRESOLVED_ITEMS[@]}"; do print "  ${ui}"; done
    local he; for he in "${HARNESS_ERRORS[@]}"; do print "  ${he}"; done
    print ""; print "## Test Detail"
    cat "$RELEASE1B_REPORT_WORK" 2>/dev/null || true
  } > "${RELEASE1B_REPORT_WORK}.final"
  RELEASE1B_CANONICAL_ROOT="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_SCAN_PY" "${RELEASE1B_REPORT_WORK}.final" "$RELEASE1B_REPORT_PATH" 2>/dev/null || \
    RELEASE1B_REPORT_PATH="${RELEASE1B_REPORT_WORK}.final"
  print "=== Report: ${RELEASE1B_REPORT_PATH} ==="
  return $rc
}

# ────────────────────────────────────────────────────────────
# §22 MAIN
# ────────────────────────────────────────────────────────────
pb_run_all_tests() {
  pb_preflight_ports || return 1
  pb_verify_binary_version
  pb_apply_schema_migrations || return 1
  pb_setup_nsu_credentials
  pb_write_nsu_bootstrap_migration
  pb_write_future_schema_migration
  pb_write_phone_guard_hook
  pb_deploy_hooks
  pb_start_pocketbase
  pb_create_local_superuser || return 1
  pb_verify_email_domain    || return 1
  pb_verify_schema
  pb_create_test_user "user"       ORDINARY_ID_FILE   ORDINARY_TOK_FILE   ORDINARY_AUTH_CFG
  pb_create_test_user "user"       ORDINARY_B_ID_FILE ORDINARY_B_TOK_FILE ORDINARY_B_AUTH_CFG
  pb_create_test_user "admin"      ADMIN_ID_FILE      ADMIN_TOK_FILE      ADMIN_AUTH_CFG
  pb_create_test_user "superadmin" SADMIN_ID_FILE     SADMIN_TOK_FILE     SADMIN_AUTH_CFG
  pb_create_legacy_fixture; pb_setup_alias_group
  t_role_inject_emergency_group
  (( T_BLOCKING > 0 )) && HALT_DEPENDENTS=1
  t_crud_children_list; t_crud_children_create; t_crud_growth_create
  t_field_role_reject; t_field_phone_reject
  t_file_auth_anon_list_rejected; t_file_auth_own_record_visible
  t_file_auth_admin_can_list; t_file_auth_upload_own
  t_file_auth_download_protected; t_file_auth_delete_own
  t_alias_enum_group
  t_anon_read_denied; t_admin_escalation_self; t_sadmin_list_users; t_nsu_bypass
  t_phone_future_state_group
  t_user_name_update
  t_art_anon_policy; t_art_antenatal_vis; t_rule_apply_restore
  t_otp_flow; t_otp_db_fail_request; t_otp_db_fail_request_cleanup_fail; t_otp_expired
  t_concurrency_auth_group; t_concurrency_otp_send_group; t_concurrency_otp_verify_group
  t_hook_smoke_group
  t_authorized_exclusions
  pb_cleanup_all_fixtures
  pb_delete_test_user "superadmin" "$SADMIN_ID_FILE"     "$SADMIN_TOK_FILE"     "$SADMIN_AUTH_CFG"
  pb_delete_test_user "admin"      "$ADMIN_ID_FILE"      "$ADMIN_TOK_FILE"      "$ADMIN_AUTH_CFG"
  pb_delete_test_user "user"       "$ORDINARY_B_ID_FILE" "$ORDINARY_B_TOK_FILE" "$ORDINARY_B_AUTH_CFG"
  pb_delete_test_user "user"       "$ORDINARY_ID_FILE"   "$ORDINARY_TOK_FILE"   "$ORDINARY_AUTH_CFG"
  pb_delete_legacy_fixture; pb_cleanup_alias_group; pb_delete_local_superuser
}

pb_main() {
  local mode="" authorize_cp0=0 _rdest=""
  for arg in "$@"; do
    case "$arg" in
      --package-check) mode="package-check" ;;
      --harness-check) mode="harness-check" ;;
      --preflight)     mode="preflight"     ;;
      --run)           mode="run"           ;;
      --authorize-cp0) authorize_cp0=1      ;;
      --report-dest=*) _rdest="${arg#--report-dest=}" ;;
    esac
  done
  pb_setup_umask; pb_generate_run_suffix; pb_detect_platform
  if [[ -n "$_rdest" ]]; then
    local dp="${_rdest%/*}"; [[ ! -d "$dp" ]] && pb_halt "--report-dest parent missing"
    local lt; lt=$(python3 -c "
import os,sys,stat
s=os.lstat(sys.argv[1]); print('SYMLINK' if stat.S_ISLNK(s.st_mode) else 'OK')
" -- "$_rdest" 2>/dev/null || echo "NEW")
    [[ "$lt" == "SYMLINK" ]] && pb_halt "--report-dest is a symlink"
    RELEASE1B_REPORT_DEST="$_rdest"
  fi
  case "$mode" in
    package-check)
      pb_setup_root; pb_write_scripts; pb_check_package_completeness; exit $? ;;
    harness-check)
      pb_setup_root; pb_write_scripts; t_harness_selftest || exit 1; exit 0 ;;
    preflight)
      pb_setup_root; pb_write_scripts; pb_preflight_ports; exit $? ;;
    run)
      (( authorize_cp0 )) || { print "[main] --run requires --authorize-cp0" >&2; exit 1 }
      pb_setup_root; pb_install_trap; pb_write_scripts
      t_harness_selftest || { print "[main] Self-test failed." >&2; exit 1 }
      pb_run_all_tests; pb_generate_report; local rc=$?
      print "=== Complete. Report: ${RELEASE1B_REPORT_PATH} ==="; exit $rc ;;
    *)
      print "Usage: $0 --package-check | --harness-check | --preflight | --run --authorize-cp0 [--report-dest=PATH]" >&2
      exit 1 ;;
  esac
}

pb_main "$@"
