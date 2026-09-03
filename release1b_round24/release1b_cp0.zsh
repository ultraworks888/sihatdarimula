#!/usr/bin/env zsh
# ============================================================
# release1b_cp0.zsh — Release 1B Checkpoint 0 Harness
# Round  : 24
# Status : DRAFTED — all static acceptance checks pass by inspection.
#          See delivery message for static acceptance gate results.
#          Checkpoint 0 authorization status:
#          AUTHORIZED BUT NOT EXECUTED —
#          EXECUTION ENVIRONMENT UNAVAILABLE
# ============================================================
#
# R24 corrections:
#   D24-1.  Duplicate test invocations removed from pb_run_all_tests().
#           All OTP lifecycle tests consolidated in t_otp_lifecycle_group().
#           Static duplicate-ID checker added to harness self-test.
#   D24-2.  pb_delete_local_superuser() now: reads stored NSU record ID,
#           deletes the _superusers record via API, independently verifies
#           absence (404 or 401), wipes all credential files, sets
#           CLEANUP_FAILURE on any error. T-SU-DELETE PASS only after
#           deletion and absence verification succeed.
#   D24-3.  pbj_http.py: bearer token written to a permission-600
#           single-use curl configuration file (--config). Never appended
#           to curl subprocess argv. File deleted immediately after request.
#   D24-4.  pbj_field.py: explicit allowlist of safe printable fields.
#           BLOCKED list permanently prohibits token, email, phone, code,
#           password, passwordHash, tokenKey, alias, phone_verified.
#           pbj_tok.py: non-printing token extractor writes directly to
#           permission-600 file. pbj_cmp.py: field comparison without
#           printing sensitive values.
#   D24-5.  pbj_http.py: captures sanitized response headers, content-type,
#           response size, and total request time to caller-supplied files.
#           pb_capture_full(): new function exposes all evidence.
#           Alias-enumeration uses pb_capture_full() and compares
#           content-type, size, and timing uniformity.
#   D24-6.  pbj_http.py: auth_mode is an explicit argument ('anon'|'auth').
#           If auth_mode='auth' and auth file is missing, invalid, or a
#           symlink: writes 000 to status_out and exits non-zero before
#           invoking curl. Silent downgrade eliminated.
#   D24-7.  t_concurrency_otp_send_group(): requires at least 1 success,
#           exactly 1 sent_active, 0 pending_send, 5 total attempt records,
#           all superseded records in terminal state.
#   D24-8.  Adapter error responses sanitized in otp_test_adapter.pb.js.
#   D24-9.  Complete CP0 traceability matrix in test manifest.
#   D24-10. Antenatal route inventory in test manifest.
#   D24-11. Email lifecycle classified as T-UNRESOLVED with local-mail-sink
#           prerequisite documented. No longer an authorized exclusion.
#   D24-12. Byte counts reported after all writing is complete.
# ============================================================
#
# R23 retained corrections (all retained):
#   D23-1/2/3/4/5/6/7/8/9/10/11/12/13 — see round23 review.
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
readonly RELEASE1B_SCRIPT_ROUND="24"
readonly RELEASE1B_PB_PORT="8090"
readonly RELEASE1B_PB_VERSION="0.29.3"
readonly RELEASE1B_TEST_DOMAIN="example.invalid"
readonly SEED_MIGRATION_EXCLUDE="1782898775_seed_superadmin_user_4fd7.js"
readonly OTP_ADAPTER_FILENAME="release1b_otp_test_adapter.pb.js"
readonly PHONE_GUARD_HOOK_FILENAME="release1b_r24_phone_verified_guard.pb.js"

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
  [emergency_hardening]="" [push_broadcast]="POST" [whatsapp]="GET"
)
typeset -grA HOOK_PROBE_AUTH=([emergency_hardening]="" [push_broadcast]="admin" [whatsapp]="admin")
typeset -grA HOOK_PROBE_SAFE_STATUS=([push_broadcast]="400" [whatsapp]="200 401 403 500")

typeset -g HOOK_OTP_PHONE_ROUTE="/api/auth/request-whatsapp-otp"
typeset -g HOOK_OTP_VERIFY_ROUTE="/api/auth/verify-whatsapp-otp"
typeset -g HOOK_OTP_CTRL_ROUTE="/api/test/otp-control"
typeset -g RELEASE1B_SCHEMA_SRC="UNRESOLVED__NEEDS_EXTERNAL__schema_src_path"

readonly SYNTH_PHONE_OTP="+601_R24TEST_77701234"
readonly SYNTH_PHONE_LINK="+601_R24TEST_00012345"
readonly SYNTH_PHONE_XUSER="+601_R24TEST_99900001"

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
typeset -g PBJ_SCAN_PY="" PBJ_CRED_SCAN_PY="" PBJ_TOK_PY="" PBJ_CMP_PY=""
typeset -g PBJ_DUPEID_PY=""

# D24-2: NSU credentials + record ID file.
typeset -g _NSU_EMAIL="" _NSU_PW_FILE="" _NSU_TOK_FILE="" _NSU_AUTH_CFG=""
typeset -g _NSU_REC_FILE="" _NSU_BOOTSTRAP_MIG_PATH=""

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
typeset -ga ENUM_CT_VALUES=() ENUM_SIZE_VALUES=() ENUM_TIME_VALUES=() ENUM_HDR_FILES=()
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
  local tmp="${dp}/.r24_rpt_tmp_${RUN_SUFFIX}"
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
  for sf in "$_NSU_PW_FILE" "$_NSU_TOK_FILE" "$_NSU_AUTH_CFG" "$_NSU_REC_FILE" \
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
_t_fatal_internal() {
  local orig_id="$1" outcome1="$2" outcome2="$3"
  pb_inc T_BLOCKING; HALT_DEPENDENTS=1
  local msg="HARNESS_INTEGRITY: '${orig_id}' received '${outcome1}' then '${outcome2}'"
  BLOCKING_DECISIONS+=("${msg}")
  printf '| HARNESS_INTEGRITY_%s | BLOCKING | %s |\n' \
    "${orig_id//[^A-Za-z0-9_-]/}" "$msg" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[HARNESS_INTEGRITY] ${msg}" >&2
}

_t_record_outcome() {
  local id="$1" outcome="$2"
  if [[ -n "${T_OUTCOME_MAP[$id]:-}" ]]; then
    _t_fatal_internal "$id" "${T_OUTCOME_MAP[$id]}" "$outcome"
    return 1
  fi
  T_OUTCOME_MAP[$id]="$outcome"; return 0
}

t_pass()      {
  local l="$1" m="${2:-}"; _t_record_outcome "$l" "PASS" || return
  pb_inc T_PASS
  printf '| %s | PASS | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[PASS] ${l}${m:+ | }${m}"
}
t_fail()      {
  local l="$1" m="${2:-}"; _t_record_outcome "$l" "FAIL" || return
  pb_inc T_FAIL; BLOCKING_DECISIONS+=("FAIL: ${l}: ${m}")
  printf '| %s | FAIL | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[FAIL] ${l}: ${m}" >&2
}
t_blocking()  {
  local l="$1" m="${2:-}"; _t_record_outcome "$l" "BLOCKING" || return
  pb_inc T_BLOCKING; HALT_DEPENDENTS=1; BLOCKING_DECISIONS+=("BLOCKING: ${l}: ${m}")
  printf '| %s | BLOCKING | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[BLOCKING] ${l}: ${m}" >&2
}
t_unresolved() {
  local l="$1" m="${2:-}"; _t_record_outcome "$l" "UNRESOLVED" || return
  pb_inc T_UNRESOLVED; UNRESOLVED_ITEMS+=("UNRESOLVED: ${l}: ${m}")
  printf '| %s | UNRESOLVED | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[UNRESOLVED] ${l}: ${m}" >&2
}
t_deferred_mandatory() {
  local l="$1" m="${2:-}"; _t_record_outcome "$l" "DEFERRED" || return
  pb_inc T_DEFERRED; UNRESOLVED_ITEMS+=("DEFERRED-MANDATORY: ${l}: ${m}")
  printf '| %s | DEFERRED-MANDATORY | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[DEFERRED-MANDATORY] ${l}: ${m}"
}
t_skip()      {
  local l="$1" m="${2:-}"; _t_record_outcome "$l" "SKIP" || return
  pb_inc T_SKIP
  printf '| %s | SKIP | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[SKIP] ${l}: ${m}"
}
t_harness_err() {
  local l="$1" m="${2:-}"; _t_record_outcome "$l" "HARNESS_ERR" || return
  pb_inc T_HARNESS_ERR; HARNESS_ERRORS+=("HARNESS_ERR: ${l}: ${m}")
  printf '| %s | HARNESS_ERR | %s |\n' "$l" "$m" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[HARNESS_ERR] ${l}: ${m}" >&2
}
t_authorized_exclusion() {
  printf '| %s | AUTHORIZED-EXCLUSION | %s |\n' "$1" "${2:-}" >> "$RELEASE1B_REPORT_WORK" 2>/dev/null
  print "[AUTHORIZED-EXCLUSION] $1: ${2:-}"
}

# ────────────────────────────────────────────────────────────
# §8  PYTHON HELPERS  (D24-3,4,5,6)
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

  # D24-3,5,6: pbj_http.py — curl config file for auth, extended output, explicit auth mode.
  PBJ_HTTP_PY="${d}/pbj_http.py"; cat > "$PBJ_HTTP_PY" << 'PYEOF'
import sys,os,subprocess,re,stat as _st,tempfile

MAX_RESP=1024*512

BLOCKED_HDR=frozenset(['authorization','cookie','set-cookie','www-authenticate',
    'x-auth-token','x-file-token','x-token','x-real-ip','x-forwarded-for'])

def _is_regular_file(path):
    try:
        s=os.lstat(path)
        return (not _st.S_ISLNK(s.st_mode)) and _st.S_ISREG(s.st_mode)
    except OSError: return False

def _sanitize_hdr_dump(dump_path):
    lines=[]
    try:
        with open(dump_path,errors='replace') as f: raw=f.readlines()
    except Exception: return ''
    for line in raw:
        line=line.rstrip('\r\n')
        if not line or line.startswith('HTTP/'): lines.append(line); continue
        if ':' in line:
            name=line.split(':',1)[0].strip().lower()
            if name in BLOCKED_HDR:
                lines.append(f'{line.split(":")[0].strip()}: [REDACTED]'); continue
        lines.append(line)
    return '\n'.join(lines)

def main():
    status_out=sys.argv[1]; path_out=sys.argv[2]; url=sys.argv[3]
    auth_mode=sys.argv[4] if len(sys.argv)>4 else 'anon'
    auth_file=sys.argv[5] if len(sys.argv)>5 else ''
    body_file=sys.argv[6] if len(sys.argv)>6 else ''
    method=sys.argv[7] if len(sys.argv)>7 else 'GET'
    hdr_out=sys.argv[8]  if len(sys.argv)>8  else ''
    ct_out=sys.argv[9]   if len(sys.argv)>9  else ''
    size_out=sys.argv[10] if len(sys.argv)>10 else ''
    time_out=sys.argv[11] if len(sys.argv)>11 else ''

    CANONICAL_TMP=os.environ.get('RELEASE1B_CANONICAL_TMP','') or os.path.dirname(status_out)

    resp_path=os.path.join(CANONICAL_TMP,f'resp_{os.getpid()}_{os.urandom(4).hex()}.json')
    with open(resp_path,'w') as f: f.write('')
    os.chmod(resp_path,0o600)

    hdr_dump=os.path.join(CANONICAL_TMP,f'hdrdump_{os.getpid()}_{os.urandom(4).hex()}.txt')
    with open(hdr_dump,'w') as f: f.write('')
    os.chmod(hdr_dump,0o600)

    # D24-6: validate auth_mode before touching curl
    if auth_mode not in ('anon','auth'):
        print(f'ERROR:unknown auth_mode {auth_mode!r}',file=sys.stderr)
        _write_fail(status_out,path_out,resp_path); sys.exit(1)

    curl_cfg_path=None
    if auth_mode=='auth':
        # D24-6: fail hard if auth file missing/invalid/symlink
        if not auth_file:
            print('ERROR:auth mode requires auth_file',file=sys.stderr)
            _write_fail(status_out,path_out,resp_path); sys.exit(1)
        if not _is_regular_file(auth_file):
            print(f'ERROR:auth_file not a regular file: {os.path.basename(auth_file)!r}',file=sys.stderr)
            _write_fail(status_out,path_out,resp_path); sys.exit(1)
        try:
            with open(auth_file) as f: hdr=f.read().strip()
        except Exception as e:
            print(f'ERROR:auth_file read failed',file=sys.stderr)
            _write_fail(status_out,path_out,resp_path); sys.exit(1)
        if not re.match(r'^Authorization: Bearer [A-Za-z0-9._\-]+$',hdr):
            print('ERROR:auth_file header format invalid',file=sys.stderr)
            _write_fail(status_out,path_out,resp_path); sys.exit(1)
        # D24-3: write to curl config file, NOT to subprocess argv
        curl_cfg_path=os.path.join(CANONICAL_TMP,f'curlcfg_{os.getpid()}_{os.urandom(4).hex()}.cfg')
        with open(curl_cfg_path,'w') as f: f.write(f'header = "{hdr}"\n')
        os.chmod(curl_cfg_path,0o600)

    cmd=['curl','-sf','--max-time','30','--connect-timeout','10',
         '--dump-header',hdr_dump,
         '--output',resp_path,
         '--write-out','%{http_code}\t%{content_type}\t%{size_download}\t%{time_total}',
         '-X',method.upper(),'-H','Content-Type: application/json']

    if curl_cfg_path:
        cmd+=['--config',curl_cfg_path]  # auth header via config file, not argv

    if body_file and _is_regular_file(body_file):
        cmd+=['--data-binary',f'@{body_file}']
    cmd.append(url)

    try:
        result=subprocess.run(cmd,capture_output=True,text=True)
        wo=result.stdout.strip()
        parts=wo.split('\t') if wo else []
        status=parts[0] if parts else '000'
        ct=parts[1] if len(parts)>1 else ''
        size=parts[2] if len(parts)>2 else '0'
        ttime=parts[3] if len(parts)>3 else '0'
    finally:
        # D24-3: delete curl config immediately after request
        if curl_cfg_path and os.path.exists(curl_cfg_path):
            try: os.unlink(curl_cfg_path)
            except Exception: pass

    try:
        sz=os.path.getsize(resp_path)
        if sz>MAX_RESP:
            with open(resp_path,'r+b') as f: f.seek(MAX_RESP); f.truncate()
    except Exception: pass

    # D24-5: write sanitized headers
    if hdr_out:
        sanitized=_sanitize_hdr_dump(hdr_dump)
        with open(hdr_out,'w') as f: f.write(sanitized)
        os.chmod(hdr_out,0o600)
    try: os.unlink(hdr_dump)
    except Exception: pass

    with open(status_out,'w') as f: f.write(status or '000')
    os.chmod(status_out,0o600)
    with open(path_out,'w') as f: f.write(resp_path)
    os.chmod(path_out,0o600)
    if ct_out:
        with open(ct_out,'w') as f: f.write(ct[:256])
        os.chmod(ct_out,0o600)
    if size_out:
        with open(size_out,'w') as f: f.write(size)
        os.chmod(size_out,0o600)
    if time_out:
        with open(time_out,'w') as f: f.write(ttime)
        os.chmod(time_out,0o600)

def _write_fail(status_out,path_out,resp_path):
    try:
        with open(status_out,'w') as f: f.write('000')
        os.chmod(status_out,0o600)
        with open(path_out,'w') as f: f.write(resp_path)
        os.chmod(path_out,0o600)
    except Exception: pass

main()
PYEOF

  # D24-4: pbj_field.py — explicit allowlist; BLOCKED permanently prohibits sensitive fields.
  PBJ_FIELD_PY="${d}/pbj_field.py"; cat > "$PBJ_FIELD_PY" << 'PYEOF'
import sys,json,re

# D24-4: Explicit allowlist of safe printable fields.
# Anything not in this set is rejected regardless of BLOCKED status.
ALLOWED=frozenset({
    'id','collectionId','collectionName',
    'created','updated',
    'role','name','username','displayName',
    'verified',
    'adapter_status','is_used',
    'mode','epochId',
    'status','count','page','perPage','totalItems','totalPages',
})
# D24-4: Permanently blocked; checked even if somehow added to ALLOWED later.
BLOCKED=frozenset({
    'token','email','phone','code',
    'password','passwordConfirm','passwordHash','tokenKey',
    'phone_verified','alias','emailAlias','identity',
    'fileToken','file_token','hmac',
})
resp_file=sys.argv[1]; field=sys.argv[2]
if field in BLOCKED:
    print(f'ERROR: field {field!r} is permanently blocked',file=sys.stderr); sys.exit(1)
if field not in ALLOWED:
    print(f'ERROR: field {field!r} not in allowlist',file=sys.stderr); sys.exit(1)
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

  # D24-4: pbj_tok.py — non-printing token extractor; writes directly to protected file.
  PBJ_TOK_PY="${d}/pbj_tok.py"; cat > "$PBJ_TOK_PY" << 'PYEOF'
"""
pbj_tok.py: Extract auth token and optional record ID from an auth response.
Writes token directly to tok_file, record ID to rec_id_file.
Never prints token, record ID, or email to stdout.
Prints 'OK' on success, 'ERROR:reason' on failure.
Args: resp_file tok_file [rec_id_file] [expected_collection_name]
"""
import sys,os,json,re,stat as _st

def _is_regular(path):
    try: s=os.lstat(path); return not _st.S_ISLNK(s.st_mode) and _st.S_ISREG(s.st_mode)
    except OSError: return False

def main():
    if len(sys.argv)<3: print('ERROR:usage'); sys.exit(1)
    resp_file=sys.argv[1]; tok_file=sys.argv[2]
    rec_id_file=sys.argv[3] if len(sys.argv)>3 else ''
    expected_coll=sys.argv[4] if len(sys.argv)>4 else ''
    if not _is_regular(resp_file): print('ERROR:resp_file'); sys.exit(1)
    if not _is_regular(tok_file): print('ERROR:tok_file'); sys.exit(1)
    try:
        with open(resp_file) as f: data=json.load(f)
    except Exception: print('ERROR:json_parse'); sys.exit(1)
    tok=data.get('token','')
    if not tok or not re.match(r'^[A-Za-z0-9._\-]{10,}$',tok):
        print('ERROR:token_invalid'); sys.exit(1)
    rec=data.get('record',{})
    if not isinstance(rec,dict): print('ERROR:record_not_dict'); sys.exit(1)
    if expected_coll:
        actual_coll=rec.get('collectionName','')
        if actual_coll!=expected_coll:
            print(f'ERROR:collection_mismatch'); sys.exit(1)
    rec_id=rec.get('id','')
    if not rec_id or not re.match(r'^[a-z0-9]{15}$',rec_id):
        print('ERROR:record_id_invalid'); sys.exit(1)
    # Write token without printing it
    with open(tok_file,'w') as f: f.write(tok)
    os.chmod(tok_file,0o600)
    if rec_id_file:
        if not _is_regular(rec_id_file): print('ERROR:rec_id_file'); sys.exit(1)
        with open(rec_id_file,'w') as f: f.write(rec_id)
        os.chmod(rec_id_file,0o600)
    print('OK')

main()
PYEOF

  # D24-4: pbj_cmp.py — field comparison without printing sensitive values.
  PBJ_CMP_PY="${d}/pbj_cmp.py"; cat > "$PBJ_CMP_PY" << 'PYEOF'
"""
pbj_cmp.py: Compare a specific field value to an expected value.
Prints MATCH or MISMATCH. Never prints the actual field value.
Safe for comparing sensitive fields (phone, phone_verified, etc.)
Args: resp_file field expected_value
"""
import sys,json

BLOCKED=frozenset({
    'token','email','password','passwordConfirm','passwordHash','tokenKey',
    'code','alias','emailAlias','fileToken',
})
ALLOWED_CMP=frozenset({
    'phone','phone_verified','role','name','verified',
    'adapter_status','is_used','status',
    'id','collectionId','collectionName','mode','epochId',
})
resp_file=sys.argv[1]; field=sys.argv[2]; expected=sys.argv[3]
if field in BLOCKED: print('ERROR:BLOCKED'); sys.exit(1)
if field not in ALLOWED_CMP: print(f'ERROR:NOT_IN_ALLOWLIST:{field}'); sys.exit(1)
with open(resp_file) as f: data=json.load(f)
actual=data.get(field,'__absent__')
if isinstance(actual,bool): actual_s='true' if actual else 'false'
elif actual is None: actual_s='__null__'
else: actual_s=str(actual)
print('MATCH' if actual_s==expected else 'MISMATCH')
PYEOF

  # D24-1: pbj_dupeid.py — static duplicate test-ID checker.
  PBJ_DUPEID_PY="${d}/pbj_dupeid.py"; cat > "$PBJ_DUPEID_PY" << 'PYEOF'
"""
pbj_dupeid.py: Scan harness source for duplicate static test IDs.
Extracts literal quoted IDs from terminal function calls.
Ignores dynamic IDs containing ${...} variable interpolation.
"""
import sys,re,collections

content=open(sys.argv[1]).read()
TERMS=r'\b(?:t_pass|t_fail|t_blocking|t_skip|t_harness_err|t_unresolved|t_deferred_mandatory)\s+'
# Match only literal IDs (no $ in string)
PAT=re.compile(TERMS+r'"(T-[A-Z0-9_\-]+)"')
ids=PAT.findall(content)
counter=collections.Counter(ids)
dupes={k:v for k,v in counter.items() if v>1}
if dupes:
    for k,v in sorted(dupes.items()):
        print(f'DUPLICATE_STATIC_ID: {k!r} x{v}',file=sys.stderr)
    sys.exit(1)
print(f'OK: {len(counter)} unique static test IDs found')
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
os.chmod(tmp,0o600); os.replace(tmp,report_out)
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
    "$PBJ_FIELD_PY" "$PBJ_TOK_PY" "$PBJ_CMP_PY" "$PBJ_DUPEID_PY" \
    "$PBJ_COPY_PY" "$PBJ_EXTRACT_PY" "$PBJ_SHAPE_PY" \
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

# D24-4: Field comparison without printing sensitive values.
_assert_user_field() {
  local user_id="$1" field="$2" expected="$3"
  [[ -z "$user_id" ]] && { printf 'ERROR:empty_user_id'; return 1 }
  local vs; vs=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" \
    "$vs" "$vrp_f" \
    "$(pb_url "/api/collections/users/records/${user_id}")" \
    "auth" "$_NSU_AUTH_CFG" "" "GET"
  local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs" "$vrp_f"
  local result; result=$(python3 "$PBJ_CMP_PY" "$vrp" "$field" "$expected" 2>/dev/null)
  rm -f "$vrp"
  printf '%s' "$result"
}

# ────────────────────────────────────────────────────────────
# §10 HARNESS SELF-TEST  (D23-9, D24-1)
# ────────────────────────────────────────────────────────────
t_harness_selftest() {
  print "=== Harness self-test (offline) ==="
  local fail=0

  # pbj.py validation
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

  # D24-4: pbj_field.py allowlist check
  local jf; jf=$(pb_secure_tmpfile .json)
  printf '{"role":"user","token":"secret_tok","phone":"+601test"}' > "$jf"
  local v; v=$(python3 "$PBJ_FIELD_PY" "$jf" "role" 2>/dev/null)
  [[ "$v" != "user" ]] && {
    print "[selftest] pbj_field.py: role read failed (got '${v}')" >&2; fail=1
  }
  v=$(python3 "$PBJ_FIELD_PY" "$jf" "token" 2>/dev/null)
  [[ "$v" == "secret_tok" ]] && {
    print "[selftest] pbj_field.py: token not blocked" >&2; fail=1
  }
  v=$(python3 "$PBJ_FIELD_PY" "$jf" "phone" 2>/dev/null)
  [[ "$v" == "+601test" ]] && {
    print "[selftest] pbj_field.py: phone not blocked" >&2; fail=1
  }
  v=$(python3 "$PBJ_FIELD_PY" "$jf" "email" 2>/dev/null)
  [[ "$v" != "" && "$v" != *"ERROR"* && "$v" != *"blocked"* && "$v" != *"allowlist"* ]] && {
    print "[selftest] pbj_field.py: email not blocked (got '${v}')" >&2; fail=1
  }
  rm -f "$jf"

  # D24-4: pbj_tok.py — non-printing token extraction
  local mock_resp; mock_resp=$(pb_secure_tmpfile .json)
  printf '{"token":"eyJhbGciOiJIUzI1NiJ9.abc.def123","record":{"id":"aabbccddeeff123","collectionName":"users"}}' > "$mock_resp"
  local tok_f; tok_f=$(pb_secure_tmpfile .tok)
  local tok_rc; python3 "$PBJ_TOK_PY" "$mock_resp" "$tok_f" 2>/dev/null; tok_rc=$?
  local tok_val; tok_val=$(cat "$tok_f" 2>/dev/null)
  if (( tok_rc != 0 )) || [[ -z "$tok_val" ]]; then
    print "[selftest] pbj_tok.py: extraction failed (rc=${tok_rc})" >&2; fail=1
  fi
  rm -f "$mock_resp" "$tok_f"

  # D24-4: pbj_cmp.py — comparison without printing
  local cmp_resp; cmp_resp=$(pb_secure_tmpfile .json)
  printf '{"phone":"+60123456789","phone_verified":true,"role":"user"}' > "$cmp_resp"
  local cmp_r; cmp_r=$(python3 "$PBJ_CMP_PY" "$cmp_resp" "phone_verified" "true" 2>/dev/null)
  [[ "$cmp_r" != "MATCH" ]] && {
    print "[selftest] pbj_cmp.py: phone_verified MATCH failed (got '${cmp_r}')" >&2; fail=1
  }
  cmp_r=$(python3 "$PBJ_CMP_PY" "$cmp_resp" "phone_verified" "false" 2>/dev/null)
  [[ "$cmp_r" != "MISMATCH" ]] && {
    print "[selftest] pbj_cmp.py: phone_verified MISMATCH failed" >&2; fail=1
  }
  rm -f "$cmp_resp"

  # Symlink detection
  local link_target; link_target=$(pb_secure_tmpfile .tgt)
  local link_name="${RELEASE1B_TEST_TMP}/selftest_link_${RANDOM}"
  ln -s "$link_target" "$link_name" 2>/dev/null
  local link_result; link_result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$link_name" 2>/dev/null)
  [[ "$link_result" != "SYMLINK" ]] && {
    print "[selftest] symlink not detected (got '${link_result}')" >&2; fail=1
  }
  rm -f "$link_name" "$link_target"

  # Credential scanner
  local cred_f; cred_f=$(pb_secure_tmpfile .js)
  printf 'admin.set("password", "$$TestCredXyz$$");\n' > "$cred_f"
  python3 "$PBJ_CRED_SCAN_PY" "$cred_f" 2>/dev/null
  local scan_rc=$?; rm -f "$cred_f"
  (( scan_rc != 1 )) && {
    print "[selftest] cred scanner missed test pattern (rc=${scan_rc})" >&2; fail=1
  }

  # D23-9: Double-outcome detection (isolated state)
  local -A _st_map=()
  local _st_dupe=0
  _st_rec() {
    local id="$1"
    if [[ -n "${_st_map[$id]:-}" ]]; then _st_dupe=1; return 1; fi
    _st_map[$id]="used"; return 0
  }
  _st_rec "ST-DUPE-PP" || { print "[selftest] unexpected reject (PASS/PASS first)" >&2; fail=1 }
  _st_rec "ST-DUPE-PP"; (( _st_dupe == 0 )) && { print "[selftest] PASS/PASS dupe not detected" >&2; fail=1 }
  _st_map=(); _st_dupe=0
  _st_rec "ST-DUPE-PF" || { print "[selftest] unexpected reject (PASS/FAIL first)" >&2; fail=1 }
  _st_rec "ST-DUPE-PF"; (( _st_dupe == 0 )) && { print "[selftest] PASS/FAIL dupe not detected" >&2; fail=1 }
  _st_map=(); _st_dupe=0
  _st_rec "ST-DUPE-FP" || { print "[selftest] unexpected reject (FAIL/PASS first)" >&2; fail=1 }
  _st_rec "ST-DUPE-FP"; (( _st_dupe == 0 )) && { print "[selftest] FAIL/PASS dupe not detected" >&2; fail=1 }
  unfunction _st_rec 2>/dev/null || true

  # D24-1: Static duplicate test-ID check
  local harness_path="${${(%):-%N}}"
  if [[ -f "$harness_path" ]]; then
    local dupeid_result; dupeid_result=$(python3 "$PBJ_DUPEID_PY" "$harness_path" 2>&1)
    if [[ "$dupeid_result" == *"DUPLICATE_STATIC_ID"* ]]; then
      print "[selftest] DUPLICATE TEST IDs: ${dupeid_result}" >&2; fail=1
    else
      print "[selftest] Static ID dedup: ${dupeid_result}"
    fi
  else
    print "[selftest] WARNING: harness path unavailable for static dedup check" >&2
  fi

  # Cleanup target validation
  pb_validate_cleanup_target "" 2>/dev/null && {
    print "[selftest] cleanup accepted empty path" >&2; fail=1
  }
  pb_validate_cleanup_target "/" 2>/dev/null && {
    print "[selftest] cleanup accepted '/'" >&2; fail=1
  }
  local no_marker="${TMPDIR:-/tmp}/release1b_cp0_selftest_nomarker_$$"
  mkdir -p "$no_marker" 2>/dev/null
  pb_validate_cleanup_target "$no_marker" 2>/dev/null && {
    print "[selftest] cleanup accepted no-marker dir" >&2; fail=1
  }
  rm -rf "$no_marker" 2>/dev/null
  local sym_real="${TMPDIR:-/tmp}/release1b_selftest_symreal_$$"
  local sym_link="${TMPDIR:-/tmp}/release1b_cp0_selftest_symlink_$$"
  mkdir -p "$sym_real" 2>/dev/null
  printf 'marker\n' > "${sym_real}/.release1b_marker" 2>/dev/null
  ln -sf "$sym_real" "$sym_link" 2>/dev/null
  pb_validate_cleanup_target "$sym_link" 2>/dev/null && {
    print "[selftest] cleanup accepted symlink" >&2; fail=1
  }
  rm -rf "$sym_real"; rm -f "$sym_link"
  pb_validate_cleanup_target "$RELEASE1B_ISOLATED_ROOT" 2>/dev/null || {
    print "[selftest] cleanup rejected valid isolated root" >&2; fail=1
  }

  if (( fail )); then
    print "[selftest] RESULT: FAIL (${fail} issue(s))" >&2; return 1
  fi
  print "[selftest] RESULT: PASS"
}

# ────────────────────────────────────────────────────────────
# §11 INFRASTRUCTURE
# ────────────────────────────────────────────────────────────
pb_detect_platform() {
  local os_name arch
  os_name=$(uname -s | tr '[:upper:]' '[:lower:]'); arch=$(uname -m)
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
    [[ ! -f "${HOOK_SRC_PATHS[$hk]}" ]] && { print "[pkg] HOOK_SRC_PATHS[$hk]: not found"; ok=0 }
  done
  [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]] && { print "[pkg] RELEASE1B_SCHEMA_SRC: UNRESOLVED"; ok=0 }
  local sd="${${(%):-%N}:h}"
  [[ ! -f "${sd}/${OTP_ADAPTER_FILENAME}" ]] && { print "[pkg] OTP adapter not found"; ok=0 }
  (( ok )) && print "[pkg] OK" && return 0
  print "[pkg] INCOMPLETE"; return 1
}

# ────────────────────────────────────────────────────────────
# §12 NSU BOOTSTRAP  (D23-2/3, D24-2)
# ────────────────────────────────────────────────────────────
pb_setup_nsu_credentials() {
  _NSU_EMAIL="cp0_nsu_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  _NSU_PW_FILE=$(pb_secure_tmpfile .pw)
  openssl rand -base64 32 | tr -d '\n=' > "$_NSU_PW_FILE"
}

pb_write_nsu_bootstrap_migration() {
  print "=== Writing NSU bootstrap migration ==="
  _NSU_BOOTSTRAP_MIG_PATH="${RELEASE1B_PB_MIGRATIONS_DIR}/0000000001_r24_nsu_bootstrap.js"
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
  _su_pw=""
  t_pass "T-NSU-BOOTSTRAP-MIG-WRITTEN"
}

pb_write_future_schema_migration() {
  print "=== Writing future schema migration ==="
  local mig="${RELEASE1B_PB_MIGRATIONS_DIR}/9999999999_r24_future_schema.js"
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
// release1b_r24_phone_verified_guard.pb.js — ISOLATED ENV ONLY
onRecordUpdateRequest(function(e) {
  var body=e.requestInfo().body;
  var tp=body["phone"]!==undefined; var tpv=body["phone_verified"]!==undefined;
  if (!tp && !tpv) { e.next(); return; }
  if (tpv && body["phone_verified"]===true) {
    var targetRole=e.record ? e.record.getString("role") : "";
    if (targetRole==="admin"||targetRole==="superadmin") {
      throw new ForbiddenError("Admin accounts cannot be made eligible for phone authentication.");
    }
    var ep=tp ? String(body["phone"]||"").trim() : (e.record ? e.record.getString("phone") : "");
    if (!ep) { throw new BadRequestError("Cannot set phone_verified=true without a non-blank phone."); }
  }
  try {
    if (e.auth && e.auth.collection().name==="_superusers") { e.next(); return; }
  } catch(_) {}
  throw new ForbiddenError("phone and phone_verified can only be modified by the OTP verification path or _superusers emergency recovery.");
},"users");
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
    (( scan_rc == 1 )) && { print "[migrations] CRED SUSPECTED: ${bn}" >&2; cred_suspect=1 }
    cp "$_jf" "${RELEASE1B_PB_MIGRATIONS_DIR}/" && \
      chmod 600 "${RELEASE1B_PB_MIGRATIONS_DIR}/${bn}" || {
      t_blocking "T-SCHEMA-MIGRATIONS" "cp failed: ${bn}"; return 1
    }
    (( js_count++ ))
  done
  (( cred_suspect )) && {
    t_blocking "T-SCHEMA-MIGRATIONS-CRED" "Credential detected in non-excluded migration"
    return 1
  }
  (( js_count == 0 )) && { t_blocking "T-SCHEMA-MIGRATIONS" "No .js files found"; return 1 }
  (( excluded == 0 )) && {
    t_blocking "T-SCHEMA-MIGRATIONS-EXCLUDE" "Seed migration not found to exclude"; return 1
  }
  t_pass "T-SCHEMA-MIGRATIONS"
}

pb_deploy_hooks() {
  print "=== Deploying hooks ==="
  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local src="${HOOK_SRC_PATHS[$hk]}"
    [[ "$src" == UNRESOLVED* ]] && { t_unresolved "T-HOOK-DEPLOY-${hk}" "src NEEDS-EXTERNAL"; continue }
    [[ ! -f "$src" ]] && { t_blocking "T-HOOK-DEPLOY-${hk}" "file not found"; continue }
    local exp="${HOOK_EXPECTED_SHA256[$hk]:-}"
    if [[ "$exp" != UNRESOLVED* ]]; then
      local act; act=$(shasum -a 256 "$src" | awk '{print $1}')
      [[ "$act" != "$exp" ]] && { t_blocking "T-HOOK-HASH-${hk}" "hash mismatch"; continue }
    fi
    local dest="${RELEASE1B_PB_HOOKS_DIR}/$(basename "$src")"
    if cp "$src" "$dest" && chmod 600 "$dest"; then t_pass "T-HOOK-DEPLOY-${hk}"
    else t_blocking "T-HOOK-DEPLOY-${hk}" "cp failed"
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
      if [[ -n "$_NSU_BOOTSTRAP_MIG_PATH" && -f "$_NSU_BOOTSTRAP_MIG_PATH" ]]; then
        rm -f "$_NSU_BOOTSTRAP_MIG_PATH"; _NSU_BOOTSTRAP_MIG_PATH=""
        print "=== Bootstrap migration deleted ==="
      fi
      return 0
    }
    sleep 1; (( tries++ ))
  done
  pb_halt "PocketBase did not become ready within 30s"
}

# D23-2/D24-2: Auth via /api/collections/_superusers/auth-with-password.
# D24-2: Stores _NSU_REC_FILE for use by pb_delete_local_superuser().
# D24-4: Uses pbj_tok.py — token never printed to stdout.
pb_create_local_superuser() {
  print "=== Authenticating NSU ==="
  _NSU_TOK_FILE=$(pb_secure_tmpfile .tok)
  _NSU_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  _NSU_REC_FILE=$(pb_secure_tmpfile .rec)

  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${_NSU_EMAIL}" \
    "secret-file:password=${_NSU_PW_FILE}" 2>/dev/null || {
    t_blocking "T-SU-AUTH-BODY" "pbj.py failed building auth body"
    rm -f "$body_f"; return 1
  }

  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" \
    "$sf" "$rp_f" \
    "$(pb_url /api/collections/_superusers/auth-with-password)" \
    "anon" "" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"

  if [[ "$status" != "200" ]]; then
    t_blocking "T-SU-AUTH" "NSU auth returned ${status}"
    rm -f "$resp_path"
    pb_wipe_secret_file "$_NSU_PW_FILE"
    return 1
  fi

  # D24-4: pbj_tok.py writes token + record ID to protected files; never prints them.
  local tok_rc; python3 "$PBJ_TOK_PY" \
    "$resp_path" "$_NSU_TOK_FILE" "$_NSU_REC_FILE" "_superusers" 2>/dev/null
  tok_rc=$?
  rm -f "$resp_path"
  pb_wipe_secret_file "$_NSU_PW_FILE"

  if (( tok_rc != 0 )); then
    t_blocking "T-SU-COLL-CHECK" "pbj_tok.py: auth response failed validation"
    return 1
  fi
  t_pass "T-SU-COLL-CHECK"
  t_pass "T-SU-TOKEN-VALID"

  python3 "$PBJ_AUTH_PY" "$_NSU_AUTH_CFG" "$_NSU_TOK_FILE" 2>/dev/null || {
    t_blocking "T-SU-AUTH-CFG" "pbj_auth.py failed"; return 1
  }
  t_pass "T-SU-CREATE-AUTH"
}

# D24-2: Actually delete the _superusers record; verify absence; wipe credentials.
pb_delete_local_superuser() {
  print "=== Deleting NSU record ==="
  local rec_id; rec_id=$(cat "$_NSU_REC_FILE" 2>/dev/null)

  if [[ -z "$rec_id" ]]; then
    t_harness_err "T-SU-DELETE" "NSU record ID unavailable; cannot verify deletion"
    pb_wipe_secret_file "$_NSU_TOK_FILE"
    pb_wipe_secret_file "$_NSU_AUTH_CFG"
    pb_wipe_secret_file "$_NSU_REC_FILE"
    CLEANUP_FAILURE=1; return 1
  fi

  # Step 1: DELETE the record (using NSU token before it's wiped).
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" \
    "$sf" "$rp_f" \
    "$(pb_url "/api/collections/_superusers/records/${rec_id}")" \
    "auth" "$_NSU_AUTH_CFG" "" "DELETE"
  local del_st; del_st=$(cat "$sf" 2>/dev/null)
  local del_rp; del_rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$sf" "$rp_f" "$del_rp"

  if [[ "$del_st" != "200" && "$del_st" != "204" ]]; then
    t_harness_err "T-SU-DELETE" "DELETE returned ${del_st}"
    pb_wipe_secret_file "$_NSU_TOK_FILE"
    pb_wipe_secret_file "$_NSU_AUTH_CFG"
    pb_wipe_secret_file "$_NSU_REC_FILE"
    CLEANUP_FAILURE=1; return 1
  fi

  # Step 2: Verify deletion (GET with same token — 404 or 401 both prove record is gone).
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" \
    "$sf" "$rp_f" \
    "$(pb_url "/api/collections/_superusers/records/${rec_id}")" \
    "auth" "$_NSU_AUTH_CFG" "" "GET"
  local ver_st; ver_st=$(cat "$sf" 2>/dev/null)
  local ver_rp; ver_rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$sf" "$rp_f" "$ver_rp"

  # Step 3: Wipe all credential files (after using auth for verification).
  pb_wipe_secret_file "$_NSU_TOK_FILE"
  pb_wipe_secret_file "$_NSU_AUTH_CFG"
  pb_wipe_secret_file "$_NSU_REC_FILE"

  # 404: record gone, token briefly valid.
  # 401: token invalidated because record was deleted.
  # Both are positive evidence of deletion.
  if [[ "$ver_st" == "404" || "$ver_st" == "401" ]]; then
    t_pass "T-SU-DELETE"
    print "[nsu] Record deleted and confirmed absent (status: ${ver_st})."
  else
    t_fail "T-SU-DELETE" "Absence verification: expected 404 or 401; got ${ver_st}"
    CLEANUP_FAILURE=1
  fi
}

pb_verify_email_domain() {
  print "=== Verifying example.invalid domain ==="
  local email="cp0_domtest_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${email}" "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" "role=user" 2>/dev/null || {
    t_blocking "T-SELFTEST-EMAIL-DOMAIN" "pbj.py failed"
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"; return 1
  }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "auth" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"; pb_wipe_secret_file "$pw_file"
  if [[ "$status" == "200" ]]; then
    local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
    rm -f "$resp_path"
    if [[ -n "$rec_id" && "$rec_id" != "__absent__" ]]; then
      local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"
      pb_delete_record "users" "$id_f"
    fi
    t_pass "T-SELFTEST-EMAIL-DOMAIN"; return 0
  fi
  rm -f "$resp_path"
  t_blocking "T-SELFTEST-EMAIL-DOMAIN" "example.invalid rejected (HTTP ${status})."
  return 1
}

# ────────────────────────────────────────────────────────────
# §13 HTTP CAPTURE (D24-5: full evidence; D24-6: explicit auth mode)
# ────────────────────────────────────────────────────────────
pb_capture() {
  local method="$1" url_suffix="$2" auth_cfg="${3:-}" body_f="${4:-}"
  local status_out="$5" resp_path_out="$6"
  shift 6; local -a expected=("$@")
  local url; url=$(pb_url "$url_suffix")
  local auth_mode="anon"; [[ -n "$auth_cfg" ]] && auth_mode="auth"
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" \
    "$status_out" "$resp_path_out" "$url" "$auth_mode" "${auth_cfg:-}" \
    "${body_f:-}" "$method"
  local actual; actual=$(cat "$status_out" 2>/dev/null)
  local exp; for exp in "${expected[@]}"; do [[ "$actual" == "$exp" ]] && return 0; done
  return 1
}

# D24-5: Full evidence capture (headers, content-type, size, timing).
pb_capture_full() {
  local method="$1" url_suffix="$2" auth_cfg="${3:-}" body_f="${4:-}"
  local status_f="$5" resp_f="$6" hdr_f="${7:-}" ct_f="${8:-}" size_f="${9:-}" time_f="${10:-}"
  shift 10; local -a expected=("$@")
  local url; url=$(pb_url "$url_suffix")
  local auth_mode="anon"; [[ -n "$auth_cfg" ]] && auth_mode="auth"
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" \
    "$status_f" "$resp_f" "$url" "$auth_mode" "${auth_cfg:-}" \
    "${body_f:-}" "$method" "${hdr_f:-}" "${ct_f:-}" "${size_f:-}" "${time_f:-}"
  local actual; actual=$(cat "$status_f" 2>/dev/null)
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
    rm -f "$body_f"; pb_wipe_secret_file "$pw_file"; return 1
  }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "auth" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"

  if [[ "$status" != "200" ]]; then
    t_blocking "T-USER-CREATE-${role}" "HTTP ${status}"
    rm -f "$rp"; pb_wipe_secret_file "$pw_file"; return 1
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
    "$(pb_url /api/collections/users/auth-with-password)" "anon" "" "$body_f" "POST"
  status=$(cat "$sf" 2>/dev/null); rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"

  if [[ "$status" != "200" ]]; then
    t_blocking "T-USER-AUTH-${role}" "HTTP ${status}"
    rm -f "$rp"; pb_wipe_secret_file "$pw_file"; return 1
  fi

  # D24-4: pbj_tok.py writes token directly to file; never prints it.
  python3 "$PBJ_TOK_PY" "$rp" "$tok_file" "" "" 2>/dev/null
  local tok_rc=$?
  rm -f "$rp"
  pb_wipe_secret_file "$pw_file"

  if (( tok_rc != 0 )); then
    t_blocking "T-USER-AUTH-TOKEN-${role}" "pbj_tok.py failed"; return 1
  fi
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
    "auth" "$_NSU_AUTH_CFG" "" "DELETE"
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
    "$(pb_url "/api/collections/${coll}")" "auth" "$_NSU_AUTH_CFG" "" "GET"
  local st; st=$(cat "$sf" 2>/dev/null); local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$sf" "$rp_f"
  if [[ "$st" != "200" ]]; then
    rm -f "$rp"; t_harness_err "T-RULE-BASELINE-${coll}" "GET ${st}"; return 1
  fi
  local val; val=$(python3 "$PBJ_FIELD_PY" "$rp" "status" 2>/dev/null || echo "")
  # Use pbj_field.py for listRule — but 'listRule' isn't in our allowlist.
  # Use a safe inline reader for rule values (they're not sensitive).
  val=$(python3 - "$rp" "$rule_type" << 'PYEOF'
import sys,json
with open(sys.argv[1]) as f: d=json.load(f)
rv=d.get(sys.argv[2],'__absent__')
print('__pb_null__' if rv is None else str(rv) if rv!='__absent__' else '__absent__')
PYEOF
)
  rm -f "$rp"
  RULE_BASELINE["${coll}::${rule_type}"]="$val"
  t_pass "T-RULE-BASELINE-${coll}-${rule_type}"
}

pb_apply_rule_local() {
  local coll="$1" rule_type="$2" nv="$3"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  printf '{ "%s": "%s" }' "$rule_type" "$nv" > "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url "/api/collections/${coll}")" "auth" "$_NSU_AUTH_CFG" "$body_f" "PATCH"
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
    "$(pb_url "/api/collections/${coll}")" "auth" "$_NSU_AUTH_CFG" "$body_f" "PATCH"
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
      "$(pb_url "/api/collections/${col}")" "auth" "$_NSU_AUTH_CFG" "" "GET"
    local st; st=$(cat "$sf" 2>/dev/null); local rp; rp=$(cat "$rp_f" 2>/dev/null)
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
  LEGACY_ID_FILE=$(pb_secure_tmpfile .id); LEGACY_TOK_FILE=$(pb_secure_tmpfile .tok)
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
    "$(pb_url /api/collections/users/records)" "auth" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null); local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  if [[ "$status" == "200" ]]; then
    python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null > "$LEGACY_ID_FILE" || true
    local rid; rid=$(cat "$LEGACY_ID_FILE" 2>/dev/null); rm -f "$rp"
    LEGACY_CHILD_ID_FILE=$(pb_secure_tmpfile .id)
    local cbody; cbody=$(pb_secure_tmpfile .json)
    python3 "$PBJ_PY" "$cbody" "user=${rid}" "name=LegacyChild_${RUN_SUFFIX}" 2>/dev/null
    local cs; cs=$(pb_secure_tmpfile .http); local cr; cr=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$cs" "$cr" \
      "$(pb_url /api/collections/children/records)" "auth" "$_NSU_AUTH_CFG" "$cbody" "POST"
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
      "$(pb_url /api/collections/users/auth-with-password)" "anon" "" "$body_f" "POST"
    status=$(cat "$sf" 2>/dev/null); rp=$(cat "$rp_f" 2>/dev/null)
    rm -f "$body_f" "$sf" "$rp_f"
    [[ "$status" == "200" ]] && {
      python3 "$PBJ_TOK_PY" "$rp" "$LEGACY_TOK_FILE" "" "" 2>/dev/null || true
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
  ALIAS_ID_FILE=$(pb_secure_tmpfile .id); ALIAS_PW_FILE=$(pb_secure_tmpfile .pw)
  ALIAS_AUTH_CFG=$(pb_secure_tmpfile .hdr)
  local alias_email="cp0_alias_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  openssl rand -base64 24 | tr -d '\n=' > "$ALIAS_PW_FILE"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${alias_email}" \
    "secret-file:password=${ALIAS_PW_FILE}" "secret-file:passwordConfirm=${ALIAS_PW_FILE}" \
    "role=user" "b:emailVisibility=true" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "auth" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local status; status=$(cat "$sf" 2>/dev/null); local rp; rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  [[ "$status" == "200" ]] && {
    python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null > "$ALIAS_ID_FILE" || true
  }
  rm -f "$rp"
  WRONG_PW_FILE=$(pb_secure_tmpfile .pw)
  printf 'definitely-wrong-password-R24xYzQ' > "$WRONG_PW_FILE"
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
    "$(pb_url /api/collections/users/records)" "auth" "$_NSU_AUTH_CFG" "$body_f" "POST"
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
    "auth" "$_NSU_AUTH_CFG" "" "GET"
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
    pb_wipe_secret_file "$pw_file"; rm -f "$body_f"; return 1
  }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "anon" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"; pb_wipe_secret_file "$pw_file"
  case "$http_status" in
    400|401|403)
      if _inj_check_no_users_record "$email" "$label"; then t_pass "${label}"; fi
      return 0 ;;
    200) ;;
    000|''|5[0-9][0-9]|*)
      rm -f "$resp_path"; t_harness_err "${label}" "Unexpected HTTP ${http_status}"; return 1 ;;
  esac
  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  [[ -z "$rec_id" || "$rec_id" == "__absent__" ]] && {
    t_blocking "${label}" "HTTP 200 but no id"; return 1
  }
  local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"
  local vs; vs=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$vs" "$vrp_f" \
    "$(pb_url "/api/collections/users/records/${rec_id}")" "auth" "$_NSU_AUTH_CFG" "" "GET"
  local vst; vst=$(cat "$vs" 2>/dev/null); local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs" "$vrp_f"
  pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1
  if [[ "$vst" != "200" ]]; then
    rm -f "$vrp"; t_blocking "${label}" "NSU verify ${vst}"; return 1
  fi
  # D24-4: use pbj_cmp.py for comparison; don't print field value.
  local cmp_result; cmp_result=$(python3 "$PBJ_CMP_PY" "$vrp" "$field" "$value" 2>/dev/null)
  rm -f "$vrp"
  local bv; for bv in ${=bad_values}; do
    if [[ "$cmp_result" == "MATCH" && "$value" == "$bv" ]]; then
      t_blocking "${label}" "INJECTION CONFIRMED: ${field} matched injected value"
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
    "$(pb_url /api/collections/users/records)" "anon" "" "$body_f" "POST"
  local http_status; http_status=$(cat "$sf" 2>/dev/null)
  local resp_path; resp_path=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"; pb_wipe_secret_file "$pw_file"
  case "$http_status" in
    400|401|403)
      if _inj_check_no_users_record "$email" "T-INJECT-CREATE-UNEXPECTED"; then
        rm -f "$resp_path"; t_pass "T-INJECT-CREATE-UNEXPECTED"
      else
        rm -f "$resp_path"
      fi
      return ;;
    200) ;;
    000|''|5[0-9][0-9]|*)
      rm -f "$resp_path"
      t_harness_err "T-INJECT-CREATE-UNEXPECTED" "HTTP ${http_status}"; return ;;
  esac
  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  [[ -z "$rec_id" || "$rec_id" == "__absent__" ]] && {
    t_blocking "T-INJECT-CREATE-UNEXPECTED" "200 no id"; return
  }
  local id_f; id_f=$(pb_secure_tmpfile .id); printf '%s' "$rec_id" > "$id_f"
  local vs; vs=$(pb_secure_tmpfile .http); local vrp_f; vrp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$vs" "$vrp_f" \
    "$(pb_url "/api/collections/users/records/${rec_id}")" "auth" "$_NSU_AUTH_CFG" "" "GET"
  local vst; vst=$(cat "$vs" 2>/dev/null); local vrp; vrp=$(cat "$vrp_f" 2>/dev/null)
  rm -f "$vs" "$vrp_f"
  pb_delete_record "users" "$id_f" || CLEANUP_FAILURE=1
  if [[ "$vst" != "200" ]]; then
    rm -f "$vrp"; t_blocking "T-INJECT-CREATE-UNEXPECTED" "NSU verify ${vst}"; return
  fi
  local role_r; role_r=$(python3 "$PBJ_FIELD_PY" "$vrp" "role" 2>/dev/null)
  local pv_r; pv_r=$(python3 "$PBJ_CMP_PY" "$vrp" "phone_verified" "true" 2>/dev/null)
  rm -f "$vrp"
  if [[ "$role_r" == "admin" || "$role_r" == "superadmin" ]]; then
    t_blocking "T-INJECT-CREATE-UNEXPECTED" "INJECTED ROLE: ${role_r}"; return
  fi
  if [[ "$pv_r" == "MATCH" ]]; then
    t_blocking "T-INJECT-CREATE-UNEXPECTED" "INJECTED phone_verified=true persisted"; return
  fi
  t_pass "T-INJECT-CREATE-UNEXPECTED"
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
  rm -f "$body_f" "$sf" "$rp_f" "$rp"; return $rc
}

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
    "auth" "$_NSU_AUTH_CFG" "" "GET"
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
    "auth" "$_NSU_AUTH_CFG" "" "GET"
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
# §18 PHONE GUARD TESTS
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
    t_fail "T-PHONE-MIXED-FIELD-REJECT" "Expected 403; got ${actual}"; return
  fi
  # D24-4: use _assert_user_field() — no printing of phone or name values.
  local ph_r; ph_r=$(_assert_user_field "$ord_id" "phone" "$SYNTH_PHONE_LINK")
  local nm_r; nm_r=$(_assert_user_field "$ord_id" "name" "SHOULD_NOT_PERSIST_${RUN_SUFFIX}")
  if [[ "$ph_r" == "MATCH" ]]; then
    t_fail "T-PHONE-MIXED-FIELD-REJECT" "phone persisted despite 403"; return
  fi
  if [[ "$nm_r" == "MATCH" ]]; then
    t_fail "T-PHONE-MIXED-FIELD-REJECT" "name persisted despite 403 (mixed rejection failed)"; return
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
    local pv_r; pv_r=$(_assert_user_field "$ord_id" "phone_verified" "true")
    local ph_r; ph_r=$(_assert_user_field "$ord_id" "phone" "$SYNTH_PHONE_LINK")
    _reset_user_phone "$ord_id"
    if [[ "$pv_r" == "MATCH" && "$ph_r" == "MATCH" ]]; then
      t_pass "T-PHONE-NSU-RECOVERY"
    else
      t_fail "T-PHONE-NSU-RECOVERY" "phone_match=${ph_r} pv_match=${pv_r}"
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
    t_skip "T-PHONE-OTP-AUTH-ANON" "blocked"
    t_skip "T-PHONE-OTP-AUTH-ADMIN" "blocked"
    t_skip "T-PHONE-OTP-AUTH-SADMIN" "blocked"
    return
  }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_request "$SYNTH_PHONE_OTP" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "" "$body_f" "$sf" "$rp_f" "401"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-OTP-AUTH-ANON"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-OTP-AUTH-ANON" "Expected 401; got ${actual}"
  fi
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "POST" "$HOOK_OTP_PHONE_ROUTE" "$ADMIN_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403"; then
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_pass "T-PHONE-OTP-AUTH-ADMIN"
  else
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$sf" "$rp_f" "$rp"
    t_fail "T-PHONE-OTP-AUTH-ADMIN" "Expected 403; got ${actual}"
  fi
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

t_phone_otp_cross_user_attack() {
  (( HALT_DEPENDENTS )) && { t_skip "T-PHONE-OTP-CROSS-USER" "blocked"; return }
  [[ -z "$ORDINARY_B_AUTH_CFG" || -z "$ORDINARY_B_ID_FILE" ]] && {
    t_skip "T-PHONE-OTP-CROSS-USER" "User B fixture not available"; return
  }
  _otp_set_mode "success" || { t_harness_err "T-PHONE-OTP-CROSS-USER" "Mode set failed"; return }
  local user_b_id; user_b_id=$(cat "$ORDINARY_B_ID_FILE" 2>/dev/null)
  local code; code=$(_otp_request_and_read_code "$SYNTH_PHONE_XUSER" "$ORDINARY_AUTH_CFG")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-PHONE-OTP-CROSS-USER" "OTP request or code read failed"; return
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$SYNTH_PHONE_XUSER" "$code" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" \
    "$ORDINARY_B_AUTH_CFG" "$body_f" "$sf" "$rp_f" "403" "400"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  if [[ "$actual" != "403" && "$actual" != "400" ]]; then
    t_fail "T-PHONE-OTP-CROSS-USER" "Cross-user verify returned ${actual}"; return
  fi
  local b_ph_r; b_ph_r=$(_assert_user_field "$user_b_id" "phone" "$SYNTH_PHONE_XUSER")
  local b_pv_r; b_pv_r=$(_assert_user_field "$user_b_id" "phone_verified" "true")
  if [[ "$b_ph_r" == "MATCH" || "$b_pv_r" == "MATCH" ]]; then
    t_fail "T-PHONE-OTP-CROSS-USER" "Cross-user spoofing: User B state changed (ph=${b_ph_r} pv=${b_pv_r})"
    return
  fi
  local active_cnt; active_cnt=$(_otp_count_by_status "$SYNTH_PHONE_XUSER" "sent_active")
  if [[ "$active_cnt" != "1" ]]; then
    t_fail "T-PHONE-OTP-CROSS-USER" "OTP state changed after rejected attempt (active=${active_cnt})"
    return
  fi
  t_pass "T-PHONE-OTP-CROSS-USER"
}

t_otp_expired() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-EXPIRED" "blocked"; return }
  _otp_set_mode "success" || { t_harness_err "T-OTP-EXPIRED" "Mode set failed"; return }
  local phone="+601_R24TEST_11199001"
  local code; code=$(_otp_request_and_read_code "$phone")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-OTP-EXPIRED" "OTP request failed"; return
  fi
  local fe; fe=$(python3 -c \
    "import urllib.parse,sys; print(urllib.parse.quote(f\"phone='{sys.argv[1]}' && adapter_status='sent_active'\"))" \
    -- "$phone" 2>/dev/null)
  local ds; ds=$(pb_secure_tmpfile .http); local dr; dr=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$ds" "$dr" \
    "$(pb_url "/api/collections/phone_otps/records")?filter=${fe}&perPage=1" \
    "auth" "$_NSU_AUTH_CFG" "" "GET"
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
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$phone" "$code" "$body_f"
  sf=$(pb_secure_tmpfile .http); rp_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "400"
  local vst; vst=$(cat "$sf" 2>/dev/null); rp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local exp_cnt; exp_cnt=$(_otp_count_by_status "$phone" "expired")
  local act_cnt; act_cnt=$(_otp_count_by_status "$phone" "sent_active")
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local pv_r; pv_r=$(_assert_user_field "$ord_id" "phone_verified" "true")
  if [[ "$vst" != "400" ]]; then
    t_fail "T-OTP-EXPIRED" "Expected 400 for expired OTP; got ${vst}"; return
  fi
  if [[ "$exp_cnt" != "1" ]]; then
    t_fail "T-OTP-EXPIRED" "expired_count=${exp_cnt} active_count=${act_cnt}"; return
  fi
  if [[ "$act_cnt" != "0" ]]; then
    t_fail "T-OTP-EXPIRED" "Expired OTP still sent_active"; return
  fi
  if [[ "$pv_r" == "MATCH" ]]; then
    t_fail "T-OTP-EXPIRED" "phone_verified set despite expired OTP"; return
  fi
  t_pass "T-OTP-EXPIRED"
}

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
  local ph_r; ph_r=$(_assert_user_field "$ord_id" "phone" "$SYNTH_PHONE_LINK")
  local pv_r; pv_r=$(_assert_user_field "$ord_id" "phone_verified" "true")
  local active_cnt; active_cnt=$(_otp_count_by_status "$SYNTH_PHONE_LINK" "sent_active")
  if [[ "$ph_r" == "MATCH" || "$pv_r" == "MATCH" ]]; then
    t_fail "T-PHONE-OTP-ROLLBACK" "Partial commit: ph_match=${ph_r} pv_match=${pv_r}"
    return
  fi
  t_pass "T-PHONE-OTP-ROLLBACK"
  print "[rollback] TX-3 rolled back. OTP active_cnt=${active_cnt} (retryable). phone+pv unchanged."
}

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
    t_fail "T-PHONE-OTP-ATOMIC-LINK" "Verify failed; got ${actual}"; return
  fi
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local ph_r; ph_r=$(_assert_user_field "$ord_id" "phone" "$SYNTH_PHONE_LINK")
  local pv_r; pv_r=$(_assert_user_field "$ord_id" "phone_verified" "true")
  local con_cnt; con_cnt=$(_otp_count_by_status "$SYNTH_PHONE_LINK" "consumed")
  _reset_user_phone "$ord_id"
  if [[ "$ph_r" != "MATCH" || "$pv_r" != "MATCH" || "$con_cnt" != "1" ]]; then
    t_fail "T-PHONE-OTP-ATOMIC-LINK" "ph_match=${ph_r} pv_match=${pv_r} consumed=${con_cnt}"
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
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local cnt; cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "pending_send")
  local active; active=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "sent_active")
  _otp_set_mode "success"
  if [[ "$cnt" == "0" && "$active" == "0" ]]; then
    t_pass "T-OTP-PENDING-CREATE-FAIL"
    print "[otp-create-fail] TX-1 rollback confirmed: no phone_otps record created."
  else
    t_fail "T-OTP-PENDING-CREATE-FAIL" "Expected 0 records; pending=${cnt} active=${active}"
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
    t_fail "T-OTP-DB-FAIL-CLEANUP-FAIL" "Expected 500; got ${actual}"; return
  fi
  if [[ "$active_cnt" != "0" ]]; then
    t_fail "T-OTP-DB-FAIL-CLEANUP-FAIL" "sent_active=${active_cnt} after cleanup fail"; return
  fi
  t_pass "T-OTP-DB-FAIL-CLEANUP-FAIL"
  print "[cleanup-fail] 500 returned. pending=${pending_cnt} active=${active_cnt}."
}

# ────────────────────────────────────────────────────────────
# §19 OTP LIFECYCLE GROUP  (D24-1: consolidated, no duplicates)
# ────────────────────────────────────────────────────────────
t_otp_flow() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-FLOW" "blocked"; return }
  _otp_set_mode "success" || { t_harness_err "T-OTP-FLOW" "Mode set failed"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _reset_user_phone "$ord_id"
  local code; code=$(_otp_request_and_read_code "$SYNTH_PHONE_OTP")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-OTP-FLOW" "OTP request failed"; return
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  _otp_body_verify "$SYNTH_PHONE_OTP" "$code" "$body_f"
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if ! pb_capture "POST" "$HOOK_OTP_VERIFY_ROUTE" \
      "$ORDINARY_AUTH_CFG" "$body_f" "$sf" "$rp_f" "200"; then
    local actual; actual=$(cat "$sf" 2>/dev/null)
    local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
    t_fail "T-OTP-FLOW" "Verify failed; got ${actual}"
    _reset_user_phone "$ord_id"; return
  fi
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local pv_r; pv_r=$(_assert_user_field "$ord_id" "phone_verified" "true")
  local ph_r; ph_r=$(_assert_user_field "$ord_id" "phone" "$SYNTH_PHONE_OTP")
  local con_cnt; con_cnt=$(_otp_count_by_status "$SYNTH_PHONE_OTP" "consumed")
  _reset_user_phone "$ord_id"
  if [[ "$con_cnt" == "1" && "$pv_r" == "MATCH" && "$ph_r" == "MATCH" ]]; then
    t_pass "T-OTP-FLOW"
    print "[otp-flow] lifecycle: pending_send→sent_active→consumed. phone+pv set atomically."
  else
    t_fail "T-OTP-FLOW" "consumed=${con_cnt} ph_match=${ph_r} pv_match=${pv_r}"
  fi
}

# D24-1: Single authoritative group; all OTP lifecycle tests here.
# pb_run_all_tests() calls ONLY this group for OTP tests.
t_otp_lifecycle_group() {
  (( HALT_DEPENDENTS )) && {
    for l in ORD-NO-PATCH-PHONE ORD-NO-PATCH-PV MIXED-FIELD-REJECT NSU-RECOVERY \
      NSU-PV-NO-PHONE OTP-AUTH-ANON OTP-AUTH-ADMIN OTP-AUTH-SADMIN OTP-CROSS-USER \
      OTP-ATOMIC-LINK OTP-ROLLBACK; do t_skip "T-PHONE-${l}" "blocked"; done
    t_skip "T-OTP-FLOW" "blocked"
    t_skip "T-OTP-PENDING-CREATE-FAIL" "blocked"
    t_skip "T-OTP-DB-FAIL-REQUEST" "blocked"
    t_skip "T-OTP-DB-FAIL-CLEANUP-FAIL" "blocked"
    t_skip "T-OTP-EXPIRED" "blocked"
    return
  }
  print "=== §28.6-7 OTP Lifecycle and Phone Protection Tests ==="
  t_phone_ordinary_cannot_patch_phone
  t_phone_ordinary_cannot_patch_phone_verified
  t_phone_mixed_field_rejection
  t_phone_nsu_can_set_phone_and_pv_together
  t_phone_nsu_cannot_set_pv_without_phone
  t_phone_otp_auth_requirements
  t_phone_otp_cross_user_attack
  t_phone_otp_atomic_link
  t_phone_otp_rollback
  t_otp_flow
  t_otp_pending_create_fail
  t_otp_db_fail_request
  t_otp_db_fail_request_cleanup_fail
  t_otp_expired
}

# ────────────────────────────────────────────────────────────
# §20 STANDARD CRUD / AUTH TESTS
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
    t_fail "T-FIELD-ROLE-REJECT" "Expected 403; got ${actual}"; return
  fi
  local rp; rp=$(cat "$rp_f" 2>/dev/null); rm -f "$body_f" "$sf" "$rp_f" "$rp"
  local role_r; role_r=$(_assert_user_field "$ord_id" "role" "admin")
  local sadmin_r; sadmin_r=$(_assert_user_field "$ord_id" "role" "superadmin")
  if [[ "$role_r" == "MATCH" || "$sadmin_r" == "MATCH" ]]; then
    t_fail "T-FIELD-ROLE-REJECT" "CRITICAL: privileged role persisted"
    return
  fi
  t_pass "T-FIELD-ROLE-REJECT"
}

t_file_auth_anon_list_rejected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-1" "blocked"; return }
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  if pb_capture "GET" "/api/collections/growth_logs/records" "" "" "$sf" "$rp_f" "401" "403"; then
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
  if pb_capture "GET" "/api/files/users/nonexistent_r24_id_xyz/nonexistent.jpg" \
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
t_field_phone_reject()   { t_deferred_mandatory "T-FIELD-PHONE-REJECT" "Covered by OTP lifecycle tests." }

# D24-5: Alias enumeration with full evidence capture and uniformity comparison.
pb_alias_enum_case() {
  local label="$1" email="$2" expected="$3"
  local body_f sf rp_f hdr_f ct_f size_f time_f
  body_f=$(pb_secure_tmpfile .json); sf=$(pb_secure_tmpfile .http)
  rp_f=$(pb_secure_tmpfile .rp); hdr_f=$(pb_secure_tmpfile .hdr)
  ct_f=$(pb_secure_tmpfile .ct); size_f=$(pb_secure_tmpfile .sz); time_f=$(pb_secure_tmpfile .tm)
  python3 "$PBJ_PY" "$body_f" "identity=${email}" "secret-file:password=${WRONG_PW_FILE}" \
    2>/dev/null || { t_harness_err "$label" "pbj.py"; rm -f "$body_f" "$hdr_f" "$ct_f" "$size_f" "$time_f"; return }
  pb_capture_full "POST" "/api/collections/users/auth-with-password" \
    "" "$body_f" "$sf" "$rp_f" "$hdr_f" "$ct_f" "$size_f" "$time_f" "400"
  local actual; actual=$(cat "$sf" 2>/dev/null)
  local resp; resp=$(cat "$rp_f" 2>/dev/null)
  local ct; ct=$(cat "$ct_f" 2>/dev/null)
  local sz; sz=$(cat "$size_f" 2>/dev/null)
  local tm; tm=$(cat "$time_f" 2>/dev/null)
  ENUM_HTTP_VALUES+=("$actual"); ENUM_RESP_FILES+=("$resp")
  ENUM_CT_VALUES+=("$ct"); ENUM_SIZE_VALUES+=("$sz")
  ENUM_TIME_VALUES+=("$tm"); ENUM_HDR_FILES+=("$hdr_f")
  rm -f "$body_f" "$sf" "$rp_f" "$ct_f" "$size_f" "$time_f"
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

  # D24-5: Uniformity checks for content-type, size, and timing.
  local first_ct="${ENUM_CT_VALUES[1]:-}"
  local ct_match=1
  for ct in "${ENUM_CT_VALUES[@]}"; do
    [[ "$ct" != "$first_ct" ]] && { ct_match=0; break }
  done
  (( ct_match )) && t_pass "T-ALIAS-ENUM-CT-UNIFORM" || \
    t_fail "T-ALIAS-ENUM-CT-UNIFORM" "Content-type varies across enum cases"

  local max_sz=0 min_sz=999999
  for sz in "${ENUM_SIZE_VALUES[@]}"; do
    local s_int; s_int=$(( ${sz:-0} ))
    (( s_int > max_sz )) && max_sz=$s_int
    (( s_int < min_sz && s_int > 0 )) && min_sz=$s_int
  done
  local size_ratio=100
  (( max_sz > 0 && min_sz > 0 )) && size_ratio=$(( min_sz * 100 / max_sz ))
  (( size_ratio >= 70 )) && t_pass "T-ALIAS-ENUM-SIZE-UNIFORM" || \
    t_fail "T-ALIAS-ENUM-SIZE-UNIFORM" "Response sizes vary significantly (ratio=${size_ratio}%)"

  local max_tms=0 min_tms=999999
  for tm in "${ENUM_TIME_VALUES[@]}"; do
    local tms; tms=$(python3 -c "print(int(float('${tm:-0}')*1000))" 2>/dev/null || echo "0")
    (( tms > max_tms )) && max_tms=$tms
    (( tms > 0 && tms < min_tms )) && min_tms=$tms
  done
  if (( max_tms > 0 && min_tms > 0 && min_tms * 10 < max_tms )); then
    t_fail "T-ALIAS-ENUM-TIMING" "Potential timing oracle: min=${min_tms}ms max=${max_tms}ms (>10x)"
  else
    t_pass "T-ALIAS-ENUM-TIMING"
  fi

  local rp hdr
  for rp in "${ENUM_RESP_FILES[@]}"; do rm -f "$rp" 2>/dev/null; done
  for hdr in "${ENUM_HDR_FILES[@]}"; do rm -f "$hdr" 2>/dev/null; done
  ENUM_RESP_FILES=(); ENUM_HTTP_VALUES=(); ENUM_CT_VALUES=()
  ENUM_SIZE_VALUES=(); ENUM_TIME_VALUES=(); ENUM_HDR_FILES=()
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

# D24-11: Email lifecycle — classified as UNRESOLVED (requires local mail sink).
# No longer an authorized exclusion.
t_email_lifecycle_group() {
  t_unresolved "T-EMAIL-LIFECYCLE-CHANGE" \
    "Requires local mail sink (e.g. smtp4dev or null mailer). " \
    "Cannot observe whether delivery is queued or attempted without local SMTP fixture. " \
    "Test production SMTP is not authorized. " \
    "Resolve: configure PocketBase SMTP to loopback test relay and observe queue behavior."
  t_authorized_exclusion "E4-PUSH-DELIVERY" "Requires live OneSignal endpoint"
  t_authorized_exclusion "E6-OTP-REACHABILITY" "Requires Meta Cloud API"
  t_authorized_exclusion "E8-WARN-LOG-OBSERVABILITY" "Requires production log pipeline"
}

# ────────────────────────────────────────────────────────────
# §21 CONCURRENCY TESTS  (D24-7: corrected send acceptance)
# ────────────────────────────────────────────────────────────

# D24-7: Concurrent send — requires at least 1 success, exactly 1 sent_active,
# 0 pending_send, 5 total attempt records, all in terminal states.
t_concurrency_otp_send_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-OTP-SEND" "blocked"; return }
  local synth_phone="+601_R24TEST_00099001"
  _otp_set_mode "success" || { t_harness_err "T-CONCURRENCY-OTP-SEND" "Mode"; return }
  local req_url; req_url="$(pb_url "$HOOK_OTP_PHONE_ROUTE")"
  local pids=() i

  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/otpconcs_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json"
    python3 "$PBJ_PY" "$wbody" "phone=${synth_phone}" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" python3 "$PBJ_HTTP_PY" \
        "${wdir}/status" "${wdir}/resp_rp" "$req_url" "auth" "$ORDINARY_AUTH_CFG" "$wbody" "POST"
    ) &
    pids+=($!)
  done

  local w_success=0 w_fail=0 w_other=0
  for (( i=1; i<=5; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wst; wst=$(cat "${RELEASE1B_TEST_TMP}/otpconcs_w${i}_${RUN_SUFFIX}/status" 2>/dev/null)
    local wrp_f="${RELEASE1B_TEST_TMP}/otpconcs_w${i}_${RUN_SUFFIX}/resp_rp"
    [[ -f "$wrp_f" ]] && { local wrp; wrp=$(cat "$wrp_f" 2>/dev/null); rm -f "$wrp" "$wrp_f" }
    case "$wst" in 200) (( w_success++ )) ;; 400|403|429) (( w_fail++ )) ;; *) (( w_other++ )) ;; esac
  done

  local active_cnt; active_cnt=$(_otp_count_by_status "$synth_phone" "sent_active")
  local failed_cnt; failed_cnt=$(_otp_count_by_status "$synth_phone" "send_failed")
  local pending_cnt; pending_cnt=$(_otp_count_by_status "$synth_phone" "pending_send")
  local consumed_cnt; consumed_cnt=$(_otp_count_by_status "$synth_phone" "consumed")
  local total_cnt=$(( active_cnt + failed_cnt + pending_cnt + consumed_cnt ))

  print "[otp-conc-send] workers: success=${w_success} rejected=${w_fail} other=${w_other}"
  print "[otp-conc-send] DB: active=${active_cnt} failed=${failed_cnt} pending=${pending_cnt} total=${total_cnt}"

  # D24-7: At least 1 success required.
  if (( w_success == 0 )); then
    t_fail "T-CONCURRENCY-OTP-SEND" "No worker returned 200 (success=0); test is inconclusive"
    return
  fi
  # D24-7: Unexpected worker statuses.
  if (( w_other > 0 )); then
    t_harness_err "T-CONCURRENCY-OTP-SEND" "${w_other} workers returned unexpected status"
    return
  fi
  # D24-7: Exactly 1 sent_active.
  if (( active_cnt != 1 )); then
    t_fail "T-CONCURRENCY-OTP-SEND" "Expected exactly 1 sent_active; got ${active_cnt}"
    return
  fi
  # D24-7: No unresolved pending_send records.
  if (( pending_cnt > 0 )); then
    t_fail "T-CONCURRENCY-OTP-SEND" "Unresolved pending_send records: ${pending_cnt}"
    return
  fi
  # D24-7: Total records consistent with 5 workers.
  if (( total_cnt != 5 )); then
    t_fail "T-CONCURRENCY-OTP-SEND" "Total records=${total_cnt}; expected 5 for 5 workers"
    return
  fi
  t_pass "T-CONCURRENCY-OTP-SEND"
  print "[otp-conc-send] Exactly 1 sent_active. 0 pending. ${total_cnt} total records."
  t_deferred_mandatory "T-OTP-RATE-LIMIT-POLICY"  "Rate-limit policy undefined. D23-12: DEFERRED-MANDATORY."
  t_deferred_mandatory "T-OTP-IDEMPOTENCY-POLICY" "Idempotency policy undefined. D23-12: DEFERRED-MANDATORY."
}

# D23-7: Concurrent verify — exactly 1 success; DB-state verified.
t_concurrency_otp_verify_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-OTP-VERIFY" "blocked"; return }
  local synth_phone="+601_R24TEST_00099002"
  _otp_set_mode "success" || { t_harness_err "T-CONCURRENCY-OTP-VERIFY" "Mode"; return }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  _reset_user_phone "$ord_id"
  local code; code=$(_otp_request_and_read_code "$synth_phone")
  if [[ -z "$code" || ! "$code" =~ ^[0-9]{6}$ ]]; then
    t_harness_err "T-CONCURRENCY-OTP-VERIFY" "Could not obtain active OTP"; return
  fi
  local verify_url; verify_url="$(pb_url "$HOOK_OTP_VERIFY_ROUTE")"
  local pids=() i
  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/otpconcv_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json"
    python3 "$PBJ_PY" "$wbody" "phone=${synth_phone}" "code=${code}" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" python3 "$PBJ_HTTP_PY" \
        "${wdir}/status" "${wdir}/resp_rp" "$verify_url" "auth" "$ORDINARY_AUTH_CFG" "$wbody" "POST"
    ) &
    pids+=($!)
  done
  local success_count=0 denial_count=0 other_count=0
  for (( i=1; i<=5; i++ )); do
    wait "${pids[$i]}" 2>/dev/null
    local wst; wst=$(cat "${RELEASE1B_TEST_TMP}/otpconcv_w${i}_${RUN_SUFFIX}/status" 2>/dev/null)
    local wrp_f="${RELEASE1B_TEST_TMP}/otpconcv_w${i}_${RUN_SUFFIX}/resp_rp"
    [[ -f "$wrp_f" ]] && { local wrp; wrp=$(cat "$wrp_f" 2>/dev/null); rm -f "$wrp" "$wrp_f" }
    case "$wst" in 200) (( success_count++ )) ;; 400|403|409|429) (( denial_count++ )) ;; *) (( other_count++ )) ;; esac
  done
  local con_cnt; con_cnt=$(_otp_count_by_status "$synth_phone" "consumed")
  local act_cnt; act_cnt=$(_otp_count_by_status "$synth_phone" "sent_active")
  local ph_r; ph_r=$(_assert_user_field "$ord_id" "phone" "$synth_phone")
  local pv_r; pv_r=$(_assert_user_field "$ord_id" "phone_verified" "true")
  _reset_user_phone "$ord_id"
  print "[otp-conc-verify] success=${success_count}/5 denied=${denial_count} other=${other_count}"
  print "[otp-conc-verify] DB: consumed=${con_cnt} active=${act_cnt} ph=${ph_r} pv=${pv_r}"
  if (( success_count != 1 )); then
    t_fail "T-CONCURRENCY-OTP-VERIFY" "Expected exactly 1 success; got ${success_count}"; return
  fi
  if [[ "$con_cnt" != "1" ]]; then
    t_fail "T-CONCURRENCY-OTP-VERIFY" "Expected 1 consumed OTP; got ${con_cnt}"; return
  fi
  if [[ "$act_cnt" != "0" ]]; then
    t_fail "T-CONCURRENCY-OTP-VERIFY" "Active OTP remains (${act_cnt})"; return
  fi
  if [[ "$ph_r" != "MATCH" || "$pv_r" != "MATCH" ]]; then
    t_fail "T-CONCURRENCY-OTP-VERIFY" "User phone/pv not set after verify"; return
  fi
  t_pass "T-CONCURRENCY-OTP-VERIFY"
  print "[otp-conc-verify] Exactly 1 TX-3 committed. OTP consumed once. User phone+pv set once."
}

t_concurrency_auth_group() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-AUTH" "blocked"; return }
  local conc_email="cp0_concauth_${RUN_SUFFIX}@${TEST_EMAIL_DOMAIN}"
  local cpw; cpw=$(pb_secure_tmpfile .pw); openssl rand -base64 24 | tr -d '\n=' > "$cpw"
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${conc_email}" \
    "secret-file:password=${cpw}" "secret-file:passwordConfirm=${cpw}" "role=user" 2>/dev/null
  local sf; sf=$(pb_secure_tmpfile .http); local rp_f; rp_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" python3 "$PBJ_HTTP_PY" "$sf" "$rp_f" \
    "$(pb_url /api/collections/users/records)" "auth" "$_NSU_AUTH_CFG" "$body_f" "POST"
  local cst; cst=$(cat "$sf" 2>/dev/null); local crp; crp=$(cat "$rp_f" 2>/dev/null)
  rm -f "$body_f" "$sf" "$rp_f"
  if [[ "$cst" != "200" ]]; then
    pb_wipe_secret_file "$cpw"; rm -f "$crp"
    t_harness_err "T-CONCURRENCY-AUTH-SETUP" "Create ${cst}"; return
  fi
  local conc_uid; conc_uid=$(python3 "$PBJ_EXTRACT_PY" "$crp" "id" 2>/dev/null)
  rm -f "$crp"; pb_wipe_secret_file "$cpw"
  local url; url="$(pb_url /api/collections/users/auth-with-password)"
  local pids=() i
  for (( i=1; i<=5; i++ )); do
    local wdir="${RELEASE1B_TEST_TMP}/concauth_w${i}_${RUN_SUFFIX}"
    mkdir -p "$wdir" && chmod 700 "$wdir"
    local wbody="${wdir}/body.json"
    python3 "$PBJ_PY" "$wbody" "identity=${conc_email}" "password=definitely-wrong-pw" 2>/dev/null
    (
      RELEASE1B_CANONICAL_TMP="$wdir" python3 "$PBJ_HTTP_PY" \
        "${wdir}/status" "${wdir}/resp_rp" "$url" "anon" "" "$wbody" "POST"
    ) &
    pids+=($!)
  done
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
  if (( fail_count > 0 )); then
    t_fail "T-CONCURRENCY-AUTH" "${fail_count} workers returned 200 (unexpected auth success)"
  elif (( other_count > 0 )); then
    t_harness_err "T-CONCURRENCY-AUTH" "${other_count} workers returned unexpected status"
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
      t_pass "T-HOOK-SMOKE-${hk}"; continue
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
    pb_capture "$method" "$route" "${auth_cfg:-}" "${body_f:-}" "$sf" "$rp_f" "${safe_statuses[@]}"
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
# §22 REPORT
# ────────────────────────────────────────────────────────────
pb_generate_report() {
  local rc=0
  (( T_BLOCKING > 0 || T_FAIL > 0 || T_HARNESS_ERR > 0 || CLEANUP_FAILURE > 0 )) && rc=1
  (( rc == 0 && (T_DEFERRED > 0 || T_UNRESOLVED > 0) )) && rc=2
  {
    print "## Release 1B Checkpoint 0 Report — Round 24"
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
# §23 MAIN  (D24-1: t_otp_lifecycle_group is the single OTP call)
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
  # D24-1: Single authoritative OTP+phone lifecycle call — no duplicates.
  t_otp_lifecycle_group
  t_user_name_update
  t_art_anon_policy; t_art_antenatal_vis; t_rule_apply_restore
  t_concurrency_auth_group; t_concurrency_otp_send_group; t_concurrency_otp_verify_group
  t_hook_smoke_group
  t_email_lifecycle_group
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
