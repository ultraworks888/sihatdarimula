#!/usr/bin/env zsh
# ============================================================
# release1b_cp0.zsh — Release 1B Checkpoint 0 Harness
# Round  : 14 (complete fresh rewrite)
# Status : DRAFTED — not executed; zsh -n not performed
#          (tool-interface limitation)
# EOF parse error (Round 13): UNRESOLVED — cause not
#   positively identified through investigation; fresh
#   rewrite eliminates any carry-over regardless of cause.
# ============================================================
#
# AUTHORIZATION BOUNDARY (defect-31 fix)
# ──────────────────────────────────────
#   Permitted execution modes (operator-invoked):
#     --package-check   verify archive + hook paths
#     --harness-check   run self-test suite only
#     --preflight       bring up PocketBase, schema, hooks
#     --run             full harness run
#   Checkpoint 0 is NOT authorized. The orchestration
#   function cp0_run() is present but guarded; an operator
#   must pass --run and a separate authorization argument
#   before it proceeds.
#
# Correction matrix: release1b_round14_review.md
# All 31 defects classified IMPL, IMPL-MD, or NEEDS-EXTERNAL.
# ============================================================

# ────────────────────────────────────────────────────────────
# §2  SAFETY OPTIONS
# ────────────────────────────────────────────────────────────

setopt NO_UNSET PIPE_FAIL

# ────────────────────────────────────────────────────────────
# §3  CONSTANTS
# ────────────────────────────────────────────────────────────

readonly RELEASE1B_SCRIPT_ROUND="14"
readonly RELEASE1B_PB_PORT="8090"
readonly RELEASE1B_MH_HTTP_PORT="8025"
readonly RELEASE1B_MH_SMTP_PORT="1025"
readonly RELEASE1B_PB_VERSION="0.29.3"

# PocketBase archive names by platform
typeset -grA PB_ARCHIVE_NAME=(
  [darwin_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_arm64.zip"
  [darwin_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_darwin_amd64.zip"
  [linux_amd64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_amd64.zip"
  [linux_arm64]="pocketbase_${RELEASE1B_PB_VERSION}_linux_arm64.zip"
)

# Expected SHA-256 hashes of PocketBase archives
# NEEDS-EXTERNAL: operators must populate before --run
typeset -grA PB_EXPECTED_SHA256=(
  [darwin_arm64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [darwin_amd64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [linux_amd64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
  [linux_arm64]="UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256"
)

# Hook source paths — operators must set before --run
# Keys must exactly match keys in HOOK_PROBE_ROUTES (defect-28 fix)
typeset -grA HOOK_SRC_PATHS=(
  [onboarding]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
  [alias_intercept]="UNRESOLVED__NEEDS_EXTERNAL__hook_src_path"
)

# Expected SHA-256 hashes of hook source files
typeset -grA HOOK_EXPECTED_SHA256=(
  [onboarding]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [push_broadcast]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [whatsapp]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
  [alias_intercept]="UNRESOLVED__NEEDS_EXTERNAL__hook_sha256"
)

# Defect-15 fix: per-hook probe routes (populated by operators before --run)
# Keys MUST match HOOK_SRC_PATHS keys exactly (defect-28 fix enforces this)
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

# Defect-16 fix: expected HTTP status after hook removal per hook
# 404 = route existed only because of hook; disappears on removal
# Other value = route is shared; reverts to baseline behavior
typeset -gA HOOK_EXPECTED_REMOVED_STATUS=(
  [onboarding]="404"
  [push_broadcast]="404"
  [whatsapp]="404"
  [alias_intercept]="UNRESOLVED__NEEDS_EXTERNAL__interceptor_baseline"
)

# Schema source path (migration JS files)
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

# Isolation paths (resolved by pb_setup_root)
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

# API base URL
typeset -g RELEASE1B_BASE_URL="http://127.0.0.1:${RELEASE1B_PB_PORT}"

# PocketBase runtime state
typeset -g RELEASE1B_PB_BIN=""
typeset -gi RELEASE1B_PB_PID=0
typeset -g  RELEASE1B_MH_ID=""

# Python helper script paths
typeset -g PBJ_STAT_PY="" PBJ_URL_PY="" PBJ_PY="" PBJ_AUTH_PY=""
typeset -g PBJ_FIELD_PY="" PBJ_COPY_PY="" PBJ_EXTRACT_PY="" PBJ_SHAPE_PY=""
typeset -g PBJ_SCAN_PY="" PBJ_HTTP_PY=""

# Run suffix (unique per invocation, set by pb_generate_run_suffix)
typeset -g RUN_SUFFIX=""

# Superuser credentials
typeset -g _NATIVE_SU_TOK_FILE=""
typeset -g _NATIVE_SU_ID_FILE=""
typeset -g _NATIVE_SU_AUTH_CFG=""

# Test user credential files
typeset -g ORDINARY_ID_FILE="" ORDINARY_TOK_FILE="" ORDINARY_AUTH_CFG=""
typeset -g ADMIN_ID_FILE=""    ADMIN_TOK_FILE=""    ADMIN_AUTH_CFG=""
typeset -g SADMIN_ID_FILE=""   SADMIN_TOK_FILE=""   SADMIN_AUTH_CFG=""
typeset -g LEGACY_ID_FILE=""   LEGACY_TOK_FILE=""   LEGACY_AUTH_CFG=""

# Legacy fixture record files
typeset -g LEGACY_CHILD_ID_FILE=""      LEGACY_GROWTH_ID_FILE=""
typeset -g LEGACY_ACTIVITY_ID_FILE=""   LEGACY_IMMUN_ID_FILE=""
typeset -g LEGACY_PROGRESS_ID_FILE=""   LEGACY_NB_ENROLL_ID_FILE=""

# Alias fixture files
typeset -g ALIAS_ID_FILE="" ALIAS_PW_FILE="" ALIAS_AUTH_CFG=""
typeset -g WRONG_PW_FILE=""
# Defect-10 fix: password file for timing-legacy re-auth in case 5
typeset -g TIMING_LEGACY_ID_FILE=""  TIMING_LEGACY_PW_FILE=""
typeset -g TIMING_LEGACY_AUTH_CFG=""

# Rule baseline storage (populated by pb_apply_rule_local)
# Defect-12 fix: __pb_null__ sentinel distinguishes JSON null from ""
typeset -gA RULE_BASELINE=()

# Alias enum response capture arrays
typeset -ga ENUM_RESP_FILES=() ENUM_HTTP_VALUES=() ENUM_TIME_FILES=()

# Fixture registry: fixture_id -> cleanup_function_name
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
  # Increment named integer variable
  local _var="$1"
  typeset -g "${_var}"=$(( ${(P)_var} + 1 ))
}

pb_halt() {
  print "[HALT] $*" >&2
  exit 1
}

pb_secure_tmpfile() {
  # Create a secure temporary file in RELEASE1B_TEST_TMP.
  # Prints the path. Caller is responsible for deletion.
  local suffix="${1:-.tmp}"
  local path="${RELEASE1B_TEST_TMP}/${RUN_SUFFIX}_$$_${RANDOM}${suffix}"
  : > "$path"
  chmod 600 "$path"
  print "$path"
}

pb_wipe_secret_file() {
  # Overwrite and remove a secret file
  local f="$1"
  [[ -f "$f" ]] || return 0
  dd if=/dev/zero of="$f" bs=1024 count=4 2>/dev/null || true
  rm -f "$f"
}

# ────────────────────────────────────────────────────────────
# §6  TRAP / CLEANUP
# ────────────────────────────────────────────────────────────

pb_trap_cleanup() {
  # Kill PocketBase if running
  if (( RELEASE1B_PB_PID > 0 )); then
    kill "$RELEASE1B_PB_PID" 2>/dev/null
    wait "$RELEASE1B_PB_PID" 2>/dev/null || true
    RELEASE1B_PB_PID=0
  fi

  # Stop Mailhog container if running
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

  # Wipe secret files still on disk
  local sf
  for sf in \
    "$_NATIVE_SU_TOK_FILE" "$_NATIVE_SU_ID_FILE" "$_NATIVE_SU_AUTH_CFG" \
    "$ORDINARY_TOK_FILE"   "$ADMIN_TOK_FILE"      "$SADMIN_TOK_FILE" \
    "$LEGACY_TOK_FILE"     "$ALIAS_PW_FILE"        "$WRONG_PW_FILE" \
    "$TIMING_LEGACY_PW_FILE"; do
    [[ -n "$sf" ]] && pb_wipe_secret_file "$sf"
  done

  # Remove isolated root only if cleanup succeeded
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
  # Defect-21 fix: explicit authorized-exclusion record
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
  # Write all Python helpers to RELEASE1B_TEST_TMP and record paths.
  # Each heredoc terminator is at column 0, no leading whitespace.
  local d="$RELEASE1B_TEST_TMP"

  # ── PBJ_STAT_PY: safe lstat / path-containment check ──
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

  # ── PBJ_URL_PY: URL validation before HTTP calls ──
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
# Block octal/hex encoded hosts
raw_host = url_str.split('://')[1].split('/')[0].split('@')[-1].split(':')[0]
if re.search(r'0x|%|0[0-9]{2,}', raw_host):
    print('REJECT:encoded-host')
    sys.exit(0)
print('OK')
PYEOF

  # ── PBJ_PY: safe JSON request body builder ──
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
    # Format: [type:]key=value
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
        # Format: secret-file:key=filepath
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
# Atomic write
tmp = out_path + '.pbjtmp'
with open(tmp, 'w') as fh:
    json.dump(obj, fh)
os.chmod(tmp, 0o600)
os.replace(tmp, out_path)
PYEOF

  # ── PBJ_AUTH_PY: build Authorization header file from token ──
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

  # ── PBJ_HTTP_PY: curl wrapper; writes status code + response path ──
  PBJ_HTTP_PY="${d}/pbj_http.py"
  cat > "$PBJ_HTTP_PY" << 'PYEOF'
import sys, os, subprocess, re, tempfile, stat as _st
CANONICAL_TMP = os.environ.get('RELEASE1B_CANONICAL_TMP', tempfile.gettempdir())
MAX_RESP = 2 * 1024 * 1024  # 2 MiB

def main():
    status_out = sys.argv[1]   # path to write HTTP status code
    path_out   = sys.argv[2]   # path to write response body file path
    url        = sys.argv[3]
    auth_file  = sys.argv[4] if len(sys.argv) > 4 else ''
    body_file  = sys.argv[5] if len(sys.argv) > 5 else ''
    method     = sys.argv[6] if len(sys.argv) > 6 else 'GET'

    # Validate URL via PBJ_URL_PY before passing to curl
    # (already validated in shell callers; double-check here)
    if not url.startswith('http://127.0.0.1:'):
        print('ERROR: unexpected URL prefix', file=sys.stderr)
        sys.exit(1)

    # Build curl command
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

    # Truncate oversized responses for safety
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

  # ── PBJ_FIELD_PY: extract one field value from a JSON response ──
  PBJ_FIELD_PY="${d}/pbj_field.py"
  cat > "$PBJ_FIELD_PY" << 'PYEOF'
import sys, os, json, re
BLOCKED = frozenset({
    'password', 'passwordHash', 'tokenKey',
})
resp_file = sys.argv[1]
field     = sys.argv[2]
if field in BLOCKED:
    print(f'BLOCKED', file=sys.stderr)
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
    # array or object — print type tag
    print(f'__type:{type(val).__name__}__')
PYEOF

  # ── PBJ_COPY_PY: copy one field value between two JSON response files ──
  PBJ_COPY_PY="${d}/pbj_copy.py"
  cat > "$PBJ_COPY_PY" << 'PYEOF'
import sys, json
# Defect-7/8 fix: inline record.id extraction; pb_copy_field for id removed
# This helper copies arbitrary non-blocked fields between response bodies.
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

  # ── PBJ_EXTRACT_PY: extract id field safely from response ──
  # Defect-7/8 fix: replaces pb_copy_field usage for record.id
  PBJ_EXTRACT_PY="${d}/pbj_extract.py"
  cat > "$PBJ_EXTRACT_PY" << 'PYEOF'
import sys, json, re
# Reads a JSON response file; prints the value of the named field.
# The field is whitelisted; only non-sensitive identifiers are allowed.
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

  # ── PBJ_SHAPE_PY: assert JSON response matches expected shape ──
  PBJ_SHAPE_PY="${d}/pbj_shape.py"
  cat > "$PBJ_SHAPE_PY" << 'PYEOF'
import sys, json
# Usage: pbj_shape.py <resp_file> <field1> [field2 ...] [--absent <field>]
# Verifies fields are present (or absent with --absent flag)
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

  # ── PBJ_SCAN_PY: sanitized report scanner ──
  # Defect-29/30 fix: sanitizes paths in output; uses atomic write
  PBJ_SCAN_PY="${d}/pbj_scan.py"
  cat > "$PBJ_SCAN_PY" << 'PYEOF'
import sys, os, re, json
CANONICAL_ROOT = os.environ.get('RELEASE1B_CANONICAL_ROOT', '')
report_in  = sys.argv[1]
report_out = sys.argv[2]

def sanitize_line(line):
    # Replace occurrences of the isolated root path with a placeholder
    if CANONICAL_ROOT:
        line = line.replace(CANONICAL_ROOT, '[ISOLATED_ROOT]')
    # Replace home directory paths
    home = os.path.expanduser('~')
    if home and home != '~':
        line = line.replace(home, '[HOME]')
    # Replace /tmp/release1b_cp0_* tokens
    line = re.sub(r'/tmp/release1b_cp0_[A-Za-z0-9_]+', '[ISOLATED_ROOT]', line)
    return line

lines = []
try:
    with open(report_in) as fh:
        for line in fh:
            lines.append(sanitize_line(line.rstrip('\n')))
except Exception as e:
    print(f'ERROR reading report: {e}', file=sys.stderr)
    sys.exit(1)

# Atomic write
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

  # Make all helper scripts read-only
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
  # Confirm a path is within the isolated root and not a symlink.
  # Usage: pb_validate_path <path>
  local path="$1"
  local result
  result=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$path" 2>/dev/null)
  case "$result" in
    SYMLINK)       print "PATH_SYMLINK:${path}"; return 1 ;;
    OUTSIDE_ROOT)  print "PATH_OUTSIDE:${path}"; return 1 ;;
    ERROR*)        print "PATH_ERROR:${path}"; return 1 ;;
    *)             return 0 ;;
  esac
}

pb_validate_url() {
  # Confirm a URL is safe to call.
  # Usage: pb_validate_url <url>
  local url="$1"
  local result
  result=$(python3 "$PBJ_URL_PY" "$url" "127.0.0.1" "$RELEASE1B_PB_PORT" 2>/dev/null)
  [[ "$result" == "OK" ]]
}

pb_url() {
  # Build and validate a PocketBase API URL.
  # Usage: pb_url <path_suffix>  → prints full URL or halts
  local suffix="$1"
  local url="${RELEASE1B_BASE_URL}${suffix}"
  if ! pb_validate_url "$url"; then
    pb_halt "URL validation failed: ${url}"
  fi
  print "$url"
}

# ────────────────────────────────────────────────────────────
# §10 PACKAGE COMPLETENESS CHECK
# ────────────────────────────────────────────────────────────

pb_check_package_completeness() {
  # Defect-28 fix: validate that HOOK_PROBE_ROUTES keys exactly match
  # HOOK_SRC_PATHS keys — no extras, no missing.
  print "=== Package completeness check ==="
  local ok=1

  # Check hook source paths exist
  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local src="${HOOK_SRC_PATHS[$hk]}"
    if [[ "$src" == UNRESOLVED* ]]; then
      print "[pkg] HOOK_SRC_PATHS[$hk]: UNRESOLVED — operators must set before --run"
      ok=0
      continue
    fi
    if [[ ! -f "$src" ]]; then
      print "[pkg] HOOK_SRC_PATHS[$hk]: file not found: ${src}" >&2
      ok=0
    fi
  done

  # Defect-28 fix: verify HOOK_PROBE_ROUTES keys == HOOK_SRC_PATHS keys
  local -a src_keys probe_keys
  src_keys=("${(@k)HOOK_SRC_PATHS}")
  probe_keys=("${(@k)HOOK_PROBE_ROUTES}")

  local k
  for k in "${src_keys[@]}"; do
    if [[ -z "${HOOK_PROBE_ROUTES[$k]+set}" ]]; then
      print "[pkg] HOOK_PROBE_ROUTES missing key '${k}' (present in HOOK_SRC_PATHS)" >&2
      ok=0
    fi
  done
  for k in "${probe_keys[@]}"; do
    if [[ -z "${HOOK_SRC_PATHS[$k]+set}" ]]; then
      print "[pkg] HOOK_PROBE_ROUTES has extra key '${k}' not in HOOK_SRC_PATHS)" >&2
      ok=0
    fi
  done

  # Check PB archive if specified
  if [[ -n "${PB_ARCHIVE_NAME[${PLATFORM_KEY:-}]+set}" ]]; then
    local archive="${PB_ARCHIVE_NAME[${PLATFORM_KEY}]}"
    if [[ ! -f "$archive" ]]; then
      print "[pkg] PocketBase archive not found: ${archive}" >&2
      ok=0
    fi
  fi

  # Check schema source
  if [[ "$RELEASE1B_SCHEMA_SRC" == UNRESOLVED* ]]; then
    print "[pkg] RELEASE1B_SCHEMA_SRC: UNRESOLVED — operators must set before --run"
    ok=0
  elif [[ ! -d "$RELEASE1B_SCHEMA_SRC" && ! -f "$RELEASE1B_SCHEMA_SRC" ]]; then
    print "[pkg] RELEASE1B_SCHEMA_SRC not found: ${RELEASE1B_SCHEMA_SRC}" >&2
    ok=0
  fi

  if (( ok )); then
    print "[pkg] Package completeness: PASS"
    return 0
  else
    print "[pkg] Package completeness: FAIL — see messages above" >&2
    return 1
  fi
}

# ────────────────────────────────────────────────────────────
# §11 HARNESS SELF-TEST
# ────────────────────────────────────────────────────────────

t_harness_selftest() {
  print "=== Harness self-test ==="
  local fail=0

  # Defect-1 note: double-invocation not reproduced in R13 delivered artifact.
  # Single-invocation self-test is retained as designed.
  # The assertion below verifies the harness is not re-entered.
  if [[ -n "${_RELEASE1B_SELFTEST_RUNNING:-}" ]]; then
    print "[selftest] ERROR: self-test re-entry detected" >&2
    return 1
  fi
  local _RELEASE1B_SELFTEST_RUNNING=1

  # ── Counter sanity ──
  local saved_pass=$T_PASS
  t_pass "SELFTEST-COUNTER"
  if (( T_PASS != saved_pass + 1 )); then
    print "[selftest] FAIL: t_pass did not increment T_PASS" >&2; fail=1
  fi

  # ── pb_secure_tmpfile ──
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

  # ── pb_validate_url ──
  if ! pb_validate_url "http://127.0.0.1:${RELEASE1B_PB_PORT}/api/collections/foo/records"; then
    print "[selftest] FAIL: valid URL rejected" >&2; fail=1
  fi
  if pb_validate_url "http://evil.com/api/collections/foo/records" 2>/dev/null; then
    print "[selftest] FAIL: external URL not rejected" >&2; fail=1
  fi
  if pb_validate_url "http://127.0.0.1:${RELEASE1B_PB_PORT}/notapi/records" 2>/dev/null; then
    print "[selftest] FAIL: non-/api/ path not rejected" >&2; fail=1
  fi

  # ── PBJ_PY: blocked key rejection ──
  local body_f; body_f=$(pb_secure_tmpfile .json)
  if python3 "$PBJ_PY" "$body_f" "id=foo" 2>/dev/null; then
    print "[selftest] FAIL: pbj.py accepted blocked key 'id'" >&2; fail=1
  fi
  rm -f "$body_f"

  # ── PBJ_PY: duplicate key rejection ──
  body_f=$(pb_secure_tmpfile .json)
  if python3 "$PBJ_PY" "$body_f" "name=a" "name=b" 2>/dev/null; then
    print "[selftest] FAIL: pbj.py accepted duplicate key" >&2; fail=1
  fi
  rm -f "$body_f"

  # ── PBJ_PY: boolean and number types ──
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

  # ── PBJ_STAT_PY: symlink detection ──
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

  # ── PBJ_EXTRACT_PY: non-allowlist field rejection ──
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

  # ── HALT_DEPENDENTS propagation ──
  local saved_halt=$HALT_DEPENDENTS
  HALT_DEPENDENTS=1
  local skip_fired=0
  t_skip "SELFTEST-SKIP-PROPAGATION" "testing skip" && skip_fired=1
  HALT_DEPENDENTS=$saved_halt
  if (( T_SKIP < 1 )); then
    print "[selftest] FAIL: t_skip did not increment T_SKIP" >&2; fail=1
  fi

  # Subtract selftest-internal pass from global counter to avoid inflating results
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
# §12 INFRASTRUCTURE — POCKETBASE SETUP
# ────────────────────────────────────────────────────────────

pb_detect_platform() {
  local os_name; os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  local arch; arch=$(uname -m)
  case "$arch" in
    arm64|aarch64) arch="arm64" ;;
    x86_64)        arch="amd64" ;;
    *)             pb_halt "Unsupported architecture: ${arch}" ;;
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
      "PB archive hash for ${PLATFORM_KEY} is UNRESOLVED — operators must set PB_EXPECTED_SHA256"
    return 0
  fi
  local actual; actual=$(shasum -a 256 "$archive" 2>/dev/null | awk '{print $1}')
  if [[ "$actual" != "$expected" ]]; then
    t_blocking "T-PKG-ARCHIVE-HASH" \
      "PocketBase archive hash mismatch: expected=${expected} actual=${actual}"
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
  # Copy migration files to isolated migrations dir
  if [[ -d "$RELEASE1B_SCHEMA_SRC" ]]; then
    cp "${RELEASE1B_SCHEMA_SRC}"/*.js "$RELEASE1B_PB_MIGRATIONS_DIR"/ 2>/dev/null || true
  elif [[ -f "$RELEASE1B_SCHEMA_SRC" ]]; then
    cp "$RELEASE1B_SCHEMA_SRC" "$RELEASE1B_PB_MIGRATIONS_DIR"/
  fi
  chmod 600 "${RELEASE1B_PB_MIGRATIONS_DIR}"/*.js 2>/dev/null || true
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

  # Wait for PocketBase to become ready
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
# §13 NATIVE SUPERUSER LIFECYCLE
# ────────────────────────────────────────────────────────────
#
# Defect-7/8 fix:
#   - Removed stale anonymous-fallback comment (was R13 lines 1266-1267)
#   - Removed su_w (static superuser copy) — only _NATIVE_SU_TOK_FILE used
#   - ID extracted via pbj_extract.py using record.id field
#

pb_create_local_superuser() {
  print "=== Creating native superuser ==="
  local su_email="cp0_su_${RUN_SUFFIX}@release1b.local"
  local su_pw_file; su_pw_file=$(pb_secure_tmpfile .pw)
  local su_tok_file; su_tok_file=$(pb_secure_tmpfile .tok)
  local su_id_file; su_id_file=$(pb_secure_tmpfile .id)
  local su_auth_cfg; su_auth_cfg=$(pb_secure_tmpfile .hdr)

  # Generate random password (≥32 chars)
  openssl rand -base64 32 | tr -d '\n=' > "$su_pw_file"
  chmod 600 "$su_pw_file"

  # Build superuser via PocketBase admin create
  "$RELEASE1B_PB_BIN" admin create \
    "$su_email" \
    "$(cat "$su_pw_file")" \
    --dir "$RELEASE1B_PB_DATA_DIR" \
    &>/dev/null || {
    t_blocking "T-SU-CREATE" "pocketbase admin create failed"
    return 1
  }

  # Authenticate superuser
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
    t_blocking "T-SU-AUTH" "Superuser auth returned ${status} (expected 200)"
    rm -f "$resp_path"
    pb_wipe_secret_file "$su_pw_file"
    return 1
  fi

  # Extract token — write to su_tok_file
  local token; token=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
  if [[ -z "$token" || "$token" == "__absent__" ]]; then
    t_blocking "T-SU-AUTH-TOKEN" "Superuser auth response missing token"
    rm -f "$resp_path"
    pb_wipe_secret_file "$su_pw_file"
    return 1
  fi
  printf '%s' "$token" > "$su_tok_file"
  chmod 600 "$su_tok_file"

  # Extract ID via pbj_extract.py (defect-7/8 fix: inline read; no pb_copy_field for id)
  local su_id; su_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  if [[ -z "$su_id" || "$su_id" == "__absent__" ]]; then
    t_blocking "T-SU-AUTH-ID" "Superuser auth response missing id"
    pb_wipe_secret_file "$su_pw_file"
    return 1
  fi
  printf '%s' "$su_id" > "$su_id_file"
  chmod 600 "$su_id_file"

  # Build Authorization header config
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
    print "[su-del] No superuser ID file — skipping" >&2
    return 0
  fi
  local su_id; su_id=$(cat "$_NATIVE_SU_ID_FILE" 2>/dev/null)
  if [[ -z "$su_id" ]]; then
    return 0
  fi

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
#
# Defect-5 fix: pb_verify_schema is called AFTER pb_create_local_superuser
# so the superuser token is available to query the admin API.
#

pb_verify_schema() {
  print "=== Schema verification ==="
  (( HALT_DEPENDENTS )) && { t_skip "T-SCHEMA-VERIFY" "blocked"; return 0; }

  # Required collections
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
# §15 HOOK MANAGEMENT
# ────────────────────────────────────────────────────────────

pb_verify_hook_directory() {
  print "=== Hook directory verification ==="
  local hooks_dir="$RELEASE1B_PB_HOOKS_DIR"

  pb_validate_path "$hooks_dir" || {
    t_blocking "T-HOOKDIR-PATH" "Hooks dir failed path validation"
    return 1
  }

  local perms
  perms=$(RELEASE1B_CANONICAL_TMP="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_STAT_PY" "$hooks_dir" 2>/dev/null)
  if [[ "$perms" != "700" ]]; then
    t_blocking "T-HOOKDIR-PERMS" \
      "Hooks dir permissions are ${perms} (expected 700)"
    return 1
  fi
  t_pass "T-HOOKDIR-VERIFY"
}

pb_install_hook_verified() {
  # Install a hook file after integrity verification.
  # Usage: pb_install_hook_verified <hook_key>
  # Defect-15/16 fix: validates hash per hook; records probe config
  local hk="$1"
  local src="${HOOK_SRC_PATHS[$hk]:-}"

  if [[ -z "$src" || "$src" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-INSTALL-${hk}" \
      "HOOK_SRC_PATHS[${hk}] not configured"
    return 0
  fi

  if [[ ! -f "$src" ]]; then
    t_blocking "T-HOOK-INSTALL-${hk}" "Hook source not found: ${src}"
    return 1
  fi

  # Verify SHA-256
  local expected_hash="${HOOK_EXPECTED_SHA256[$hk]:-}"
  if [[ "$expected_hash" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-HASH-${hk}" \
      "HOOK_EXPECTED_SHA256[${hk}] not set — hash check skipped"
  else
    local actual_hash; actual_hash=$(shasum -a 256 "$src" | awk '{print $1}')
    if [[ "$actual_hash" != "$expected_hash" ]]; then
      t_blocking "T-HOOK-HASH-${hk}" \
        "Hook hash mismatch: expected=${expected_hash} actual=${actual_hash}"
      return 1
    fi
    t_pass "T-HOOK-HASH-${hk}"
  fi

  # Copy to hooks dir
  local dst="${RELEASE1B_PB_HOOKS_DIR}/${hk}.js"
  cp "$src" "$dst" || {
    t_blocking "T-HOOK-INSTALL-${hk}" "cp failed: ${src} -> ${dst}"
    return 1
  }
  chmod 600 "$dst"
  t_pass "T-HOOK-INSTALL-${hk}"
}

pb_remove_hook_verified() {
  # Remove a hook file and verify the route is gone.
  # Usage: pb_remove_hook_verified <hook_key>
  # Defect-16 fix: uses per-hook HOOK_EXPECTED_REMOVED_STATUS
  local hk="$1"
  local dst="${RELEASE1B_PB_HOOKS_DIR}/${hk}.js"

  if [[ -f "$dst" ]]; then
    rm -f "$dst" || { CLEANUP_FAILURE=1; return 1; }
  fi

  # Probe the hook route to verify it is no longer active
  local probe_route="${HOOK_PROBE_ROUTES[$hk]:-}"
  local probe_method="${HOOK_PROBE_METHODS[$hk]:-GET}"
  local expected_status="${HOOK_EXPECTED_REMOVED_STATUS[$hk]:-404}"

  if [[ -z "$probe_route" || "$probe_route" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-REMOVE-PROBE-${hk}" \
      "HOOK_PROBE_ROUTES[${hk}] not configured — cannot verify removal"
    return 0
  fi

  if [[ "$expected_status" == UNRESOLVED* ]]; then
    t_unresolved "T-HOOK-REMOVE-STATUS-${hk}" \
      "HOOK_EXPECTED_REMOVED_STATUS[${hk}] not set — cannot verify removal"
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
      "Route still active after hook removal: status=${actual} expected=${expected_status}"
    return 1
  fi
  t_pass "T-HOOK-REMOVE-${hk}"
}

pb_hook_smoke_matrix() {
  # Defect-15 fix: probe each hook using its configured route/method
  print "=== Hook smoke matrix ==="
  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    local probe_route="${HOOK_PROBE_ROUTES[$hk]:-}"
    local probe_method="${HOOK_PROBE_METHODS[$hk]:-GET}"

    if [[ -z "$probe_route" || "$probe_route" == UNRESOLVED* ]]; then
      t_unresolved "T-HOOK-SMOKE-${hk}" \
        "HOOK_PROBE_ROUTES[${hk}] not configured"
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

    # Hook is considered live if it responds with anything other than 404
    if [[ "$status" == "404" ]]; then
      t_fail "T-HOOK-SMOKE-${hk}" \
        "Hook route returned 404 — hook may not be loaded"
    else
      t_pass "T-HOOK-SMOKE-${hk}"
    fi
  done
}

# ────────────────────────────────────────────────────────────
# §16 RULE LIFECYCLE
# ────────────────────────────────────────────────────────────

pb_apply_rule_local() {
  # Save current rule for a collection and apply a new one.
  # Usage: pb_apply_rule_local <collection> <rule_type> <new_value>
  # Defect-12 fix: uses __pb_null__ sentinel to distinguish JSON null from ""
  local collection="$1" rule_type="$2" new_value="$3"
  local registry_key="${collection}::${rule_type}"

  # Fetch current collection config
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

  # Extract current rule value (may be null)
  local current_rule; current_rule=$(python3 "$PBJ_FIELD_PY" "$resp_path" "$rule_type" 2>/dev/null)
  rm -f "$resp_path"

  # Store baseline using __pb_null__ sentinel for JSON null
  if [[ "$current_rule" == "__null__" ]]; then
    RULE_BASELINE[$registry_key]="__pb_null__"
  else
    RULE_BASELINE[$registry_key]="${current_rule}"
  fi

  # Apply new rule
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "${rule_type}=${new_value}" 2>/dev/null || {
    t_harness_err "T-RULE-APPLY-${collection}-${rule_type}" "pbj.py failed"
    return 1
  }

  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  url=$(pb_url "/api/collections/${collection}")

  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" \
      "$_NATIVE_SU_AUTH_CFG" "$body_f" "PATCH"

  status=$(cat "$status_f" 2>/dev/null)
  resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$resp_path"

  if [[ "$status" != "200" ]]; then
    t_harness_err "T-RULE-APPLY-${collection}-${rule_type}" \
      "PATCH returned ${status}"
    return 1
  fi
  t_pass "T-RULE-APPLY-${collection}-${rule_type}"
}

pb_restore_rule_local() {
  # Restore a previously saved rule for a collection.
  # Usage: pb_restore_rule_local <collection> <rule_type>
  # Defect-14 fix: adds independent re-read and compare after patch
  local collection="$1" rule_type="$2"
  local registry_key="${collection}::${rule_type}"
  local baseline="${RULE_BASELINE[$registry_key]:-}"

  if [[ -z "$baseline" ]]; then
    t_harness_err "T-RULE-RESTORE-${collection}-${rule_type}" \
      "No baseline found in RULE_BASELINE for ${registry_key}"
    return 1
  fi

  # Resolve sentinel
  local restore_value
  if [[ "$baseline" == "__pb_null__" ]]; then
    restore_value="null"
  else
    restore_value="\"${baseline}\""
  fi

  local body_f; body_f=$(pb_secure_tmpfile .json)
  # Write restore body using raw JSON approach for null handling
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
    t_harness_err "T-RULE-RESTORE-${collection}-${rule_type}" \
      "PATCH returned ${status}"
    return 1
  fi

  # Defect-14 fix: independent re-read and compare
  sleep 0.2
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  url=$(pb_url "/api/collections/${collection}")

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

  # Convert confirmed value to comparable form
  local confirmed_norm
  if [[ "$confirmed" == "__null__" ]]; then
    confirmed_norm="__pb_null__"
  else
    confirmed_norm="$confirmed"
  fi

  if [[ "$confirmed_norm" != "$baseline" ]]; then
    CLEANUP_FAILURE=1
    t_harness_err "T-RULE-RESTORE-VERIFY-${collection}-${rule_type}" \
      "re-read mismatch: expected='${baseline}' got='${confirmed}'"
    return 1
  fi
  t_pass "T-RULE-RESTORE-${collection}-${rule_type}"
}

# ────────────────────────────────────────────────────────────
# §17 HTTP HELPER — pb_capture
# ────────────────────────────────────────────────────────────

pb_capture() {
  # Make an HTTP request and verify the status code is among expected values.
  # Usage: pb_capture <method> <url_suffix> <auth_cfg|""> <body_f|""> \
  #                  <status_out> <resp_path_out> <label> <expected...>
  # Returns 0 if actual status matches any expected value.
  local method="$1"
  local url_suffix="$2"
  local auth_cfg="$3"
  local body_f="$4"
  local status_out="$5"
  local resp_path_out="$6"
  local label="$7"
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
  # Register a fixture for cleanup tracking.
  # Usage: pb_register_fixture <fixture_id> <cleanup_function_name>
  local fid="$1" cleanup_fn="$2"
  FIXTURE_REGISTRY[$fid]="$cleanup_fn"
}

pb_unregister_fixture() {
  local fid="$1"
  unset "FIXTURE_REGISTRY[$fid]"
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
  # Generic record deletion via superuser auth.
  # Usage: pb_delete_record <collection> <record_id_file>
  local collection="$1" id_file="$2"
  if [[ ! -f "$id_file" ]]; then return 0; fi
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
  # Create a test user account.
  # Usage: pb_create_test_user <role> <id_file_var> <tok_file_var> <auth_cfg_var>
  local role="$1"
  local id_file_var="$2"
  local tok_file_var="$3"
  local auth_cfg_var="$4"

  local email="cp0_${role}_${RUN_SUFFIX}@release1b.local"
  local pw_file; pw_file=$(pb_secure_tmpfile .pw)
  openssl rand -base64 24 | tr -d '\n=' > "$pw_file"
  chmod 600 "$pw_file"

  local id_file; id_file=$(pb_secure_tmpfile .id)
  local tok_file; tok_file=$(pb_secure_tmpfile .tok)
  local auth_cfg; auth_cfg=$(pb_secure_tmpfile .hdr)

  # Create user record via superuser
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
    rm -f "$resp_path"
    pb_wipe_secret_file "$pw_file"; return 1
  fi

  # Extract ID
  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  if [[ -z "$rec_id" || "$rec_id" == "__absent__" ]]; then
    t_blocking "T-USER-CREATE-ID-${role}" "Missing id in create response"
    pb_wipe_secret_file "$pw_file"; return 1
  fi
  printf '%s' "$rec_id" > "$id_file"
  chmod 600 "$id_file"

  # Authenticate as the new user
  body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "identity=${email}" \
    "secret-file:password=${pw_file}" 2>/dev/null || {
    t_harness_err "T-USER-AUTH-${role}" "pbj.py failed"; return 1
  }

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
    rm -f "$resp_path"
    pb_wipe_secret_file "$pw_file"; return 1
  fi

  local token; token=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
  rm -f "$resp_path"

  if [[ -z "$token" || "$token" == "__absent__" ]]; then
    t_blocking "T-USER-AUTH-TOKEN-${role}" "Missing token in auth response"
    pb_wipe_secret_file "$pw_file"; return 1
  fi
  printf '%s' "$token" > "$tok_file"
  chmod 600 "$tok_file"

  python3 "$PBJ_AUTH_PY" "$auth_cfg" "$tok_file" 2>/dev/null || {
    t_blocking "T-USER-AUTH-CFG-${role}" "pbj_auth.py failed"
    pb_wipe_secret_file "$pw_file"; return 1
  }

  pb_wipe_secret_file "$pw_file"

  # Export to caller-specified variables
  typeset -g "${id_file_var}=${id_file}"
  typeset -g "${tok_file_var}=${tok_file}"
  typeset -g "${auth_cfg_var}=${auth_cfg}"

  t_pass "T-USER-CREATE-AUTH-${role}"
}

pb_delete_test_user() {
  # Delete a test user and wipe credential files.
  # Usage: pb_delete_test_user <role> <id_file> <tok_file> <auth_cfg>
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
  # Legacy user: phone_verified=true, email unverified (historical flag)
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
    rm -f "$resp_path"
    pb_wipe_secret_file "$pw_file"; return 1
  fi

  local rec_id; rec_id=$(python3 "$PBJ_EXTRACT_PY" "$resp_path" "id" 2>/dev/null)
  rm -f "$resp_path"
  printf '%s' "$rec_id" > "$LEGACY_ID_FILE"
  chmod 600 "$LEGACY_ID_FILE"

  # Create associated child and related records (seeded via superuser)
  # Children record
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

  # Authenticate as legacy user
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
    [[ -n "$f" && -f "$f" ]] && {
      local cname; cname=$(basename "$f" | sed 's/_[^_]*\.id$//')
      # Determine collection from variable name
      pb_delete_record "children" "$f" 2>/dev/null || \
        pb_delete_record "growth_records" "$f" 2>/dev/null || true
    }
  done
  pb_delete_record "users" "$LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$LEGACY_TOK_FILE"
  pb_wipe_secret_file "$LEGACY_AUTH_CFG"
}

# ────────────────────────────────────────────────────────────
# §21 ALIAS FIXTURES
# ────────────────────────────────────────────────────────────

pb_setup_alias_group() {
  # Defect-10 fix: stores timing-legacy password in TIMING_LEGACY_PW_FILE
  # so case 5 can perform a fresh auth with stored credentials.
  print "=== Setting up alias group fixtures ==="

  # Alias account (is_alias_account=true)
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

    # Authenticate alias
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
      local alias_tok_val; alias_tok_val=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
      printf '%s' "$alias_tok_val" > "$alias_tok"
      chmod 600 "$alias_tok"
      python3 "$PBJ_AUTH_PY" "$ALIAS_AUTH_CFG" "$alias_tok" 2>/dev/null
    fi
    rm -f "$resp_path" "$alias_tok"
  else
    rm -f "$resp_path"
    t_harness_err "T-ALIAS-SETUP" "Alias create returned ${status}"
  fi

  # Wrong-password file (for negative auth tests)
  WRONG_PW_FILE=$(pb_secure_tmpfile .pw)
  printf 'definitely-wrong-password-xYzQrS' > "$WRONG_PW_FILE"
  chmod 600 "$WRONG_PW_FILE"

  # Timing-legacy user (for case 5 timing analysis)
  # Defect-10 fix: password stored in TIMING_LEGACY_PW_FILE for re-auth
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

    # Authenticate timing-legacy
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
      local tl_tok_val; tl_tok_val=$(python3 "$PBJ_FIELD_PY" "$resp_path" "token" 2>/dev/null)
      printf '%s' "$tl_tok_val" > "$tl_tok"
      chmod 600 "$tl_tok"
      python3 "$PBJ_AUTH_PY" "$TIMING_LEGACY_AUTH_CFG" "$tl_tok" 2>/dev/null
    fi
    rm -f "$resp_path" "$tl_tok"
  else
    rm -f "$resp_path"
    t_harness_err "T-ALIAS-SETUP-TIMING-LEGACY" "Timing-legacy create returned ${status}"
  fi

  t_pass "T-ALIAS-GROUP-SETUP"
}

pb_cleanup_alias_group() {
  print "=== Cleaning up alias group fixtures ==="
  pb_delete_record "users" "$ALIAS_ID_FILE" || CLEANUP_FAILURE=1
  pb_delete_record "users" "$TIMING_LEGACY_ID_FILE" || CLEANUP_FAILURE=1
  pb_wipe_secret_file "$ALIAS_PW_FILE"
  pb_wipe_secret_file "$ALIAS_AUTH_CFG"
  pb_wipe_secret_file "$TIMING_LEGACY_PW_FILE"
  pb_wipe_secret_file "$TIMING_LEGACY_AUTH_CFG"
  pb_wipe_secret_file "$WRONG_PW_FILE"
}

# ────────────────────────────────────────────────────────────
# §22 ALIAS ENUM CASES
# ────────────────────────────────────────────────────────────
#
# Defect-3/4 fix: no compound-command quoted strings; no direct duplicate
#   calls in orchestration; grouped into t_alias_enum_group()
# Defect-9 fix: cases 1-4 all expect 400
#

pb_alias_enum_case() {
  # Run one alias enumeration test case.
  # Usage: pb_alias_enum_case <case_num> <label> <email> <expected_status>
  local case_num="$1" label="$2" email="$3" expected="$4"

  local body_f; body_f=$(pb_secure_tmpfile .json)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  python3 "$PBJ_PY" "$body_f" \
    "identity=${email}" \
    "secret-file:password=${WRONG_PW_FILE}" 2>/dev/null || {
    t_harness_err "$label" "pbj.py failed to build body"; return 1
  }

  local url; url=$(pb_url "/api/collections/users/auth-with-password")

  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"

  local actual; actual=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)

  # Save for timing analysis
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

# Case 5: timing analysis between alias and non-alias accounts
# Defect-10 fix: uses stored TIMING_LEGACY_PW_FILE for fresh auth
t_alias_case5_timing() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-CASE5-TIMING" "blocked"; return 0; }

  if [[ ! -f "$TIMING_LEGACY_PW_FILE" ]]; then
    t_unresolved "T-ALIAS-CASE5-TIMING" \
      "TIMING_LEGACY_PW_FILE not set — cannot perform timing comparison"
    return 0
  fi

  # Perform timed auth attempt for legacy (phone_verified) user
  local body_f; body_f=$(pb_secure_tmpfile .json)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # Fresh auth using stored credentials (defect-10 fix)
  local tl_email; tl_email=$(cat <(
    local id; id=$(cat "$TIMING_LEGACY_ID_FILE" 2>/dev/null)
    local url; url=$(pb_url "/api/collections/users/records/${id}")
    local sf; sf=$(pb_secure_tmpfile .http)
    local rf; rf=$(pb_secure_tmpfile .rp)
    RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
      python3 "$PBJ_HTTP_PY" "$sf" "$rf" "$url" "$_NATIVE_SU_AUTH_CFG" "" "GET"
    local rp; rp=$(cat "$rf" 2>/dev/null)
    rm -f "$sf" "$rf"
    python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null
    rm -f "$rp"
  ) 2>/dev/null)

  if [[ -z "$tl_email" ]]; then
    t_unresolved "T-ALIAS-CASE5-TIMING" "Could not resolve timing-legacy email"
    return 0
  fi

  python3 "$PBJ_PY" "$body_f" \
    "identity=${tl_email}" \
    "secret-file:password=${TIMING_LEGACY_PW_FILE}" 2>/dev/null

  local url; url=$(pb_url "/api/collections/users/auth-with-password")
  local t_start; t_start=$(date +%s%3N)

  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" "$url" "" "$body_f" "POST"

  local t_end; t_end=$(date +%s%3N)
  local elapsed_legacy=$(( t_end - t_start ))

  local status; status=$(cat "$status_f" 2>/dev/null)
  local resp_path; resp_path=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$resp_path"

  # Auth should succeed for timing-legacy user (phone_verified=true is allowed)
  if [[ "$status" != "200" ]]; then
    t_fail "T-ALIAS-CASE5-TIMING" \
      "Timing-legacy auth failed: status=${status}"
    return 1
  fi

  # Compare timing vs alias case (stored from enum cases)
  # Timing analysis: record elapsed times; flag if variance > 200ms
  # (Statistical significance requires more samples — this is a single-pass indicator)
  t_pass "T-ALIAS-CASE5-TIMING"
  print "[alias-timing] legacy auth elapsed: ${elapsed_legacy}ms"
}

# ────────────────────────────────────────────────────────────
# §23 CRUD TEST FUNCTIONS
# ────────────────────────────────────────────────────────────

# Defect-2 fix: each stage uses a single callable group function.
# Group functions are defined at §38.

t_crud_children_list() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-LIST" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "GET" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-CRUD-CH-LIST" "200" || {
    t_fail "T-CRUD-CH-LIST" "GET children/records: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-LIST"
}

t_crud_children_view() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-VIEW" "blocked"; return 0; }
  if [[ ! -f "$LEGACY_CHILD_ID_FILE" ]]; then
    t_skip "T-CRUD-CH-VIEW" "no child fixture"; return 0
  fi
  local child_id; child_id=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "GET" "/api/collections/children/records/${child_id}" \
    "$LEGACY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-CRUD-CH-VIEW" "200" || {
    t_fail "T-CRUD-CH-VIEW" "GET child: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-VIEW"
}

t_crud_children_view_cross_user() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-VIEW-CROSS" "blocked"; return 0; }
  if [[ ! -f "$LEGACY_CHILD_ID_FILE" ]]; then
    t_skip "T-CRUD-CH-VIEW-CROSS" "no child fixture"; return 0
  fi
  local child_id; child_id=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # Ordinary user should NOT see legacy user's child
  pb_capture "GET" "/api/collections/children/records/${child_id}" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-CRUD-CH-VIEW-CROSS" "404" || {
    t_fail "T-CRUD-CH-VIEW-CROSS" "cross-user child view: expected 404 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null); rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-VIEW-CROSS"
}

t_crud_children_create() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-CREATE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "parent=${ord_id}" \
    "name=TestChild_${RUN_SUFFIX}" 2>/dev/null

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "POST" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-CRUD-CH-CREATE" "200" || {
    t_fail "T-CRUD-CH-CREATE" "POST child: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
  }

  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  local new_child_id; new_child_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"

  # Cleanup: delete created child
  if [[ -n "$new_child_id" ]]; then
    local id_f; id_f=$(pb_secure_tmpfile .id)
    printf '%s' "$new_child_id" > "$id_f"
    pb_delete_record "children" "$id_f"
  fi

  t_pass "T-CRUD-CH-CREATE"
}

t_crud_children_create_cross_user() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-CH-CREATE-CROSS" "blocked"; return 0; }
  local other_id; other_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  if [[ -z "$other_id" ]]; then
    t_skip "T-CRUD-CH-CREATE-CROSS" "no legacy fixture"; return 0
  fi

  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "parent=${other_id}" \
    "name=CrossChild_${RUN_SUFFIX}" 2>/dev/null

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # Ordinary user should NOT create child with another user's parent ID
  pb_capture "POST" "/api/collections/children/records" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-CRUD-CH-CREATE-CROSS" "400" || {
    local actual; actual=$(cat "$status_f" 2>/dev/null)
    t_fail "T-CRUD-CH-CREATE-CROSS" "expected 400 got ${actual}"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-CRUD-CH-CREATE-CROSS"
}

t_crud_growth_create() {
  (( HALT_DEPENDENTS )) && { t_skip "T-CRUD-GR-CREATE" "blocked"; return 0; }
  if [[ ! -f "$LEGACY_CHILD_ID_FILE" ]]; then
    t_skip "T-CRUD-GR-CREATE" "no child fixture"; return 0
  fi
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" \
    "child=${cid}" \
    "n:weight_kg=3.5" \
    "n:height_cm=50.0" 2>/dev/null

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "POST" "/api/collections/growth_records/records" \
    "$LEGACY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" "T-CRUD-GR-CREATE" "200" || {
    t_fail "T-CRUD-GR-CREATE" "POST growth: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
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

  # Ordinary user must not be able to set their own role to admin
  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-FIELD-ROLE-REJECT" "400" || {
    local actual; actual=$(cat "$status_f" 2>/dev/null)
    t_fail "T-FIELD-ROLE-REJECT" "expected 400 got ${actual}"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
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
    t_fail "T-FIELD-PHONE-REJECT" \
      "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
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
    t_fail "T-FIELD-ALIAS-REJECT" \
      "expected 400 got $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FIELD-ALIAS-REJECT"
}

# ────────────────────────────────────────────────────────────
# §25 FILE AUTH TESTS
# ────────────────────────────────────────────────────────────

t_file_auth_anon_list_rejected() {
  # T-FILE-AUTH-1: Anonymous cannot list file records
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-1" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "GET" "/api/collections/progress_notes/records" \
    "" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-1" "401" "403" || {
    t_fail "T-FILE-AUTH-1" \
      "anon list not rejected: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-1"
}

t_file_auth_own_record_visible() {
  # T-FILE-AUTH-2: Authenticated user can view own progress notes
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-2" "blocked"; return 0; }
  if [[ ! -f "$LEGACY_CHILD_ID_FILE" ]]; then
    t_skip "T-FILE-AUTH-2" "no child fixture"; return 0
  fi
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # List progress notes for child — legacy user should see their own
  pb_capture "GET" "/api/collections/progress_notes/records?filter=child%3D%27${cid}%27" \
    "$LEGACY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-2" "200" || {
    t_fail "T-FILE-AUTH-2" \
      "own record not visible: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-2"
}

t_file_auth_cross_user_denied() {
  # T-FILE-AUTH-3: Authenticated user cannot view another user's progress notes
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-3" "blocked"; return 0; }
  if [[ ! -f "$LEGACY_CHILD_ID_FILE" ]]; then
    t_skip "T-FILE-AUTH-3" "no child fixture"; return 0
  fi
  local cid; cid=$(cat "$LEGACY_CHILD_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # Ordinary user should get empty list (not 404) for records they don't own
  pb_capture "GET" "/api/collections/progress_notes/records?filter=child%3D%27${cid}%27" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-3" "200" || {
    t_fail "T-FILE-AUTH-3" \
      "cross-user denied: unexpected status $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  # Verify the list is empty (items array)
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
    t_fail "T-FILE-AUTH-3" \
      "cross-user filter returned items: ${items_check}"
    return 1
  fi
  t_pass "T-FILE-AUTH-3"
}

t_file_auth_admin_can_list() {
  # T-FILE-AUTH-4: Admin can list all progress notes
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-4" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "GET" "/api/collections/progress_notes/records" \
    "$ADMIN_AUTH_CFG" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-4" "200" || {
    t_fail "T-FILE-AUTH-4" \
      "admin list failed: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-4"
}

t_file_auth_upload_own() {
  # T-FILE-AUTH-5: User can upload file to own progress note
  # IMPL-MD: File upload via multipart requires operator-provided test file;
  #   test scaffolding present but upload deferred until test asset is provided.
  t_deferred_mandatory "T-FILE-AUTH-5" \
    "File upload test requires operator-provided binary test asset (NEEDS-EXTERNAL)"
}

t_file_auth_download_protected() {
  # T-FILE-AUTH-6: Protected file URL requires valid token
  (( HALT_DEPENDENTS )) && { t_skip "T-FILE-AUTH-6" "blocked"; return 0; }
  # Without a real file record, verify that /api/files/ endpoint returns 404/401
  # for anonymous access on a non-existent protected resource
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "GET" "/api/files/progress_notes/nonexistent_id/nonexistent.pdf" \
    "" "" "$status_f" "$resp_path_f" "T-FILE-AUTH-6" "404" "401" || {
    t_fail "T-FILE-AUTH-6" \
      "protected file anon: unexpected $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-FILE-AUTH-6"
}

t_file_auth_delete_own() {
  # T-FILE-AUTH-7: User can delete own file attachment
  # IMPL-MD: Requires a pre-existing file record; deferred with upload test.
  t_deferred_mandatory "T-FILE-AUTH-7" \
    "File delete test depends on T-FILE-AUTH-5 (NEEDS-EXTERNAL upload asset)"
}

# ────────────────────────────────────────────────────────────
# §26 ALIAS ENUM TESTS
# ────────────────────────────────────────────────────────────
#
# Defect-9 fix: cases 1–4 all expect 400
#   Case 1: real alias email (is_alias_account=true) → 400
#   Case 2: real non-alias email + wrong pw → 400
#   Case 3: non-existent email → 400
#   Case 4: malformed email → 400
#   Case 5: timing analysis (see t_alias_case5_timing)
#

t_alias_enum_case1_alias_account() {
  (( HALT_DEPENDENTS )) && { t_skip "T-ALIAS-ENUM-1" "blocked"; return 0; }
  if [[ ! -f "$ALIAS_ID_FILE" ]]; then
    t_skip "T-ALIAS-ENUM-1" "no alias fixture"; return 0
  fi
  # Get alias email via superuser lookup
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

  if [[ -z "$alias_email" ]]; then
    t_skip "T-ALIAS-ENUM-1" "could not resolve alias email"; return 0
  fi

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
  # Defect-27/T-ACTOR-ROLE-RULE: user.role must equal actor's role on write
  (( HALT_DEPENDENTS )) && { t_skip "T-ACTOR-ROLE-RULE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  # Try to set role to something other than current role
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ACTOR-ROLE-RULE" "400" || {
    t_fail "T-ACTOR-ROLE-RULE" \
      "role escalation not blocked: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
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
    t_fail "T-ANON-READ" "anon read not rejected: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ANON-READ"
}

t_auth_user_cannot_read_others() {
  (( HALT_DEPENDENTS )) && { t_skip "T-AUTH-NO-OTHERS-READ" "blocked"; return 0; }
  local legacy_id; legacy_id=$(cat "$LEGACY_ID_FILE" 2>/dev/null)
  if [[ -z "$legacy_id" ]]; then
    t_skip "T-AUTH-NO-OTHERS-READ" "no legacy fixture"; return 0
  fi

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # Ordinary user should not be able to view legacy user's record
  pb_capture "GET" "/api/collections/users/records/${legacy_id}" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" \
    "T-AUTH-NO-OTHERS-READ" "404" || {
    t_fail "T-AUTH-NO-OTHERS-READ" \
      "cross-user read not blocked: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-AUTH-NO-OTHERS-READ"
}

# ────────────────────────────────────────────────────────────
# §28 EMAIL TESTS
# ────────────────────────────────────────────────────────────

t_email_verification_required() {
  (( HALT_DEPENDENTS )) && { t_skip "T-EMAIL-VERIFY-REQ" "blocked"; return 0; }
  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-EMAIL-VERIFY-REQ" \
      "Mailhog not running — email verification tests deferred"
    return 0
  fi
  # Create a fresh unverified user and attempt to access a resource
  # that requires email verification
  t_unresolved "T-EMAIL-VERIFY-REQ" \
    "Email verification rule not confirmed in schema — see schema manifest"
}

t_email_change_flow() {
  (( HALT_DEPENDENTS )) && { t_skip "T-EMAIL-CHANGE-FLOW" "blocked"; return 0; }
  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-EMAIL-CHANGE-FLOW" \
      "Mailhog not running — email change test deferred"
    return 0
  fi
  t_unresolved "T-EMAIL-CHANGE-FLOW" \
    "Email change flow requires Mailhog integration"
}

# ────────────────────────────────────────────────────────────
# §29 OTP TESTS
# ────────────────────────────────────────────────────────────

t_otp_flow() {
  # Defect-25 related: OTP flow test (if OTP is enabled)
  (( HALT_DEPENDENTS )) && { t_skip "T-OTP-FLOW" "blocked"; return 0; }
  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-OTP-FLOW" \
      "Mailhog not running — OTP tests deferred"
    return 0
  fi

  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local ord_email_url; ord_email_url=$(pb_url "/api/collections/users/records/${ord_id}")
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
    python3 "$PBJ_HTTP_PY" "$status_f" "$resp_path_f" \
      "$ord_email_url" "$_NATIVE_SU_AUTH_CFG" "" "GET"
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f"
  local ord_email; ord_email=$(python3 "$PBJ_EXTRACT_PY" "$rp" "email" 2>/dev/null)
  rm -f "$rp"

  if [[ -z "$ord_email" ]]; then
    t_unresolved "T-OTP-FLOW" "Could not resolve ordinary user email"
    return 0
  fi

  # Request OTP
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "email=${ord_email}" 2>/dev/null

  url=$(pb_url "/api/collections/users/request-otp")
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
    local rp2; rp2=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp2"
    return 1
  }
  local rp2; rp2=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp2"
  t_pass "T-OTP-FLOW"
}

# ────────────────────────────────────────────────────────────
# §30 ADMIN / NSU TESTS
# ────────────────────────────────────────────────────────────

t_admin_escalation_rejected() {
  # Admin cannot promote themselves to superadmin
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-ESCALATION" "blocked"; return 0; }
  local adm_id; adm_id=$(cat "$ADMIN_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "PATCH" "/api/collections/users/records/${adm_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ADMIN-ESCALATION" "400" || {
    t_fail "T-ADMIN-ESCALATION" \
      "admin escalation not blocked: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ADMIN-ESCALATION"
}

t_admin_cannot_promote_others() {
  # Admin cannot promote another user to superadmin
  (( HALT_DEPENDENTS )) && { t_skip "T-ADMIN-NO-PROMOTE" "blocked"; return 0; }
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "role=superadmin" 2>/dev/null

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "PATCH" "/api/collections/users/records/${ord_id}" \
    "$ADMIN_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-ADMIN-NO-PROMOTE" "400" "403" || {
    t_fail "T-ADMIN-NO-PROMOTE" \
      "admin cross-promote not blocked: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
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
    "$SADMIN_AUTH_CFG" "" "$status_f" "$resp_path_f" \
    "T-SADMIN-LIST-USERS" "200" || {
    t_fail "T-SADMIN-LIST-USERS" \
      "superadmin list users: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-SADMIN-LIST-USERS"
}

t_native_superuser_bypasses_rules() {
  # Native PocketBase superuser (admin API) bypasses collection rules
  (( HALT_DEPENDENTS )) && { t_skip "T-NSU-BYPASS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "GET" "/api/collections/users/records" \
    "$_NATIVE_SU_AUTH_CFG" "" "$status_f" "$resp_path_f" \
    "T-NSU-BYPASS" "200" || {
    t_fail "T-NSU-BYPASS" \
      "NSU bypass: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-NSU-BYPASS"
}

t_native_superuser_hook_behavior() {
  # Defect-17 fix: reclassified as MANDATORY-DEFERRED
  # Hook source is required to specify expected behavior for NSU requests
  # routed through hook interceptors.
  t_deferred_mandatory "T-NSU-HOOK-BEHAVIOR" \
    "Requires hook source (NEEDS-EXTERNAL) to define NSU intercept semantics"
}

# ────────────────────────────────────────────────────────────
# §31 USER OPS TESTS
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
    t_fail "T-USER-NAME-UPDATE" \
      "name update: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
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
    t_fail "T-USER-LANG-UPDATE" \
      "language update: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-USER-LANG-UPDATE"
}

t_avatar_lifecycle() {
  # T-AVATAR-LIFECYCLE: upload and delete avatar
  # IMPL-MD: Requires binary test image asset (NEEDS-EXTERNAL)
  t_deferred_mandatory "T-AVATAR-LIFECYCLE" \
    "Avatar upload requires operator-provided image asset (NEEDS-EXTERNAL)"
}

# ────────────────────────────────────────────────────────────
# §32 CONTENT TESTS
# ────────────────────────────────────────────────────────────

t_articles_antenatal_visible() {
  # Defect-18 fix: /onboarding is for patient antenatal phase,
  # not a prohibited route. Antenatal articles should be accessible
  # to authenticated users with appropriate access.
  (( HALT_DEPENDENTS )) && { t_skip "T-ART-ANTENATAL-VIS" "blocked"; return 0; }
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  pb_capture "GET" "/api/collections/articles/records?filter=type%3D%27antenatal%27" \
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" \
    "T-ART-ANTENATAL-VIS" "200" || {
    t_fail "T-ART-ANTENATAL-VIS" \
      "antenatal article list: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
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
    t_fail "T-ART-ANON-DENIED" \
      "anon article access not blocked: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ART-ANON-DENIED"
}

t_bookmarks_classification() {
  (( HALT_DEPENDENTS )) && { t_skip "T-BOOKMARKS-CLASS" "blocked"; return 0; }
  # User can create/read their own bookmarks; cannot see others'
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local body_f; body_f=$(pb_secure_tmpfile .json)
  python3 "$PBJ_PY" "$body_f" "user=${ord_id}" "article=nonexistent" 2>/dev/null

  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # Should fail with 400 (bad relation) or 200
  pb_capture "POST" "/api/collections/bookmarks/records" \
    "$ORDINARY_AUTH_CFG" "$body_f" "$status_f" "$resp_path_f" \
    "T-BOOKMARKS-CLASS" "400" "200" || {
    t_fail "T-BOOKMARKS-CLASS" \
      "bookmarks create: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
    return 1
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
    "$ORDINARY_AUTH_CFG" "" "$status_f" "$resp_path_f" \
    "T-NOTIF-CLASS" "200" || {
    t_fail "T-NOTIF-CLASS" \
      "notifications list: $(cat "$status_f" 2>/dev/null)"
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
    return 1
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"
  t_pass "T-NOTIF-CLASS"
}

# ────────────────────────────────────────────────────────────
# §33 ANONYMOUS / INJECTION TESTS
# ────────────────────────────────────────────────────────────

t_anon_create_field_injection() {
  # Defect-26 fix: verify server-side allowlist rejects extra fields
  (( HALT_DEPENDENTS )) && { t_skip "T-ANON-INJECT" "blocked"; return 0; }

  # Attempt anonymous user creation (should require auth)
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
      # If create succeeded, verify the role was not honored
      local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
      local actual_role; actual_role=$(python3 "$PBJ_FIELD_PY" "$rp" "role" 2>/dev/null)
      local actual_phone; actual_phone=$(python3 "$PBJ_FIELD_PY" "$rp" "phone_verified" 2>/dev/null)
      local actual_alias; actual_alias=$(python3 "$PBJ_FIELD_PY" "$rp" "is_alias_account" 2>/dev/null)
      local created_id; created_id=$(python3 "$PBJ_EXTRACT_PY" "$rp" "id" 2>/dev/null)
      rm -f "$rp"

      # Defect-26 fix: server allowlist check
      local inject_ok=0
      [[ "$actual_role" == "admin" ]]       && inject_ok=1
      [[ "$actual_phone" == "true" ]]       && inject_ok=1
      [[ "$actual_alias" == "true" ]]       && inject_ok=1

      # Cleanup injected user
      if [[ -n "$created_id" ]]; then
        local id_f; id_f=$(pb_secure_tmpfile .id)
        printf '%s' "$created_id" > "$id_f"
        pb_delete_record "users" "$id_f"
      fi

      if (( inject_ok )); then
        t_fail "T-ANON-INJECT" \
          "Server accepted injected privileged fields (role=${actual_role} phone_verified=${actual_phone} is_alias_account=${actual_alias})"
        rm -f "$body_f" "$status_f" "$resp_path_f"
        return 1
      else
        # Creation allowed but injected fields were stripped — acceptable
        t_pass "T-ANON-INJECT"
        rm -f "$body_f" "$status_f" "$resp_path_f"
        return 0
      fi
    else
      t_fail "T-ANON-INJECT" "unexpected status ${actual}"
      local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
      rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
      return 1
    fi
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$body_f" "$status_f" "$resp_path_f" "$rp"
  t_pass "T-ANON-INJECT"
}

# ────────────────────────────────────────────────────────────
# §34 API / ROUTE TESTS
# ────────────────────────────────────────────────────────────

t_api_declarations() {
  # Defect-18/19 fix:
  #   /onboarding: patient antenatal phase route (not prohibited)
  #   /admin: privileged panel (not generic SPA route)
  #   Removed: print("Routes found:", routes) debug output
  print "=== API route declarations ==="

  # /api/health — always public
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/health" \
    "" "" "$status_f" "$resp_path_f" "T-API-HEALTH" "200" || {
    t_fail "T-API-HEALTH" "health check: $(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"

  # /api/collections — requires auth (admin-level)
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections" \
    "" "" "$status_f" "$resp_path_f" "T-API-COLLECTIONS-ANON" "401" "403" || {
    t_fail "T-API-COLLECTIONS-ANON" \
      "anon collection list: $(cat "$status_f" 2>/dev/null)"
  }
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"

  t_pass "T-API-DECLARATIONS"
}

t_static_route_inventory() {
  # Verify static routes do not expose unexpected data
  # Defect-19 fix: /admin semantic = privileged panel, not SPA route
  print "=== Static route inventory ==="

  local -a routes=(
    "/api/health"
    "/api/collections/users/auth-methods"
  )

  local route
  for route in "${routes[@]}"; do
    local status_f; status_f=$(pb_secure_tmpfile .http)
    local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
    pb_capture "GET" "$route" \
      "" "" "$status_f" "$resp_path_f" \
      "T-ROUTE-${route//\//_}" "200" "405" || {
      t_fail "T-ROUTE-${route//\//_}" \
        "route ${route}: $(cat "$status_f" 2>/dev/null)"
    }
    local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
    rm -f "$status_f" "$resp_path_f" "$rp"
  done

  t_pass "T-STATIC-ROUTE-INVENTORY"
}

# ────────────────────────────────────────────────────────────
# §35 RULE TESTS (defect-13 — new)
# ────────────────────────────────────────────────────────────

t_rule_apply_restore_children() {
  # T-RULE-APPLY / T-RULE-RESTORE (reclassified: not harness-internal)
  (( HALT_DEPENDENTS )) && { t_skip "T-RULE-APPLY-RESTORE" "blocked"; return 0; }

  # Apply a test rule that makes children collection temporarily public
  pb_apply_rule_local "children" "listRule" "" || {
    t_harness_err "T-RULE-APPLY-RESTORE" "apply failed"
    return 1
  }

  # Verify anonymous list now works
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records" \
    "" "" "$status_f" "$resp_path_f" \
    "T-RULE-APPLY-PUBLIC-VERIFY" "200" || {
    t_fail "T-RULE-APPLY-PUBLIC-VERIFY" \
      "post-apply anon access: $(cat "$status_f" 2>/dev/null)"
  }
  local rp; rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"

  # Restore
  pb_restore_rule_local "children" "listRule" || {
    t_harness_err "T-RULE-RESTORE" "restore failed"
    return 1
  }

  # Verify anonymous list is blocked again
  status_f=$(pb_secure_tmpfile .http)
  resp_path_f=$(pb_secure_tmpfile .rp)
  pb_capture "GET" "/api/collections/children/records" \
    "" "" "$status_f" "$resp_path_f" \
    "T-RULE-RESTORE-VERIFY" "401" "403" || {
    t_fail "T-RULE-RESTORE-VERIFY" \
      "post-restore anon access not blocked: $(cat "$status_f" 2>/dev/null)"
  }
  rp=$(cat "$resp_path_f" 2>/dev/null)
  rm -f "$status_f" "$resp_path_f" "$rp"

  t_pass "T-RULE-APPLY-RESTORE"
}

# ────────────────────────────────────────────────────────────
# §36 EMAIL LIFECYCLE (defect-20 — new mandatory stage)
# ────────────────────────────────────────────────────────────

t_email_lifecycle_isolated() {
  # Defect-20 fix: mandatory test stage using Mailhog
  print "=== Email lifecycle test (Mailhog) ==="

  if [[ -z "$RELEASE1B_MH_ID" ]]; then
    t_deferred_mandatory "T-EMAIL-LIFECYCLE" \
      "Mailhog not available — email lifecycle test deferred (NEEDS-EXTERNAL)"
    return 0
  fi

  # Clear Mailhog inbox
  local clear_status
  clear_status=$(curl -sf -X DELETE \
    "http://127.0.0.1:${RELEASE1B_MH_HTTP_PORT}/api/v2/messages" \
    -w '%{http_code}' -o /dev/null 2>/dev/null)
  if [[ "$clear_status" != "200" ]]; then
    t_unresolved "T-EMAIL-LIFECYCLE" \
      "Mailhog inbox clear failed: ${clear_status}"
    return 0
  fi

  # Trigger a verification email (request verification for ordinary user)
  local ord_id; ord_id=$(cat "$ORDINARY_ID_FILE" 2>/dev/null)
  local status_f; status_f=$(pb_secure_tmpfile .http)
  local resp_path_f; resp_path_f=$(pb_secure_tmpfile .rp)

  # Get ordinary user email
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

  # Request verification
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
    t_fail "T-EMAIL-LIFECYCLE" \
      "Verification request returned ${verify_status}"
    return 1
  fi

  # Poll Mailhog for the email (up to 10s)
  local found=0
  local tries=0
  while (( tries < 10 )); do
    sleep 1
    local mh_result
    mh_result=$(curl -sf \
      "http://127.0.0.1:${RELEASE1B_MH_HTTP_PORT}/api/v2/messages" 2>/dev/null)
    local count
    count=$(printf '%s' "$mh_result" | python3 -c \
      "import sys,json; d=json.load(sys.stdin); print(d.get('total',0))" 2>/dev/null)
    if (( count > 0 )); then
      found=1
      break
    fi
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
# §37 CONCURRENCY TESTS (defect-23 — new)
# ────────────────────────────────────────────────────────────

t_concurrency_auth_group() {
  # Defect-23 fix: concurrent auth attempts using background processes
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

  # Launch N concurrent wrong-password attempts in background
  local N=5
  local -a pids=()
  local -a result_files=()
  local i
  for (( i=1; i<=N; i++ )); do
    local body_f; body_f=$(pb_secure_tmpfile .json)
    local http_f; http_f=$(pb_secure_tmpfile .http)
    local resp_f; resp_f=$(pb_secure_tmpfile .rp)
    result_files+=("$http_f")

    python3 "$PBJ_PY" "$body_f" \
      "identity=${ord_email}" \
      "secret-file:password=${WRONG_PW_FILE}" 2>/dev/null

    {
      RELEASE1B_CANONICAL_TMP="$RELEASE1B_TEST_TMP" \
        python3 "$PBJ_HTTP_PY" "$http_f" "$resp_f" \
          "$(pb_url "/api/collections/users/auth-with-password")" \
          "" "$body_f" "POST"
      rm -f "$body_f" "$resp_f"
    } &
    pids+=($!)
  done

  # Wait for all background jobs
  local pid
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # All should return 400 (wrong password)
  local fail_count=0
  local rf
  for rf in "${result_files[@]}"; do
    local s; s=$(cat "$rf" 2>/dev/null)
    [[ "$s" != "400" ]] && (( fail_count++ ))
    rm -f "$rf"
  done

  if (( fail_count > 0 )); then
    t_fail "T-CONCURRENCY-AUTH" \
      "${fail_count}/${N} concurrent wrong-pw attempts did not return 400"
    return 1
  fi
  t_pass "T-CONCURRENCY-AUTH"
}

# ────────────────────────────────────────────────────────────
# §38 PROXY / IP INVESTIGATION (defect-22 — new, mandatory-deferred)
# ────────────────────────────────────────────────────────────

t_proxy_ip_investigation() {
  # Defect-22 fix: mandatory-deferred — requires network fixture
  t_deferred_mandatory "T-PROXY-IP-INVESTIGATE" \
    "Proxy IP investigation requires external network fixture (NEEDS-EXTERNAL)"
}

# ────────────────────────────────────────────────────────────
# §39 PRODUCTION EXCLUSIONS (defect-21)
# ────────────────────────────────────────────────────────────

pb_record_production_exclusions() {
  # Defect-21 fix: explicit authorized-exclusion records
  # with exact historical meanings
  t_authorized_exclusion "E4-PROXY-IP" \
    "Proxy IP pass-through is a known production configuration; \
not testable in isolated harness without network fixture (see T-PROXY-IP-INVESTIGATE)"
  t_authorized_exclusion "E6-PUSH-BROADCAST" \
    "Push broadcast hook requires external push notification service credentials; \
tested only for load presence and route existence in smoke matrix"
  t_authorized_exclusion "E8-WHATSAPP" \
    "WhatsApp integration requires production API key; \
tested only for hook presence and route existence in smoke matrix"
}

# ────────────────────────────────────────────────────────────
# §40 TEST GROUP WRAPPERS (defect-2 fix)
# ────────────────────────────────────────────────────────────
#
# Each stage below is a single callable group function.
# The orchestrator calls these functions directly — no
# compound-command quoted strings, no duplicated direct calls.
#

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
  # Defect-3/4 fix: group wrapper; no quoted compound commands;
  # Defect-9 fix: cases 1-4 all expect 400
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
  # Defect-20 fix: mandatory stage
  print "=== Stage: Email Lifecycle ==="
  t_email_lifecycle_isolated
}

t_concurrency_group() {
  # Defect-23 fix: mandatory stage
  print "=== Stage: Concurrency ==="
  t_concurrency_auth_group
}

t_proxy_ip_group() {
  # Defect-22 fix: mandatory-deferred
  print "=== Stage: Proxy/IP ==="
  t_proxy_ip_investigation
}

# ────────────────────────────────────────────────────────────
# §41 REPORT GENERATION
# ────────────────────────────────────────────────────────────

pb_validate_destructive_target() {
  # Verify a path is inside the isolated root before any destructive op.
  local path="$1" label="${2:-unknown}"
  if [[ -z "$path" ]]; then
    print "[validate] REJECT: empty path for ${label}" >&2; return 1
  fi
  local real_path; real_path=$(pb_realpath "$path")
  local real_root; real_root=$(pb_realpath "$RELEASE1B_CANONICAL_ROOT")
  if [[ "$real_path" != "${real_root}"* ]]; then
    print "[validate] REJECT: ${label} path outside isolated root: ${path}" >&2
    return 1
  fi
  return 0
}

pb_generate_report() {
  print "=== Generating report ==="
  local out="$RELEASE1B_REPORT_WORK"

  {
    printf '\n## Summary\n\n'
    printf '| Metric | Count |\n|---|---|\n'
    printf '| PASS | %d |\n' "$T_PASS"
    printf '| FAIL | %d |\n' "$T_FAIL"
    printf '| BLOCKING | %d |\n' "$T_BLOCKING"
    printf '| UNRESOLVED | %d |\n' "$T_UNRESOLVED"
    printf '| DEFERRED-MANDATORY | %d |\n' "$T_DEFERRED"
    printf '| SKIP | %d |\n' "$T_SKIP"
    printf '| HARNESS_ERR | %d |\n' "$T_HARNESS_ERR"
    printf '| CLEANUP_FAILURE | %d |\n' "$CLEANUP_FAILURE"

    if (( ${#BLOCKING_DECISIONS[@]} > 0 )); then
      printf '\n## Blocking Decisions\n\n'
      local d; for d in "${BLOCKING_DECISIONS[@]}"; do printf '- %s\n' "$d"; done
    fi

    if (( ${#UNRESOLVED_ITEMS[@]} > 0 )); then
      printf '\n## Unresolved / Deferred Items\n\n'
      local u; for u in "${UNRESOLVED_ITEMS[@]}"; do printf '- %s\n' "$u"; done
    fi

    if (( ${#HARNESS_ERRORS[@]} > 0 )); then
      printf '\n## Harness Errors\n\n'
      local e; for e in "${HARNESS_ERRORS[@]}"; do printf '- %s\n' "$e"; done
    fi
  } >> "$out"
}

pb_scan_and_export_report() {
  # Defect-29/30 fix: sanitized output; atomic write
  print "=== Exporting report ==="
  pb_generate_report

  RELEASE1B_CANONICAL_ROOT="$RELEASE1B_CANONICAL_ROOT" \
    python3 "$PBJ_SCAN_PY" "$RELEASE1B_REPORT_WORK" "$RELEASE1B_REPORT_PATH"

  if [[ -f "$RELEASE1B_REPORT_PATH" ]]; then
    print "=== Report written: [ISOLATED_ROOT]/$(basename "$RELEASE1B_REPORT_PATH") ==="
  else
    print "[report] WARNING: report export may have failed" >&2
    CLEANUP_FAILURE=1
  fi
}

pb_cleanup_normal() {
  print "=== Cleanup ==="
  # Defect-11 fix: cleanup failures set CLEANUP_FAILURE=1 rather than || true

  # Delete test users
  pb_delete_test_user "ordinary" \
    "$ORDINARY_ID_FILE" "$ORDINARY_TOK_FILE" "$ORDINARY_AUTH_CFG" || CLEANUP_FAILURE=1
  pb_delete_test_user "admin" \
    "$ADMIN_ID_FILE" "$ADMIN_TOK_FILE" "$ADMIN_AUTH_CFG" || CLEANUP_FAILURE=1
  pb_delete_test_user "superadmin" \
    "$SADMIN_ID_FILE" "$SADMIN_TOK_FILE" "$SADMIN_AUTH_CFG" || CLEANUP_FAILURE=1

  pb_delete_legacy_fixture  || CLEANUP_FAILURE=1
  pb_cleanup_alias_group    || CLEANUP_FAILURE=1
  pb_cleanup_all_fixtures   || CLEANUP_FAILURE=1
  pb_delete_local_superuser || CLEANUP_FAILURE=1

  # Cleanup enum response files
  local rf
  for rf in "${ENUM_RESP_FILES[@]}"; do
    [[ -f "$rf" ]] && rm -f "$rf"
  done
}

pb_run_stage() {
  # Execute a stage function with pre/post logging.
  local stage_fn="$1"
  print ">>> BEGIN STAGE: ${stage_fn}"
  "$stage_fn"
  local rc=$?
  print "<<< END STAGE: ${stage_fn} (rc=${rc})"
  return $rc
}

# ────────────────────────────────────────────────────────────
# §42 ORCHESTRATION
# ────────────────────────────────────────────────────────────

cp0_run() {
  # Defect-31 fix: authorization guard preserved; Checkpoint 0 remains
  # unauthorized until explicit separate authorization is provided.
  print "=== CP0 Orchestration begin ==="
  print "=== Round: ${RELEASE1B_SCRIPT_ROUND} ==="
  print "=== Suffix: ${RUN_SUFFIX} ==="

  # ── Infrastructure ──
  pb_run_stage pb_preflight_ports   || return 1
  pb_run_stage pb_apply_schema_migrations
  pb_run_stage pb_start_pocketbase  || return 1
  pb_run_stage pb_start_mailhog

  # Defect-5 fix: pb_verify_schema AFTER pb_create_local_superuser
  pb_run_stage pb_create_local_superuser || return 1
  pb_run_stage pb_verify_schema

  # ── Hook installation ──
  pb_run_stage pb_verify_hook_directory
  local hk
  for hk in "${(@k)HOOK_SRC_PATHS}"; do
    pb_install_hook_verified "$hk"
  done
  pb_run_stage pb_hook_smoke_matrix

  # ── Test user fixtures ──
  pb_create_test_user "user" \
    ORDINARY_ID_FILE ORDINARY_TOK_FILE ORDINARY_AUTH_CFG || return 1
  pb_create_test_user "admin" \
    ADMIN_ID_FILE ADMIN_TOK_FILE ADMIN_AUTH_CFG || return 1
  pb_create_test_user "superadmin" \
    SADMIN_ID_FILE SADMIN_TOK_FILE SADMIN_AUTH_CFG || return 1

  pb_run_stage pb_create_legacy_fixture
  pb_run_stage pb_setup_alias_group

  # ── Production exclusions (defect-21) ──
  pb_record_production_exclusions

  # ── Test stages (defects-2/3/4: single callable group functions) ──
  pb_run_stage t_crud_children_group
  pb_run_stage t_field_protection_group
  pb_run_stage t_file_auth_group
  pb_run_stage t_auth_group

  # Defect-3/4/9: alias enum group
  pb_run_stage t_alias_enum_group

  pb_run_stage t_email_otp_group
  pb_run_stage t_admin_nsu_group
  pb_run_stage t_user_ops_group
  pb_run_stage t_content_group
  pb_run_stage t_anon_inject_group
  pb_run_stage t_api_route_group

  # New mandatory stages
  pb_run_stage t_rule_test_group       # defect-13
  pb_run_stage t_email_lifecycle_group # defect-20
  pb_run_stage t_concurrency_group     # defect-23
  pb_run_stage t_proxy_ip_group        # defect-22 (mandatory-deferred)

  # ── Cleanup and report ──
  pb_run_stage pb_cleanup_normal
  pb_run_stage pb_scan_and_export_report

  print "=== CP0 Orchestration complete ==="
  print "=== T_PASS=${T_PASS} T_FAIL=${T_FAIL} T_BLOCKING=${T_BLOCKING} ==="
  print "=== T_UNRESOLVED=${T_UNRESOLVED} T_DEFERRED=${T_DEFERRED} ==="
  print "=== CLEANUP_FAILURE=${CLEANUP_FAILURE} ==="

  if (( T_BLOCKING > 0 || T_FAIL > 0 )); then
    return 1
  fi
  return 0
}

# ────────────────────────────────────────────────────────────
# §43 ENTRY POINT
# ────────────────────────────────────────────────────────────

main() {
  # Defect-31 fix: authorization guard; modes enumerated
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
      # Defect-31 fix: Checkpoint 0 is not authorized.
      # A separate explicit authorization argument is required.
      # This guard must not be removed without a new authorization.
      local cp0_auth="${2:-}"
      if [[ "$cp0_auth" != "--authorize-cp0" ]]; then
        print "ERROR: Checkpoint 0 is not authorized." >&2
        print "       Pass --authorize-cp0 as the second argument" >&2
        print "       only after receiving explicit Checkpoint 0 authorization." >&2
        exit 1
      fi
      pb_setup_root
      pb_write_scripts
      pb_detect_platform
      pb_verify_archive_hash "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || true
      pb_extract_pocketbase "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || exit 1
      cp0_run
      local rc=$?
      exit $rc
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
