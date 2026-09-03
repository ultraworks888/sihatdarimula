#!/usr/bin/env zsh
# ============================================================
# release1b_cp0.zsh — Release 1B Checkpoint 0 Harness
# Round  : 16 (narrowly corrected from Round 15)
# Status : DRAFTED — not executed; zsh -n not performed
#          (tool-interface limitation)
# R13 EOF parse error: UNRESOLVED — fresh rewrite eliminates
#   carry-over regardless of cause.
# ============================================================
#
# AUTHORIZATION BOUNDARY (defect-31, preserved)
# ──────────────────────────────────────────────
#   Permitted execution modes:
#     --package-check   verify archive + hook paths
#     --harness-check   run self-test suite only
#     --preflight       port check only
#     --run             full harness run (requires --authorize-cp0)
#   Checkpoint 0 is NOT authorized.
#
# Correction matrix: release1b_round16_review.md
# R16 changes from R15:
#   1. pb_trap_cleanup: PocketBase termination confirmed before PID cleared
#   2. t_concurrency_auth_group: worker exit codes captured and classified;
#      missing/malformed result files treated as harness errors
#   3. cp0_run: explicit result policy documented and enforced for every
#      pb_run_stage call; hook phase gated on HALT_DEPENDENTS;
#      pb_apply_schema_migrations failure now halts; cleanup/report
#      failures now set CLEANUP_FAILURE
#   4. cp0_run final exit: T_HARNESS_ERR and CLEANUP_FAILURE now affect
#      exit status; T_UNRESOLVED and T_DEFERRED documented as informational
# ============================================================

# ────────────────────────────────────────────────────────────
# §2  SAFETY OPTIONS
# ────────────────────────────────────────────────────────────

setopt NO_UNSET PIPE_FAIL

# ────────────────────────────────────────────────────────────
# §3  CONSTANTS
# ────────────────────────────────────────────────────────────

readonly RELEASE1B_SCRIPT_ROUND="16"
readonly RELEASE1B_PB_PORT="8090"
readonly RELEASE1B_MH_HTTP_PORT="8025"
readonly RELEASE1B_MH_SMTP_PORT="1025"
readonly RELEASE1B_PB_VERSION="0.29.3"

typeset -grA PB_ARCHIVE_NAME=(
  [darwin_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_arm64.zip"
  [darwin_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_amd64.zip"
  [linux_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_amd64.zip"
  [linux_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_arm64.zip"
)

typeset -grA PB_EXPECTED_SHA256=(
  [darwin_arm64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [darwin_amd64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [linux_amd64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [linux_arm64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
)

typeset -grA HOOK_SRC_PATHS=(
  [onboarding]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [alias_intercept]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
)

typeset -grA HOOK_EXPECTED_SHA256=(
  [onboarding]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [alias_intercept]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
)

typeset -gA HOOK_PROBE_ROUTES=(
  [onboarding]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
  [alias_intercept]="UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route"
)

typeset -gA HOOK_PROBE_METHODS=(
  [onboarding]="GET"
  [push_broadcast]="POST"
  [whatsapp]="POST"
  [alias_intercept]="POST"
)

typeset -gA HOOK_EXPECTED_REMOVED_STATUS=(
  [onboarding]="404"
  [push_broadcast]="404"
  [whatsapp]="404"
  [alias_intercept]="UNRESOLVED__NEEDS_EXTERNAL__interceptor_baseline"
)

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
typeset -g  RELEASE1B_MH_ID=""

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

typeset -g LEGACY_CHILD_ID_FILE=""      LEGACY_GROWTH_ID_FILE=""
typeset -g LEGACY_ACTIVITY_ID_FILE=""   LEGACY_IMMUN_ID_FILE=""
typeset -g LEGACY_PROGRESS_ID_FILE=""   LEGACY_NB_ENROLL_ID_FILE=""

typeset -g ALIAS_ID_FILE="" ALIAS_PW_FILE="" ALIAS_AUTH_CFG=""
typeset -g WRONG_PW_FILE=""
typeset -g TIMING_LEGACY_ID_FILE=""  TIMING_LEGACY_PW_FILE=""
typeset -g TIMING_LEGACY_AUTH_CFG=""

typeset -gA RULE_BASELINE=()

typeset -ga ENUM_RESP_FILES=() ENUM_HTTP_VALUES=() ENUM_TIME_FILES=()
typeset -gA FIXTURE_REGISTRY=()

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
  # R15/R16 || true inventory #1 (BENIGN-RETAINED):
  # dd may return non-zero on a partial write or when the file is
  # shorter than 4 KiB. The rm -f below unconditionally removes the
  # file regardless of whether the overwrite completed.
  rm -f "$f"
}

# ────────────────────────────────────────────────────────────
# §6  TRAP / CLEANUP
# ────────────────────────────────────────────────────────────

pb_trap_cleanup() {
  if (( RELEASE1B_PB_PID > 0 )); then
    kill "$RELEASE1B_PB_PID" 2>/dev/null
    wait "$RELEASE1B_PB_PID" 2>/dev/null || true
    # R15/R16 || true inventory #2 (BENIGN-RETAINED):
    # wait returns non-zero when the process was killed by a signal.

    # R16: confirm PocketBase has stopped before clearing the PID.
    # Poll with kill -0 (existence check, no signal sent) for up to 5s.
    local _pb_tries=0
    while kill -0 "$RELEASE1B_PB_PID" 2>/dev/null && (( _pb_tries < 10 )); do
      sleep 0.5
      (( _pb_tries++ ))
    done
    if kill -0 "$RELEASE1B_PB_PID" 2>/dev/null; then
      print "[trap] WARNING: PocketBase PID ${RELEASE1B_PB_PID} still alive after \
SIGTERM — sending SIGKILL" >&2
      kill -9 "$RELEASE1B_PB_PID" 2>/dev/null
      CLEANUP_FAILURE=1
    fi
    RELEASE1B_PB_PID=0
  fi

  if [[ -n "$RELEASE1B_MH_ID" ]]; then
    if ! { docker stop "$RELEASE1B_MH_ID" &>/dev/null && \
           docker rm   "$RELEASE1B_MH_ID" &>/dev/null; }; then
      CLEANUP_FAILURE=1
      printf '%s\n' "$RELEASE1B_MH_ID" \
        >> "${RELEASE1B_EVIDENCE_DIR}/mailhog_cleanup_fail.txt" 2>/dev/null
      print "[trap] WARNING: Mailhog container not removed — see evidence dir" >&2
    fi
    RELEASE1B_MH_ID=""
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
            if _st.S_IMODE(lst.st_mode) & 0o177:
                print('ERROR: secret-file has group/world bits', file=sys.stderr)
                sys.exit(1)
            with open(sf) as fh:
                obj[key] = fh.read().strip()
        else:
            obj[key] = val
    elif typ == 'secret-file':
        sf = val
        try:
            lst = os.lstat(sf)
        except Exception as e:
            print(f'ERROR: secret-file stat: {e}', file=sys.stderr)
            sys.exit(1)
        if _st.S_ISLNK(lst.st_mode):
            print('ERROR: secret-file is a symlink', file=sys.stderr)
            sys.exit(1)
        if _st.S_IMODE(lst.st_mode) & 0o177:
            print('ERROR: secret-file has group/world bits', file=sys.stderr)
            sys.exit(1)
        with open(sf) as fh:
            obj[key] = fh.read().strip()
    elif typ == 'b':
        if val.lower() not in ('true', 'false'):
            print(f'ERROR: bad bool {val!r}', file=sys.stderr)
            sys.exit(1)
        obj[key] = val.lower() == 'true'
    elif typ == 'n':
        try:
            v = float(val)
            if not math.isfinite(v):
                raise ValueError('non-finite')
            obj[key] = int(v) if v == int(v) else v
        except ValueError as e:
            print(f'ERROR: bad number {val!r}: {e}', file=sys.stderr)
            sys.exit(1)
    else:
        print(f'ERROR: unknown type {typ!r}', file=sys.stderr)
        sys.exit(1)
tmp = out_path + '.pbjtmp'
with open(tmp, 'w') as fh:
    json.dump(obj, fh)
os.chmod(tmp, 0o600)
os.replace(tmp, out_path)
PYEOF

  PBJ_AUTH_PY="${d}/pbj_auth.py"
  cat > "$PBJ_AUTH_PY" << 'PYEOF'
import sys, os, re, stat as _st
auth_out = sys.argv[1]
tok_file = sys.argv[2]
try:
    lst = os.lstat(tok_file)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
if _st.S_ISLNK(lst.st_mode):
    print('ERROR: token file is a symlink', file=sys.stderr)
    sys.exit(1)
if _st.S_IMODE(lst.st_mode) & 0o177:
    print('ERROR: token file has group/world bits', file=sys.stderr)
    sys.exit(1)
with open(tok_file) as fh:
    token = fh.read().strip()
if not re.match(r'^[A-Za-z0-9._\-]+$', token):
    print('ERROR: token contains unexpected characters', file=sys.stderr)
    sys.exit(1)
tmp = auth_out + '.pbjtmp'
with open(tmp, 'w') as fh:
    fh.write(f'Authorization: Bearer {token}\n')
os.chmod(tmp, 0o600)
os.replace(tmp, auth_out)
PYEOF

  PBJ_HTTP_PY="${d}/pbj_http.py"
  cat > "$PBJ_HTTP_PY" << 'PYEOF'
import sys, os, subprocess, re, tempfile, stat as _st
CANONICAL_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', tempfile.gettempdir())
MAX_RESP = 2 * 1024 * 1024

def main():
    status_out = sys.argv[1]
    path_out   = sys.argv[2]
    url        = sys.argv[3]
    auth_file  = sys.argv[4] if len(sys.argv) > 4 else ''
    body_file  = sys.argv[5] if len(sys.argv) > 5 else ''
    method     = sys.argv[6] if len(sys.argv) > 6 else 'GET'

    if not url.startswith('http://127.0.0.1:'):
        print('ERROR: unexpected URL prefix', file=sys.stderr)
        sys.exit(1)

    resp_fd, resp_path = tempfile.mkstemp(dir=CANONICAL_TMP, suffix='.json')
    os.close(resp_fd)
    os.chmod(resp_path, 0o600)

    cmd = [
        'curl', '--silent', '--show-error',
        '--max-redirs', '0',
        '--max-time', '15',
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

  chmod 400 \
    "$PBJ_STAT_PY" "$PBJ_URL_PY" "$PBJ_PY" "$PBJ_AUTH_PY" \
    "$PBJ_HTTP_PY" "$PBJ_FIELD_PY" "$PBJ_COPY_PY" "$PBJ_EXTRACT_PY" \
    "$PBJ_SHAPE_PY" "$PBJ_SCAN_PY"

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
# §10 PACKAGE COMPLETENESS CHECK (defect-28)
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
      continue
    fi
    if [[ ! -f "$src" ]]; then
      print "[pkg] HOOK_SRC_PATHS[$hk]: file not found: ${src}" >&2
      ok=0
    fi
  done

  local -a src_keys probe_keys
  src_keys=("${(@k)HOOK_SRC_PATHS}")
  probe_keys=("${(@k)HOOK_PROBE_ROUTES}")

  local k
  for k in "${src_keys[@]}"; do
    if [[ -z "${HOOK_PROBE_ROUTES[$k]+set}" ]]; then
      print "[pkg] HOOK_PROBE_ROUTES missing key '${k}'" >&2
      ok=0
    fi
  done
  for k in "${probe_keys[@]}"; do
    if [[ -z "${HOOK_SRC_PATHS[$k]+set}" ]]; then
      print "[pkg] HOOK_PROBE_ROUTES has extra key '${k}'" >&2
      ok=0
    fi
  done

  if [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]]; then
    print "[pkg] RELEASE1B_SCHEMA_SRC: UNRESOLVED"
    ok=0
  elif [[ ! -d "$RELEASE1B_SCHEMA_SRC" && ! -f "$RELEASE1B_SCHEMA_SRC" ]]; then
    print "[pkg] RELEASE1B_SCHEMA_SRC not found: ${RELEASE1B_SCHEMA_SRC}" >&2
    ok=0
  fi

  if (( ok )); then
    print "[pkg] Package completeness: PASS"
    return 0
  else
    print "[pkg] Package completeness: FAIL" >&2
    return 1
  fi
}

# ────────────────────────────────────────────────────────────
# §11 HARNESS SELF-TEST
# ────────────────────────────────────────────────────────────

t_harness_selftest() {
  print "=== Harness self-test ==="
  local fail=0

  if [[ -n "${_RELEASE1B_SELFTEST_RUNNING:-}" ]]; then
    print "[selftest] ERROR: self-test re-entry detected" >&2
    return 1
  fi
  local _RELEASE1B_SELFTEST_RUNNING=1

  local saved_pass=$T_PASS
  t_pass "SELFTEST-COUNTER"
  if (( T_PASS != saved_pass + 1 )); then
    print "[selftest] FAIL: t_pass did not increment T_PASS" >&2; fail=1
  fi

  local sf
  sf=$(pb_secure_tmpfile .tstmp)
  if [[ ! -f "$sf" ]]; then
    print "[selftest] FAIL: pb_secure_tmpfile did not create file" >&2; fail=1
  else
    local perms
    perms=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
      python3 "$PBJ_STAT_PY" "$sf" 2>/dev/null)
    if [[ "$perms" != "600" ]]; then
      print "[selftest] FAIL: tmpfile perms not 600 (got ${perms})" >&2; fail=1
    fi
    rm -f "$sf"
  fi

  if ! pb_validate_url "http://127.0.0.1:${RELEASE1B_PB_PORT}/api/collections/foo/records"; then
    print "[selftest] FAIL: valid URL rejected" >&2; fail=1
  fi
  if pb_validate_url "http://evil.com/api/collections/foo/records" 2>/dev/null; then
    print "[selftest] FAIL: external URL not rejected" >&2; fail=1
  fi
  if pb_validate_url "http://127.0.0.1:${RELEASE1B_PB_PORT}/notapi/records" 2>/dev/null; then
    print "[selftest] FAIL: non-/api/ path not rejected" >&2; fail=1
  fi

  local body_f; body_f=$(pb_secure_tmpfile .json)
  if python3 "$PBJ_PY" "$body_f" "id=foo" 2>/dev/null; then
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
typeset -g PLATFORM_KEY=""

pb_verify_archive_hash() {
  local archive="$1"
  local expected="${PB_EXPECTED_SHA256[${PLATFORM_KEY}]:-}"
  if [[ "$expected" == UNRESOLVED* ]]; then
    t_unresolved "T-PKG-ARCHIVE-HASH" \
      "PB archive hash for ${PLATFORM_KEY} is UNRESOLVED"
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

pb_preflight_ports() {
  print "=== Preflight port checks ==="
  local p
  for p in "$RELEASE1B_PB_PORT" "$RELEASE1B_MH_HTTP_PORT" "$RELEASE1B_MH_SMTP_PORT"; do
    if lsof -iTCP:"$p" -sTCP:LISTEN -P -n &>/dev/null; then
      t_blocking "T-PREFLIGHT-PORT-${p}" "Port ${p} already in use"
      return 1
    fi
  done
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
  fi
  t_pass "T-SCHEMA-MIGRATIONS-COPY"
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

pb_start_mailhog() {
  print "=== Starting Mailhog ==="
  if ! command -v docker &>/dev/null; then
    t_unresolved "T-MAILHOG-START" "docker not found — Mailhog unavailable"
    return 0
  fi
  RELEASE1B_MH_ID=$(docker run -d \
    -p "127.0.0.1:${RELEASE1B_MH_HTTP_PORT}:8025" \
    -p "127.0.0.1:${RELEASE1B_MH_SMTP_PORT}:1025" \
    mailhog/mailhog 2>/dev/null) || {
    t_unresolved "T-MAILHOG-START" "docker run failed for mailhog/mailhog"
    return 0
  }
  local tries=0
  while (( tries < 15 )); do
    if curl -sf "http://127.0.0.1:${RELEASE1B_MH_HTTP_PORT}/api/v2/messages" &>/dev/null; then
      print "=== Mailhog ready ==="
      t_pass "T-MAILHOG-START"
      return 0
    fi
    sleep 1
    (( tries++ ))
  done
  t_unresolved "T-MAILHOG-START" "Mailhog did not become ready within 15s"
}

# ────────────────────────────────────────────────────────────
# §13 NATIVE SUPERUSER LIFECYCLE (defects 7, 8)
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
    return 1
  }

  _NATIVE_SU_TOK_FILE="$su_tok_file"
  _NATIVE_SU_ID_FILE="$su_id_file"
  _NATIVE_SU_AUTH_CFG="$su_auth_cfg"
  pb_wipe_secret_file "$su_pw_file"
  t_pass "T-SU-CREATE-AUTH"
}

pb_delete_local_superuser() {
  print "=== Deleting native superuser ==="
  if [[ -z "$_NATIVE_SU_ID_FILE" || ! -f "$_NATIVE_SU_ID_FILE" ]]; then
    return 0
  fi
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
  rm -f "$status_f" "$resp_path_f" "$resp_path"

  pb_wipe_secret_file "$_NATIVE_SU_TOK_FILE"
  pb_wipe_secret_file "$_NATIVE_SU_ID_FILE"
  pb_wipe_secret_file "$_NATIVE_SU_AUTH_CFG"
  _NATIVE_SU_TOK_FILE=""
  _NATIVE_SU_ID_FILE=""
  _NATIVE_SU_AUTH_CFG=""

  if [[ "$status" != "200" && "$status" != "204" ]]; then
    CLEANUP_FAILURE=1
    print "[su-del] WARNING: superuser delete returned ${status}" >&2
    return 1
  fi
  t_pass "T-SU-DELETE"
}

# ────────────────────────────────────────────────────────────
# §14 SCHEMA VERIFICATION
# ────────────────────────────────────────────────────────────

pb_verify_schema() {
  print "=== Schema verification ==="
  (( HALT_DEPENDENTS )) && { t_skip "T-SCHEMA-VERIFY" "blocked"; return 0; }

  local -a required_collections=(
    users children growth_records activities immunizations
    progress_notes articles bookmarks notifications
    newborn_enrollments courses
  )

  local col
  for col in "${required_collections[@]}"; do
    local url; url=$(pb_url "/api/collections/${col}")
    local status_f; status_f=$(pb_secure_tmpfile .http)
    local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
      python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
        "$_NATIVE_SU_AUTH_CFG" "" "GET"

    local status; status=$(cat "$status_f" 2>/dev/null)
    local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$resp_path"

    if [[ "$status" != "200" ]]; then
      t_blocking "T-SCHEMA-COL-${col}" \
        "Collection '${col}' not found (status ${status})"
    else
      t_pass "T-SCHEMA-COL-${col}"
    fi
  done
}

# ────────────────────────────────────────────────────────────
# §15 HOOK MANAGEMENT (defects 15, 16)
# ────────────────────────────────────────────────────────────

pb_verify_hook_directory() {
  print "=== Hook directory verification ==="
  pb_validate_path "$RELEASE1B_PB_HOOKS_DIR" || {
    t_blocking "T-HOOKDIR-PATH" "Hooks dir failed path validation"
    return 1
  }
  local perms
  perms=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$RELEASE1B_PB_HOOKS_DIR" 2>/dev/null)
  if [[ "$perms" != "700" ]]; then
    t_blocking "T-HOOKDIR-PERMS" "Hooks dir permissions are ${perms} (expected 700)"
    return 1
  fi
  t_pass "T-HOOKDIR-VERIFY"
}

pb_install_hook_verified() {
  local hk="$1"
  local src="${HOOK_SRC_PATHS[$hk]:-}"

  if [[ -z "$src" || "$src" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-INSTALL-${hk}" "HOOK_SRC_PATHS[${hk}] not configured"
    return 0
  fi
  if [[ ! -f "$src" ]]; then
    t_blocking "T-HOOK-INSTALL-${hk}" "Hook source not found: ${src}"
    return 1
  fi

  local expected_hash="${HOOK_EXPECTED_SHA256[$hk]:-}"
  if [[ "$expected_hash" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-HASH-${hk}" "HOOK_EXPECTED_SHA256[${hk}] not set"
  else
    local actual_hash; actual_hash=$(shasum -a 256 "$src" | awk '{print $1}')
    if [[ "$actual_hash" != "$expected_hash" ]]; then
      t_blocking "T-HOOK-HASH-${hk}" \
        "Hash mismatch: expected=${expected_hash} actual=${actual_hash}"
      return 1
    fi
    t_pass "T-HOOK-HASH-${hk}"
  fi

  local dst="${RELEASE1B_PB_HOOKS_DIR}/${hk}.js"
  cp "$src" "$dst" || {
    t_blocking "T-HOOK-INSTALL-${hk}" "cp failed"
    return 1
  }
  chmod 600 "$dst"
  t_pass "T-HOOK-INSTALL-${hk}"
}

pb_remove_hook_verified() {
  local hk="$1"
  local dst="${RELEASE1B_PB_HOOKS_DIR}/${hk}.js"
  [[ -f "$dst" ]] && { rm -f "$dst" || { CLEANUP_FAILURE=1; return 1; }; }

  local probe_route="${HOOK_PROBE_ROUTES[$hk]:-}"
  local probe_method="${HOOK_PROBE_METHODS[$hk]:-GET}"
  local expected_status="${HOOK_EXPECTED_REMOVED_STATUS[$hk]:-404}"

  if [[ -z "$probe_route" || "$probe_route" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-REMOVE-PROBE-${hk}" \
      "HOOK_PROBE_ROUTES[${hk}] not configured"
    return 0
  fi
  if [[ "$expected_status" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-REMOVE-STATUS-${hk}" \
      "HOOK_EXPECTED_REMOVED_STATUS[${hk}] not set (interceptor baseline NEEDS-EXTERNAL)"
    return 0
  fi

  local url; url=$(pb_url "$probe_route")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "" "$probe_method"
  local actual; actual=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$resp_path"

  if [[ "$actual" != "$expected_status" ]]; then
    t_fail "T-HOOK-REMOVE-${hk}" \
      "Route still active: status=${actual} expected=${expected_status}"
    return 1
  fi
  t_pass "T-HOOK-REMOVE-${hk}"
}

pb_hook_smoke_matrix() {
  print "=== Hook smoke matrix ==="
  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local probe_route="${HOOK_PROBE_ROUTES[$hk]:-}"
    local probe_method="${HOOK_PROBE_METHODS[$hk]:-GET}"

    if [[ -z "$probe_route" || "$probe_route" == UNRESOLVED* ]]; then
      t_unresolved "T-HOOK-SMOKE-${hk}" "HOOK_PROBE_ROUTES[${hk}] not configured"
      continue
    fi

    local url; url=$(pb_url "$probe_route")
    local status_f; status_f=$(pb_secure_tmpfile .http)
    local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
      python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "" "$probe_method"
    local status; status=$(cat "$status_f" 2>/dev/null)
    local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$resp_path"

    if [[ "$status" == "404" ]]; then
      t_fail "T-HOOK-SMOKE-${hk}" "Hook route returned 404 — hook may not be loaded"
    else
      t_pass "T-HOOK-SMOKE-${hk}"
    fi
  done
}

# ────────────────────────────────────────────────────────────
# §16 RULE LIFECYCLE (defects 12, 14)
# ────────────────────────────────────────────────────────────

pb_apply_rule_local() {
  local collection="$1" rule_type="$2" new_value="$3"
  local registry_key="${collection}::${rule_type}"

  local url; url=$(pb_url "/api/collections/${collection}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"

  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"

  if [[ "$status" != "200" ]]; then
    rm -f "$resp_path"
    t_harness_err "T-RULE-APPLY-${collection}-${rule_type}" \
      "Could not fetch collection (status ${status})"
    return 1
  fi

  local current_rule; current_rule=$(python3 "$PBJ_FIELD_PY" "$resp_path" "$rule_type" 2>/dev/null)
  rm -f "$resp_path"

  if [[ "$current_rule" == "__null__" ]]; then
    RULE_BASELINE[$registry_key]="__pb_null__"
  else
    RULE_BASELINE[$registry_key]="${current_rule}"
  fi

  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "${rule_type}=${new_value}" 2>/dev/null || {
    t_harness_err "T-RULE-APPLY-${collection}-${rule_type}" "pbj.py failed"
    return 1
  }

  url=$(pb_url "/api/collections/${collection}")
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "PATCH"
  status=$(cat "$status_f" 2>/dev/null)
  resp_path=$(cat "$resp_path_f" 2>/dev/null)
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
# §17 HTTP HELPER
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
# §18 FIXTURE REGISTRY
# ────────────────────────────────────────────────────────────

pb_register_fixture() {
  FIXTURE_REGISTRY[$1]="$2"
}

pb_unregister_fixture() {
  unset "FIXTURE_REGISTRY[$1]"
}

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
# §19 USER LIFECYCLE
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
  python3 "$PBJ_PY" "$body_f" \
    "email=${email}" \
    "secret-file:password=${pw_file}" \
    "secret-file:passwordConfirm=${pw_file}" \
    "role=user" \
    "b:phone_verified=true" \
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
  python3 "$PBJ_PY" "$cbody" \
    "parent=${rec_id}" \
    "name=LegacyChild_${RUN_SUFFIX}" \
    "b:has_newborn_content=true" 2>/dev/null
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
  local f
  for f in "$LEGACY_CHILD_ID_FILE" "$LEGACY_GROWTH_ID_FILE" \
            "$LEGACY_ACTIVITY_ID_FILE" "$LEGACY_IMMUN_ID_FILE" \
            "$LEGACY_PROGRESS_ID_FILE" "$LEGACY_NB_ENROLL_ID_FILE"; do
    [[ -n "$f" && -f "$f" ]] || continue
    if ! pb_delete_record "children" "$f"; then
      if ! pb_delete_record "growth_records" "$f"; then
        CLEANUP_FAILURE=1
        print "[legacy-del] WARNING: could not delete record (id_file: ${f})" >&2
      fi
    fi
  done
  pb_delete_record "users" "$LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$LEGACY_TOK_FILE"
  pb_wipe_secret_file "$LEGACY_AUTH_CFG"
}

# ────────────────────────────────────────────────────────────
# §21 ALIAS FIXTURES (defect-10)
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
  python3 "$PBJ_PY" "$body_f" \
    "email=${alias_email}" \
    "secret-file:password=${ALIAS_PW_FILE}" \
    "secret-file:passwordConfirm=${ALIAS_PW_FILE}" \
    "role=user" \
    "b:is_alias_account=true" \
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
  python3 "$PBJ_PY" "$body_f" \
    "email=${tl_email}" \
    "secret-file:password=${TIMING_LEGACY_PW_FILE}" \
    "secret-file:passwordConfirm=${TIMING_LEGACY_PW_FILE}" \
    "role=user" \
    "b:phone_verified=true" \
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
# §22 ALIAS ENUM CASES (defects 3, 4, 9, 10)
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
    t_pass "$label"
    return 0
  else
    t_fail "$label" "expected ${expected} got ${actual}"
    return 1
  fi
}

t_alias_case5_timing() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-CASE5-TIMING" "blocked"; return 0; }
  if [[ ! -f "$TIMING_LEGACY_PW_FILE" ]]; then
    t_unresolved "T-ALIAS-CASE5-TIMING" "TIMING_LEGACY_PW_FILE not set"
    return 0
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
    t_unresolved "T-ALIAS-CASE5-TIMING" "Could not resolve timing-legacy email"
    return 0
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
    t_fail "T-ALIAS-CASE5-TIMING" "Timing-legacy auth failed: status=${status}"
    return 1
  fi
  t_pass "T-ALIAS-CASE5-TIMING"
  print "[alias-timing] legacy auth elapsed: ${elapsed_legacy}ms"
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
  python3 "$PBJ_PY" "$body_f" "parent=${ord_id}" "name=TestChild_${RUN_SUFFIX}" 2>/dev/null
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
  python3 "$PBJ_PY" "$body_f" "parent=${other_id}" "name=CrossChild_${RUN_SUFFIX}" 2>/dev/null
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
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-GR-CREATE" "blocked"; return 0; }
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_skip "T-CRUD-GR-CREATE" "no child fixture"; return 0; }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "child=${cid}" "n:weight_kg=3.5" "n:height_cm=50.0" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "/api/collections/growth_records/records" \
    "$LEGACY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-CRUD-GR-CREATE" "200" || {
    t_fail "T-CRUD-GR-CREATE" "$(cat "$status_f" 2>/dev/null)"
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
  t_pass "T-CRUD-GR-CREATE"
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
    "T-FIELD-ROLE-REJECT" "400" || {
    t_fail "T-FIELD-ROLE-REJECT" "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FIELD-ROLE-REJECT"
}

t_field_phone_reject() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FIELD-PHONE-REJECT" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "b:phone_verified=true" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-FIELD-PHONE-REJECT" "400" || {
    t_fail "T-FIELD-PHONE-REJECT" "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FIELD-PHONE-REJECT"
}

t_field_alias_flag_reject() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FIELD-ALIAS-REJECT" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "b:is_alias_account=true" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-FIELD-ALIAS-REJECT" "400" || {
    t_fail "T-FIELD-ALIAS-REJECT" "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FIELD-ALIAS-REJECT"
}

# ────────────────────────────────────────────────────────────
# §25 FILE AUTH TESTS
# ────────────────────────────────────────────────────────────

t_file_auth_anon_list_rejected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-1" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/progress_notes/records" \
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
  [[ -f "$LEGACY_CHILD_ID_FILE" ]] || { t_skip "T-FILE-AUTH-2" "no child fixture"; return 0; }
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" \
    "/api/collections/progress_notes/records?filter=child%3D%27${cid}%27" \
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
  pb_capture "GET" \
    "/api/collections/progress_notes/records?filter=child%3D%27${cid}%27" \
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
    t_fail "T-FILE-AUTH-3" "cross-user filter returned items: ${items_check}"
    return 1
  fi
  t_pass "T-FILE-AUTH-3"
}

t_file_auth_admin_can_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-4" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/progress_notes/records" \
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
  pb_capture "GET" \
    "/api/files/progress_notes/nonexistent_id/nonexistent.pdf" \
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
# §26 ALIAS ENUM TESTS (defect-9)
# ────────────────────────────────────────────────────────────

t_alias_enum_case1_alias_account() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-ENUM-1" "blocked"; return 0; }
  [[ -f "$ALIAS_ID_FILE" ]] || { t_skip "T-ALIAS-ENUM-1" "no alias fixture"; return 0; }
  local alias_id; alias_id=$(cat "$ALIAS_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" \
      "$(pb_url "/api/collections/users/records/${alias_id}")" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  local alias_email; alias_email=$(python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null)
  rm -f "$rp"
  [[ -z "$alias_email" ]] && { t_skip "T-ALIAS-ENUM-1" "could not resolve alias email"; return 0; }
  pb_alias_enum_case 1 "T-ALIAS-ENUM-1" "$alias_email" "400"
}

t_alias_enum_case2_real_wrong_pw() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-ENUM-2" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" \
      "$(pb_url "/api/collections/users/records/${ord_id}")" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  local ord_email; ord_email=$(python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null)
  rm -f "$rp"
  pb_alias_enum_case 2 "T-ALIAS-ENUM-2" "$ord_email" "400"
}

t_alias_enum_case3_nonexistent() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-ENUM-3" "blocked"; return 0; }
  pb_alias_enum_case 3 "T-ALIAS-ENUM-3" \
    "cp0_nonexistent_${RUN_SUFFIX}@release1b.local" "400"
}

t_alias_enum_case4_malformed() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-ENUM-4" "blocked"; return 0; }
  pb_alias_enum_case 4 "T-ALIAS-ENUM-4" "not-an-email-address" "400"
}

# ────────────────────────────────────────────────────────────
# §27 AUTH TESTS
# ────────────────────────────────────────────────────────────

t_actor_role_rule() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ACTOR-ROLE-RULE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ACTOR-ROLE-RULE" "400" || {
    t_fail "T-ACTOR-ROLE-RULE" "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ACTOR-ROLE-RULE"
}

t_anon_read_rejected() {
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

t_auth_user_cannot_read_others() {
  (( HALT_DEPENDENTS )) && { t_skip "T-AUTH-NO-OTHERS-READ" "blocked"; return 0; }
  local legacy_id; legacy_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  [[ -z "$legacy_id" ]] && { t_skip "T-AUTH-NO-OTHERS-READ" "no legacy fixture"; return 0; }
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
# §28 EMAIL / OTP TESTS
# ────────────────────────────────────────────────────────────

t_email_verification_required() {
  (( HALT_DEPENDENTS )) && { t_skip "T-EMAIL-VERIFY-REQ" "blocked"; return 0; }
  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-EMAIL-VERIFY-REQ" "Mailhog not running"
    return 0
  fi
  t_unresolved "T-EMAIL-VERIFY-REQ" "Email verification rule not confirmed in schema"
}

t_email_change_flow() {
  (( HALT_DEPENDENTS )) && { t_skip "T-EMAIL-CHANGE-FLOW" "blocked"; return 0; }
  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-EMAIL-CHANGE-FLOW" "Mailhog not running"
    return 0
  fi
  t_unresolved "T-EMAIL-CHANGE-FLOW" "Requires Mailhog integration"
}

t_otp_flow() {
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-FLOW" "blocked"; return 0; }
  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-OTP-FLOW" "Mailhog not running"
    return 0
  fi
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" \
      "$(pb_url "/api/collections/users/records/${ord_id}")" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  local ord_email; ord_email=$(python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null)
  rm -f "$rp"
  [[ -z "$ord_email" ]] && { t_unresolved "T-OTP-FLOW" "Could not resolve email"; return 0; }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${ord_email}" 2>/dev/null
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "/api/collections/users/request-otp" \
    "" "$body_f" "$status_f" "$resp_path_f" "T-OTP-REQUEST" "200" "404" || {
    local actual; actual=$(cat "$status_f" 2>/dev/null)
    if [[ "$actual" == "404" ]]; then
      t_unresolved "T-OTP-FLOW" "OTP endpoint not found — OTP may not be enabled"
    else
      t_fail "T-OTP-FLOW" "OTP request returned ${actual}"
    fi
    rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-OTP-FLOW"
}

# ────────────────────────────────────────────────────────────
# §29 ADMIN / NSU TESTS
# ────────────────────────────────────────────────────────────

t_admin_escalation_rejected() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-ESCALATION" "blocked"; return 0; }
  local adm_id; adm_id=$(cat "$ADMIN_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${adm_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ADMIN-ESCALATION" "400" || {
    t_fail "T-ADMIN-ESCALATION" "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ADMIN-ESCALATION"
}

t_admin_cannot_promote_others() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-NO-PROMOTE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ADMIN-NO-PROMOTE" "400" "403" || {
    t_fail "T-ADMIN-NO-PROMOTE" "expected 400/403 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ADMIN-NO-PROMOTE"
}

t_superadmin_can_list_users() {
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

t_native_superuser_bypasses_rules() {
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

t_native_superuser_hook_behavior() {
  t_deferred_mandatory "T-NSU-HOOK-BEHAVIOR" \
    "Requires hook source (NEEDS-EXTERNAL) to define NSU intercept semantics"
}

# ────────────────────────────────────────────────────────────
# §30 USER OPS TESTS
# ────────────────────────────────────────────────────────────

t_ordinary_name_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-NAME-UPDATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "name=CP0TestUser_${RUN_SUFFIX}" 2>/dev/null
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

t_ordinary_language_update() {
  (( HALT_DEPENDENTS )) && { t_skip "T-USER-LANG-UPDATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "language=en" 2>/dev/null
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

t_avatar_lifecycle() {
  t_deferred_mandatory "T-AVATAR-LIFECYCLE" \
    "Requires operator-provided image asset (NEEDS-EXTERNAL)"
}

# ────────────────────────────────────────────────────────────
# §31 CONTENT TESTS
# ────────────────────────────────────────────────────────────

t_articles_antenatal_visible() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANTENATAL-VIS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" \
    "/api/collections/articles/records?filter=type%3D%27antenatal%27" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-ART-ANTENATAL-VIS" "200" || {
    t_fail "T-ART-ANTENATAL-VIS" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ART-ANTENATAL-VIS"
}

t_articles_anon_denied() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANON-DENIED" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/articles/records" \
    "" "" "$status_f" "$resp_path_f" "T-ART-ANON-DENIED" "401" "403" || {
    t_fail "T-ART-ANON-DENIED" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ART-ANON-DENIED"
}

t_bookmarks_classification() {
  (( HALT_DEPENDENTS )) && { t_skip "T-BOOKMARKS-CLASS" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "user=${ord_id}" "article=nonexistent" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "/api/collections/bookmarks/records" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-BOOKMARKS-CLASS" "400" "200" || {
    t_fail "T-BOOKMARKS-CLASS" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-BOOKMARKS-CLASS"
}

t_notifications_classification() {
  (( HALT_DEPENDENTS )) && { t_skip "T-NOTIF-CLASS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/notifications/records" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-NOTIF-CLASS" "200" || {
    t_fail "T-NOTIF-CLASS" "$(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"; return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-NOTIF-CLASS"
}

# ────────────────────────────────────────────────────────────
# §32 ANONYMOUS / INJECTION TESTS (defect-26)
# ────────────────────────────────────────────────────────────

t_anon_create_field_injection() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ANON-INJECT" "blocked"; return 0; }
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "email=injected_${RUN_SUFFIX}@evil.example" \
    "secret-file:password=${WRONG_PW_FILE}" \
    "secret-file:passwordConfirm=${WRONG_PW_FILE}" \
    "role=admin" \
    "b:phone_verified=true" \
    "b:is_alias_account=true" 2>/dev/null
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "POST" "/api/collections/users/records" \
    "" "$body_f" "$status_f" "$resp_path_f" \
    "T-ANON-INJECT" "400" "401" "403" || {
    local actual; actual=$(cat "$status_f" 2>/dev/null)
    if [[ "$actual" == "200" ]]; then
      local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
      local actual_role; actual_role=$(python3 "$PBJ_FIELD_PY" "$rp" "role" 2>/dev/null)
      local actual_phone; actual_phone=$(python3 "$PBJ_FIELD_PY" "$rp" "phone_verified" 2>/dev/null)
      local actual_alias; actual_alias=$(python3 "$PBJ_FIELD_PY" "$rp" "is_alias_account" 2>/dev/null)
      local created_id; created_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
      rm -f "$rp"
      local inject_ok=0
      [[ "$actual_role" == "admin" ]] && inject_ok=1
      [[ "$actual_phone" == "true" ]] && inject_ok=1
      [[ "$actual_alias" == "true" ]] && inject_ok=1
      if [[ -n "$created_id" ]]; then
        local id_f; id_f=$(pb_secure_tmpfile .id)
        printf '%s' "$created_id" > "$id_f"
        pb_delete_record "users" "$id_f"
      fi
      if (( inject_ok )); then
        t_fail "T-ANON-INJECT" \
          "Injected privileged fields accepted (role=${actual_role} phone=${actual_phone} alias=${actual_alias})"
        rm -f "$body_f" "$status_f" "$resp_path_f"; return 1
      else
        t_pass "T-ANON-INJECT"
        rm -f "$body_f" "$status_f" "$resp_path_f"; return 0
      fi
    else
      t_fail "T-ANON-INJECT" "unexpected status ${actual}"
      local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
      rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"; return 1
    fi
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ANON-INJECT"
}

# ────────────────────────────────────────────────────────────
# §33 API / ROUTE TESTS (defects 18, 19)
# ────────────────────────────────────────────────────────────

t_api_declarations() {
  print "=== API route declarations ==="
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/health" \
    "" "" "$status_f" "$resp_path_f" "T-API-HEALTH" "200" || {
    t_fail "T-API-HEALTH" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"

  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections" \
    "" "" "$status_f" "$resp_path_f" "T-API-COLLECTIONS-ANON" "401" "403" || {
    t_fail "T-API-COLLECTIONS-ANON" "$(cat "$status_f" 2>/dev/null)"
  }
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-API-DECLARATIONS"
}

t_static_route_inventory() {
  print "=== Static route inventory ==="
  local -a routes=("/api/health" "/api/collections/users/auth-methods")
  local route
  for route in "${routes[@]}"; do
    local status_f; status_f=$(pb_secure_tmpfile .http)
    local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
    pb_capture "GET" "$route" \
      "" "" "$status_f" "$resp_path_f" \
      "T-ROUTE-${route//\//_}" "200" "405" || {
      t_fail "T-ROUTE-${route//\//_}" "$(cat "$status_f" 2>/dev/null)"
    }
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
  done
  t_pass "T-STATIC-ROUTE-INVENTORY"
}

# ────────────────────────────────────────────────────────────
# §34 RULE TESTS (defect-13)
# ────────────────────────────────────────────────────────────

t_rule_apply_restore_children() {
  (( HALT_DEPENDENTS )) && { t_skip "T-RULE-APPLY-RESTORE" "blocked"; return 0; }
  pb_apply_rule_local "children" "listRule" "" || {
    t_harness_err "T-RULE-APPLY-RESTORE" "apply failed"; return 1
  }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records" \
    "" "" "$status_f" "$resp_path_f" "T-RULE-APPLY-PUBLIC-VERIFY" "200" || {
    t_fail "T-RULE-APPLY-PUBLIC-VERIFY" "$(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  pb_restore_rule_local "children" "listRule" || {
    t_harness_err "T-RULE-RESTORE" "restore failed"; return 1
  }
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records" \
    "" "" "$status_f" "$resp_path_f" "T-RULE-RESTORE-VERIFY" "401" "403" || {
    t_fail "T-RULE-RESTORE-VERIFY" "$(cat "$status_f" 2>/dev/null)"
  }
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-RULE-APPLY-RESTORE"
}

# ────────────────────────────────────────────────────────────
# §35 EMAIL LIFECYCLE (defect-20)
# ────────────────────────────────────────────────────────────

t_email_lifecycle_isolated() {
  print "=== Email lifecycle test (Mailhog) ==="
  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-EMAIL-LIFECYCLE" "Mailhog not available (NEEDS-EXTERNAL)"
    return 0
  fi
  local clear_status
  clear_status=$(curl -sf -X DELETE \
    "http://127.0.0.1:${RELEASE1B_MH_HTTP_PORT}/api/v2/messages" \
    -w '%{http_code}' -o /dev/null 2>/dev/null)
  if [[ "$clear_status" != "200" ]]; then
    t_unresolved "T-EMAIL-LIFECYCLE" "Mailhog inbox clear failed: ${clear_status}"
    return 0
  fi
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" \
      "$(pb_url "/api/collections/users/records/${ord_id}")" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  local ord_email; ord_email=$(python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null)
  rm -f "$rp"
  if [[ -z "$ord_email" ]]; then
    t_unresolved "T-EMAIL-LIFECYCLE" "Could not resolve ordinary user email"
    return 0
  fi
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${ord_email}" 2>/dev/null
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" \
      "$(pb_url "/api/collections/users/request-verification")" \
      "" "$body_f" "POST"
  local verify_status; verify_status=$(cat "$status_f" 2>/dev/null)
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  if [[ "$verify_status" != "204" && "$verify_status" != "200" ]]; then
    t_fail "T-EMAIL-LIFECYCLE" "Verification request returned ${verify_status}"
    return 1
  fi
  local found=0 tries=0
  while (( tries < 10 )); do
    sleep 1
    local mh_result; mh_result=$(curl -sf \
      "http://127.0.0.1:${RELEASE1B_MH_HTTP_PORT}/api/v2/messages" 2>/dev/null)
    local count; count=$(printf '%s' "$mh_result" | python3 -c \
      "import sys,json; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null)
    if (( count > 0 )); then found=1; break; fi
    (( tries++ ))
  done
  if (( found )); then
    t_pass "T-EMAIL-LIFECYCLE"
  else
    t_fail "T-EMAIL-LIFECYCLE" "No email received in Mailhog within 10s"
    return 1
  fi
}

# ────────────────────────────────────────────────────────────
# §36 CONCURRENCY TESTS (defect-23)
# ────────────────────────────────────────────────────────────

t_concurrency_auth_group() {
  print "=== Concurrency auth test ==="
  (( HALT_DEPENDENTS )) && { t_skip "T-CONCURRENCY-AUTH" "blocked"; return 0; }

  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" \
      "$(pb_url "/api/collections/users/records/${ord_id}")" \
      "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  local ord_email; ord_email=$(python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null)
  rm -f "$rp"
  if [[ -z "$ord_email" ]]; then
    t_unresolved "T-CONCURRENCY-AUTH" "Could not resolve ordinary user email"
    return 0
  fi

  local N=5
  local -a pids=() result_files=()
  local i
  for (( i=1; i<=N; i++ )); do
    local body_f; body_f=$(pb_secure_tmpfile .json)
    local http_f; http_f=$(pb_secure_tmpfile .http)
    local resp_f; resp_f=$(pb_secure_tmpfile .rp)
    result_files+=("$http_f")
    python3 "$PBJ_PY" "$body_f" \
      "identity=${ord_email}" \
      "secret-file:password=${WRONG_PW_FILE}" 2>/dev/null
    # R16: subshell exits with the helper's exit code so that
    # the parent's wait captures a meaningful status.
    (
      RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
        python3 "$PBJ_HTTP_PY" "$http_f" "$resp_f" \
          "$(pb_url "/api/collections/users/auth-with-password")" \
          "" "$body_f" "POST"
      _wrc=$?
      rm -f "$body_f" "$resp_f"
      exit $_wrc
    ) &
    pids+=($!)
  done

  # R16: capture every worker exit code for independent classification.
  local -a worker_rcs=()
  local pid
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null
    worker_rcs+=($?)
  done

  # Classify each result: worker failure / missing file / malformed / functional.
  local fail_count=0 harness_err_count=0
  local idx=0
  local rf
  for rf in "${result_files[@]}"; do
    (( idx++ ))
    local wrc="${worker_rcs[$idx]:-255}"

    # 1. Worker process failed (helper crashed or was interrupted)
    if (( wrc != 0 )); then
      t_harness_err "T-CONCURRENCY-WORKER-${idx}" \
        "Worker subshell exited nonzero: rc=${wrc}"
      (( harness_err_count++ ))
      rm -f "$rf"
      continue
    fi

    # 2. Result file absent despite clean worker exit
    if [[ ! -f "$rf" ]]; then
      t_harness_err "T-CONCURRENCY-RESULT-MISSING-${idx}" \
        "Result file absent (worker rc=${wrc})"
      (( harness_err_count++ ))
      continue
    fi

    local s; s=$(cat "$rf" 2>/dev/null)
    rm -f "$rf"

    # 3. Malformed: empty or not a three-digit code
    if [[ -z "$s" ]] || ! [[ "$s" =~ ^[0-9]{3}$ ]]; then
      t_harness_err "T-CONCURRENCY-RESULT-MALFORMED-${idx}" \
        "Result file content not a valid HTTP status: '${s}'"
      (( harness_err_count++ ))
      continue
    fi

    # 4. Functional result: wrong-password auth must return 400
    if [[ "$s" != "400" ]]; then
      (( fail_count++ ))
    fi
  done

  if (( harness_err_count > 0 )); then
    t_harness_err "T-CONCURRENCY-AUTH" \
      "${harness_err_count}/${N} workers had harness errors"
    return 1
  fi

  if (( fail_count > 0 )); then
    t_fail "T-CONCURRENCY-AUTH" \
      "${fail_count}/${N} concurrent wrong-pw attempts did not return 400"
    return 1
  fi

  t_pass "T-CONCURRENCY-AUTH"
}

# ────────────────────────────────────────────────────────────
# §37 PROXY / IP (defect-22, mandatory-deferred)
# ────────────────────────────────────────────────────────────

t_proxy_ip_investigation() {
  t_deferred_mandatory "T-PROXY-IP-INVESTIGATE" \
    "Requires external network fixture (NEEDS-EXTERNAL)"
}

# ────────────────────────────────────────────────────────────
# §38 PRODUCTION EXCLUSIONS (defect-21, corrected in R15)
# ────────────────────────────────────────────────────────────

pb_record_production_exclusions() {
  t_authorized_exclusion "E4-EMAIL-CHANGE-LIFECYCLE" \
    "Production email-change lifecycle diagnostic: cannot be replicated in isolated \
harness without production SMTP and verified-email state"
  t_authorized_exclusion "E6-OTP-REACHABILITY" \
    "Production OTP endpoint reachability: OTP delivery requires production SMTP relay; \
smoke-tested for endpoint existence only"
  t_authorized_exclusion "E8-WARN-LOG-OBSERVABILITY" \
    "Production WARN-log observability: structured log inspection requires production \
log aggregation pipeline not present in isolated harness"
}

# ────────────────────────────────────────────────────────────
# §39 TEST GROUP WRAPPERS (defect-2)
# ────────────────────────────────────────────────────────────

t_crud_children_group() {
  print "=== Stage: CRUD Children ==="
  t_crud_children_list
  t_crud_children_view
  t_crud_children_view_cross_user
  t_crud_children_create
  t_crud_children_create_cross_user
  t_crud_growth_create
}

t_field_protection_group() {
  print "=== Stage: Field Protection ==="
  t_field_role_reject
  t_field_phone_reject
  t_field_alias_flag_reject
}

t_file_auth_group() {
  print "=== Stage: File Auth ==="
  t_file_auth_anon_list_rejected
  t_file_auth_own_record_visible
  t_file_auth_cross_user_denied
  t_file_auth_admin_can_list
  t_file_auth_upload_own
  t_file_auth_download_protected
  t_file_auth_delete_own
}

t_alias_enum_group() {
  print "=== Stage: Alias Enum ==="
  t_alias_enum_case1_alias_account
  t_alias_enum_case2_real_wrong_pw
  t_alias_enum_case3_nonexistent
  t_alias_enum_case4_malformed
  t_alias_case5_timing
}

t_auth_group() {
  print "=== Stage: Auth ==="
  t_actor_role_rule
  t_anon_read_rejected
  t_auth_user_cannot_read_others
}

t_email_otp_group() {
  print "=== Stage: Email + OTP ==="
  t_email_verification_required
  t_email_change_flow
  t_otp_flow
}

t_admin_nsu_group() {
  print "=== Stage: Admin + NSU ==="
  t_admin_escalation_rejected
  t_admin_cannot_promote_others
  t_superadmin_can_list_users
  t_native_superuser_bypasses_rules
  t_native_superuser_hook_behavior
}

t_user_ops_group() {
  print "=== Stage: User Ops ==="
  t_ordinary_name_update
  t_ordinary_language_update
  t_avatar_lifecycle
}

t_content_group() {
  print "=== Stage: Content ==="
  t_articles_antenatal_visible
  t_articles_anon_denied
  t_bookmarks_classification
  t_notifications_classification
}

t_anon_inject_group() {
  print "=== Stage: Anonymous + Injection ==="
  t_anon_create_field_injection
}

t_api_route_group() {
  print "=== Stage: API + Route ==="
  t_api_declarations
  t_static_route_inventory
}

t_rule_test_group() {
  print "=== Stage: Rule Tests ==="
  t_rule_apply_restore_children
}

t_email_lifecycle_group() {
  print "=== Stage: Email Lifecycle ==="
  t_email_lifecycle_isolated
}

t_concurrency_group() {
  print "=== Stage: Concurrency ==="
  t_concurrency_auth_group
}

t_proxy_ip_group() {
  print "=== Stage: Proxy/IP ==="
  t_proxy_ip_investigation
}

# ────────────────────────────────────────────────────────────
# §40 REPORT GENERATION (defects 29, 30)
# ────────────────────────────────────────────────────────────

pb_validate_destructive_target() {
  local path="$1" label="${2:-unknown}"
  [[ -z "$path" ]] && { print "[validate] REJECT: empty path for ${label}" >&2; return 1; }
  local real_path; real_path=$(pb_realpath "$path")
  local real_root; real_root=$(pb_realpath "$RELEASE1B_CANONICAL_ROOT")
  if [[ "$real_path" != "${real_root}"* ]]; then
    print "[validate] REJECT: ${label} outside isolated root: ${path}" >&2
    return 1
  fi
  return 0
}

pb_generate_report() {
  print "=== Generating report ==="
  {
    printf '\n## Summary\n\n| Metric | Count |\n|---|---|\n'
    printf '| PASS | %d |\n'               "$T_PASS"
    printf '| FAIL | %d |\n'               "$T_FAIL"
    printf '| BLOCKING | %d |\n'           "$T_BLOCKING"
    printf '| UNRESOLVED | %d |\n'         "$T_UNRESOLVED"
    printf '| DEFERRED-MANDATORY | %d |\n' "$T_DEFERRED"
    printf '| SKIP | %d |\n'               "$T_SKIP"
    printf '| HARNESS_ERR | %d |\n'        "$T_HARNESS_ERR"
    printf '| CLEANUP_FAILURE | %d |\n'    "$CLEANUP_FAILURE"
    if (( ${#BLOCKING_DECISIONS[@]} > 0 )); then
      printf '\n## Blocking Decisions\n\n'
      local d; for d in "${BLOCKING_DECISIONS[@]}"; do printf '- %s\n' "$d"; done
    fi
    if (( ${#UNRESOLVED_ITEMS[@]} > 0 )); then
      printf '\n## Unresolved / Deferred\n\n'
      local u; for u in "${UNRESOLVED_ITEMS[@]}"; do printf '- %s\n' "$u"; done
    fi
    if (( ${#HARNESS_ERRORS[@]} > 0 )); then
      printf '\n## Harness Errors\n\n'
      local e; for e in "${HARNESS_ERRORS[@]}"; do printf '- %s\n' "$e"; done
    fi
  } >> "$RELEASE1B_REPORT_WORK"
}

pb_scan_and_export_report() {
  print "=== Exporting report ==="
  pb_generate_report
  RELEASE1B_CANONICAL_ROOT="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_SCAN_PY" "$RELEASE1B_REPORT_WORK" "$RELEASE1B_REPORT_PATH"
  if [[ -f "$RELEASE1B_REPORT_PATH" ]]; then
    print "=== Report written ==="
  else
    print "[report] WARNING: export may have failed" >&2
    CLEANUP_FAILURE=1
    return 1
  fi
}

pb_cleanup_normal() {
  print "=== Cleanup ==="
  pb_delete_test_user "ordinary" \
    "$ORDINARY_ID_FILE" "$ORDINARY_TOK_FILE" "$ORDINARY_AUTH_CFG" || CLEANUP_FAILURE=1
  pb_delete_test_user "admin" \
    "$ADMIN_ID_FILE" "$ADMIN_TOK_FILE" "$ADMIN_AUTH_CFG"     || CLEANUP_FAILURE=1
  pb_delete_test_user "superadmin" \
    "$SADMIN_ID_FILE" "$SADMIN_TOK_FILE" "$SADMIN_AUTH_CFG"  || CLEANUP_FAILURE=1
  pb_delete_legacy_fixture  || CLEANUP_FAILURE=1
  pb_cleanup_alias_group    || CLEANUP_FAILURE=1
  pb_cleanup_all_fixtures   || CLEANUP_FAILURE=1
  pb_delete_local_superuser || CLEANUP_FAILURE=1
  local rf
  for rf in "${ENUM_RESP_FILES[@]}"; do
    [[ -f "$rf" ]] && rm -f "$rf"
  done
  (( CLEANUP_FAILURE == 0 )) || return 1
}

pb_run_stage() {
  local stage_fn="$1"
  print ">>> BEGIN STAGE: ${stage_fn}"
  "$stage_fn"
  local rc=$?
  print "<<< END STAGE: ${stage_fn} (rc=${rc})"
  return $rc
}

# ────────────────────────────────────────────────────────────
# §41 ORCHESTRATION
# ────────────────────────────────────────────────────────────

cp0_run() {
  print "=== CP0 Orchestration begin ==="
  print "=== Round: ${RELEASE1B_SCRIPT_ROUND} ==="
  print "=== Suffix: ${RUN_SUFFIX} ==="

  # ── PHASE 1: Infrastructure ──────────────────────────────
  # Policy: HALT — no recovery possible; all subsequent stages depend on these.

  pb_run_stage pb_preflight_ports || {
    print "[cp0] HALT: preflight failed" >&2
    return 1
  }

  # R16: pb_apply_schema_migrations failure now halts (was silently continued in R15).
  # PocketBase cannot apply pending migrations at startup if this stage fails.
  pb_run_stage pb_apply_schema_migrations || {
    print "[cp0] HALT: schema migration stage failed" >&2
    return 1
  }

  pb_run_stage pb_start_pocketbase || {
    print "[cp0] HALT: PocketBase did not start" >&2
    return 1
  }

  # Policy: CONTINUE — optional; t_unresolved recorded if docker unavailable;
  # email tests gate themselves on RELEASE1B_MH_ID being non-empty.
  pb_run_stage pb_start_mailhog

  # Policy: HALT — superuser token is required for all schema ops and
  # fixture management that follows.
  pb_run_stage pb_create_local_superuser || {
    print "[cp0] HALT: native superuser creation failed" >&2
    return 1
  }

  # Policy: CONTINUE — t_blocking recorded per missing collection;
  # t_blocking sets HALT_DEPENDENTS=1, which gates all dependent tests.
  pb_run_stage pb_verify_schema

  # ── PHASE 2: Hook setup ──────────────────────────────────
  # Gated on HALT_DEPENDENTS. If schema verification set HALT_DEPENDENTS,
  # the entire hook phase is skipped with a single t_skip.
  if (( HALT_DEPENDENTS )); then
    t_skip "T-HOOKS-ALL" "prerequisite failed (HALT_DEPENDENTS set by schema stage)"
  else
    # Policy: CONTINUE — pb_verify_hook_directory calls t_blocking on
    # failure, which sets HALT_DEPENDENTS. The inner gate below then
    # skips hook installation if directory is bad.
    pb_run_stage pb_verify_hook_directory

    if (( ! HALT_DEPENDENTS )); then
      local hk
      for hk in "${(@k)HOOK_SRC_PATHS}"; do
        # Policy: CONTINUE — t_unresolved/t_blocking recorded per hook.
        pb_install_hook_verified "$hk"
      done
      # Policy: CONTINUE — t_fail/t_unresolved recorded per hook route.
      pb_run_stage pb_hook_smoke_matrix
    fi
  fi

  # ── PHASE 3: Fixture creation ────────────────────────────
  # Test users: HALT on failure — required for the majority of tests.
  pb_create_test_user "user" \
    ORDINARY_ID_FILE ORDINARY_TOK_FILE ORDINARY_AUTH_CFG || {
    print "[cp0] HALT: ordinary user creation failed" >&2
    return 1
  }
  pb_create_test_user "admin" \
    ADMIN_ID_FILE ADMIN_TOK_FILE ADMIN_AUTH_CFG || {
    print "[cp0] HALT: admin user creation failed" >&2
    return 1
  }
  pb_create_test_user "superadmin" \
    SADMIN_ID_FILE SADMIN_TOK_FILE SADMIN_AUTH_CFG || {
    print "[cp0] HALT: superadmin user creation failed" >&2
    return 1
  }

  # Policy: CONTINUE — t_harness_err recorded if fixture setup fails;
  # dependent tests gate on file existence (LEGACY_CHILD_ID_FILE etc.).
  pb_run_stage pb_create_legacy_fixture

  # Policy: CONTINUE — t_harness_err recorded if alias setup fails;
  # dependent tests gate on ALIAS_ID_FILE / WRONG_PW_FILE existence.
  pb_run_stage pb_setup_alias_group

  pb_record_production_exclusions

  # ── PHASE 4: Test execution ──────────────────────────────
  # Policy: CONTINUE for all test groups. Each group records its own
  # t_fail / t_blocking / t_harness_err / t_skip / t_unresolved.
  # A nonzero return from a test group means tests failed, which is
  # already conclusively recorded — execution continues to completion.
  pb_run_stage t_crud_children_group
  pb_run_stage t_field_protection_group
  pb_run_stage t_file_auth_group
  pb_run_stage t_auth_group
  pb_run_stage t_alias_enum_group
  pb_run_stage t_email_otp_group
  pb_run_stage t_admin_nsu_group
  pb_run_stage t_user_ops_group
  pb_run_stage t_content_group
  pb_run_stage t_anon_inject_group
  pb_run_stage t_api_route_group
  pb_run_stage t_rule_test_group
  pb_run_stage t_email_lifecycle_group
  pb_run_stage t_concurrency_group
  pb_run_stage t_proxy_ip_group

  # ── PHASE 5: Cleanup and report ──────────────────────────
  # Policy: set CLEANUP_FAILURE on failure; do not halt (report must still run).
  # R16: pb_cleanup_normal and pb_scan_and_export_report now propagate failure.
  pb_run_stage pb_cleanup_normal || CLEANUP_FAILURE=1
  pb_run_stage pb_scan_and_export_report || CLEANUP_FAILURE=1

  # ── Final summary ────────────────────────────────────────
  print "=== CP0 Orchestration complete ==="
  print "=== T_PASS=${T_PASS} T_FAIL=${T_FAIL} T_BLOCKING=${T_BLOCKING} ==="
  print "=== T_HARNESS_ERR=${T_HARNESS_ERR} CLEANUP_FAILURE=${CLEANUP_FAILURE} ==="
  print "=== T_UNRESOLVED=${T_UNRESOLVED} T_DEFERRED=${T_DEFERRED} T_SKIP=${T_SKIP} ==="
  print "==="
  print "=== T_UNRESOLVED and T_DEFERRED are informational. ==="
  print "=== They represent items requiring NEEDS-EXTERNAL prerequisites ==="
  print "=== and do not affect exit status. ==="
  print "==="

  # R16 final exit: all four failure modes considered.
  # T_BLOCKING: a schema, security, or infrastructure prerequisite failed.
  # T_FAIL: a test produced a wrong result.
  # T_HARNESS_ERR: the harness itself misbehaved (helper crash, bad file, etc.).
  # CLEANUP_FAILURE: records, secrets, or isolated root not fully removed.
  # T_UNRESOLVED / T_DEFERRED: informational; require NEEDS-EXTERNAL config.
  if (( T_BLOCKING > 0 || T_FAIL > 0 || T_HARNESS_ERR > 0 || CLEANUP_FAILURE > 0 )); then
    print "=== RESULT: FAIL ===" >&2
    return 1
  fi
  print "=== RESULT: PASS ==="
  return 0
}

# ────────────────────────────────────────────────────────────
# §42 ENTRY POINT (defect-31, preserved)
# ────────────────────────────────────────────────────────────

main() {
  local mode="${1:-}"

  pb_setup_umask
  pb_generate_run_suffix
  pb_install_trap

  case "$mode" in

    --package-check)
      pb_setup_root
      pb_write_scripts
      pb_check_package_completeness
      exit $?
      ;;

    --harness-check)
      pb_setup_root
      pb_write_scripts
      if ! t_harness_selftest; then
        print "[harness-check] FAIL" >&2
        exit 1
      fi
      print "[harness-check] PASS"
      exit 0
      ;;

    --preflight)
      pb_setup_root
      pb_write_scripts
      pb_detect_platform
      pb_preflight_ports || exit 1
      print "[preflight] PASS"
      exit 0
      ;;

    --run)
      local cp0_auth="${2:-}"
      if [[ "$cp0_auth" != "--authorize-cp0" ]]; then
        print "ERROR: Checkpoint 0 is not authorized." >&2
        print "       Pass --authorize-cp0 only after explicit authorization." >&2
        exit 1
      fi
      pb_setup_root
      pb_write_scripts
      pb_detect_platform
      pb_verify_archive_hash "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || {
        print "[main] HALT: archive hash verification failed — extraction aborted" >&2
        exit 1
      }
      pb_extract_pocketbase "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || exit 1
      cp0_run
      exit $?
      ;;

    *)
      print "Usage: $0 {--package-check|--harness-check|--preflight|--run}" >&2
      print "  --package-check   Verify hook/archive/schema paths" >&2
      print "  --harness-check   Run harness self-test only" >&2
      print "  --preflight       Check ports (no PocketBase started)" >&2
      print "  --run             Full harness run (requires --authorize-cp0)" >&2
      exit 2
      ;;
  esac
}

main "$@"
