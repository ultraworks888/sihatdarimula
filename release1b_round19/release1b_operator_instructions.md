# Release 1B — Checkpoint 0 Operator Instructions
# Platform: macOS (zsh) — Round 19

## Purpose

These instructions enable a human operator to:
1. Download PocketBase v0.29.3 from the official GitHub release
2. Verify available integrity evidence
3. Create an isolated test environment
4. Deploy the OTP test adapter
5. Run the Round 19 Checkpoint 0 harness
6. Retain the sanitized report
7. Clean up deterministically

**No production system may be contacted during any of these steps.**

---

## Prerequisites

Run from a Terminal with zsh. Verify the following tools are present:

```zsh
#!/usr/bin/env zsh

# Verify required tools
for tool in curl unzip zsh python3 openssl shasum lsof; do
  if ! command -v $tool &>/dev/null; then
    print "MISSING: $tool — install before proceeding" >&2
    exit 1
  fi
done
print "All required tools present."

# Verify zsh version
print "zsh version: $(zsh --version)"

# Verify python3 version (3.8+ required)
python3 --version

# Verify not running as root
if [[ $EUID -eq 0 ]]; then
  print "ERROR: Do not run as root." >&2
  exit 1
fi
```

---

## Step 1 — Record Platform and Architecture

```zsh
# Detect OS and architecture
_os=$(uname -s | tr '[:upper:]' '[:lower:]')
_arch=$(uname -m)
case "$_arch" in
  arm64|aarch64) _arch="arm64" ;;
  x86_64)        _arch="amd64" ;;
  *) print "Unsupported architecture: ${_arch}" >&2; exit 1 ;;
esac
case "$_os" in
  darwin|linux) : ;;
  *) print "Unsupported OS: ${_os}" >&2; exit 1 ;;
esac

PB_VERSION="0.29.3"
PB_PLATFORM="${_os}_${_arch}"
PB_ARCHIVE="pocketbase_${PB_VERSION}_${PB_PLATFORM}.zip"
PB_RELEASE_URL="https://github.com/pocketbase/pocketbase/releases/tag/v${PB_VERSION}"
PB_DOWNLOAD_URL="https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/${PB_ARCHIVE}"

print "Platform    : ${PB_PLATFORM}"
print "Archive name: ${PB_ARCHIVE}"
print "Release URL : ${PB_RELEASE_URL}"
print "Download URL: ${PB_DOWNLOAD_URL}"
```

**Record these values in the Checkpoint 0 report before proceeding.**

---

## Step 2 — Integrity Evidence

Visit the official release page:
```
https://github.com/pocketbase/pocketbase/releases/tag/v0.29.3
```

**Authoritative checksum policy:**

As of the preparation date of this document (August 2026), PocketBase releases on GitHub do not publish a separate `.sha256` or `.checksums` file alongside the release archives. GitHub provides only the archive downloads.

**If an authoritative checksum file is found on the release page:**
- Download it, record its URL, and use it to verify the archive in Step 3.
- Record the exact checksum file URL and its contents in the report.

**If no authoritative checksum or signature is published:**
- State this explicitly in the Checkpoint 0 report.
- Record the downloaded archive size (`wc -c < ${PB_ARCHIVE}`) and its SHA-256 (`shasum -a 256 ${PB_ARCHIVE}`).
- Treat the hash as a locally observed value (not externally verified).
- Do **not** proceed to binary-dependent testing if the integrity requirement mandates an authoritative checksum and none is available — report this as a block.
- Contact the project owner to obtain authoritative integrity evidence if required.

The harness constant `PB_EXPECTED_SHA256` remains `UNRESOLVED__NEEDS_EXTERNAL__pb_archive_sha256` until the operator provides an authoritative value. If the operator proceeds without an authoritative checksum, note this in the report as `T-PKG-ARCHIVE-HASH: UNRESOLVED`.

---

## Step 3 — Download and Locally Verify the Archive

```zsh
# Create a secure download directory
_dl_dir=$(mktemp -d /tmp/pb_dl_XXXXXX)
chmod 700 "$_dl_dir"
_archive_path="${_dl_dir}/${PB_ARCHIVE}"

# Download from the official GitHub release
print "Downloading: ${PB_DOWNLOAD_URL}"
curl -fL --progress-bar \
  -o "$_archive_path" \
  "$PB_DOWNLOAD_URL" \
  || { print "Download failed." >&2; exit 1 }

# Record archive size and SHA-256
_archive_size=$(wc -c < "$_archive_path" | tr -d ' ')
_archive_sha256=$(shasum -a 256 "$_archive_path" | awk '{print $1}')
print "Archive size  : ${_archive_size} bytes"
print "Archive SHA256: ${_archive_sha256}"
print "Record both in the Checkpoint 0 report."

# If an authoritative checksum is available, verify here:
# _expected_sha256="<value from release page>"
# if [[ "$_archive_sha256" != "$_expected_sha256" ]]; then
#   print "INTEGRITY FAILURE: checksum mismatch" >&2
#   rm -rf "$_dl_dir"
#   exit 1
# fi
# print "Integrity verified against authoritative checksum."
```

---

## Step 4 — Extract and Verify Binary Version

```zsh
# Extract the pocketbase binary only
unzip -o "$_archive_path" pocketbase -d "$_dl_dir" \
  || { print "Extraction failed." >&2; exit 1 }

_pb_bin="${_dl_dir}/pocketbase"
chmod 700 "$_pb_bin"

# Verify reported version
_pb_reported=$("$_pb_bin" version 2>&1 | head -1)
print "PocketBase reported: ${_pb_reported}"

if [[ "$_pb_reported" != *"0.29.3"* ]]; then
  print "VERSION MISMATCH: expected v0.29.3" >&2
  exit 1
fi
print "Version verified: v0.29.3"
```

**Record `_pb_reported` verbatim in the Checkpoint 0 report.**

---

## Step 5 — Configure Harness Constants

Before running the harness, set the following constants in `release1b_cp0.zsh` (§3 CONSTANTS). All `UNRESOLVED__NEEDS_EXTERNAL__` values must be replaced with actual values:

| Constant | Status | Action |
|---|---|---|
| `PB_EXPECTED_SHA256[darwin_arm64]` etc. | NEEDS-EXTERNAL | Set to authoritative hash from Step 2, or leave UNRESOLVED and note in report |
| `HOOK_SRC_PATHS[emergency_hardening]` | NEEDS-EXTERNAL | Set to absolute path of `emergency_users_hardening.pb.js` |
| `HOOK_SRC_PATHS[auth_whatsapp_otp]` | NEEDS-EXTERNAL | Set to absolute path of `auth_whatsapp_otp.pb.js` |
| `HOOK_SRC_PATHS[push_broadcast]` | NEEDS-EXTERNAL | Set to absolute path of `push_broadcast.pb.js` |
| `HOOK_SRC_PATHS[whatsapp]` | NEEDS-EXTERNAL | Set to absolute path of `whatsapp.pb.js` |
| `HOOK_EXPECTED_SHA256[*]` | NEEDS-EXTERNAL | Set to `shasum -a 256 <hook_file>` output for each |
| `HOOK_PROBE_ROUTES[*]` | NEEDS-EXTERNAL | Set to each hook's health/probe route path |
| `RELEASE1B_SCHEMA_SRC` | NEEDS-EXTERNAL | Set to absolute path of `pb_migrations/` directory |
| `HOOK_OTP_PHONE_ROUTE` | RESOLVED | `/api/auth/request-whatsapp-otp` — pre-filled in R19 |
| `HOOK_OTP_MOCK_CONTROL_ROUTE` | DESIGNED | `/api/test/otp-control` — requires adapter (Step 6) |

```zsh
# Example: compute hook SHA256 values
shasum -a 256 /path/to/pb_hooks/emergency_users_hardening.pb.js
shasum -a 256 /path/to/pb_hooks/auth_whatsapp_otp.pb.js
shasum -a 256 /path/to/pb_hooks/push_broadcast.pb.js
shasum -a 256 /path/to/pb_hooks/whatsapp.pb.js
```

---

## Step 6 — Deploy Local OTP Test Adapter

The production `auth_whatsapp_otp.pb.js` hook calls Meta Cloud API directly. For isolated testing, a local adapter must be deployed **only to the isolated harness hooks directory**, not to production.

The adapter file `release1b_otp_test_adapter.pb.js` (separate deliverable, NEEDS-EXTERNAL as of R19) must:
- Replace `auth_whatsapp_otp.pb.js` in the isolated hooks directory
- Register the same routes: `POST /api/auth/request-whatsapp-otp`, `POST /api/auth/verify-whatsapp-otp`
- Register a control route: `POST /api/test/otp-control` and `GET /api/test/otp-read/{phone}`
- Never call `graph.facebook.com` or any Meta endpoint
- Store OTP in `phone_otps` table identically to production
- Record send attempts for rate-limit invariant testing
- Never log OTP values or phone numbers

**Adapter not yet written as of R19. T-CONCURRENCY-OTP-SEND and T-OTP-FLOW remain MANDATORY-DEFERRED until the adapter is delivered.**

If the adapter is available:
```zsh
# Copy adapter to isolated hooks dir (done by the harness automatically if HOOK_SRC_PATHS set correctly)
# The harness will copy all files listed in HOOK_SRC_PATHS to the isolated root's pb_hooks/
# Ensure the adapter replaces auth_whatsapp_otp.pb.js in the isolated dir, not alongside it
```

---

## Step 7 — Run the Harness

```zsh
# Set strict options
setopt NO_UNSET PIPE_FAIL

# Make executable
chmod 700 /path/to/release1b_round19/release1b_cp0.zsh

# Syntax check first
zsh -n /path/to/release1b_round19/release1b_cp0.zsh \
  && print "Syntax check: PASS" \
  || { print "Syntax check: FAIL" >&2; exit 1 }

# Harness self-test (no network, no PocketBase)
/path/to/release1b_round19/release1b_cp0.zsh --harness-check \
  || { print "Self-test failed." >&2; exit 1 }

# Preflight only (port checks)
/path/to/release1b_round19/release1b_cp0.zsh --preflight \
  || { print "Preflight failed — check port 8090." >&2; exit 1 }

# Full run (requires authorization token from cp0 authorization)
/path/to/release1b_round19/release1b_cp0.zsh --run --authorize-cp0
_harness_rc=$?
print "Harness exit code: ${_harness_rc}"
# rc=0: PASS; rc=1: FAIL; rc=2: INCOMPLETE
```

**The harness creates its own isolated root under `${TMPDIR:-/tmp}/release1b_cp0_<suffix>/`. Do not specify the root manually.**

---

## Step 8 — Retain the Sanitized Report

The harness writes a sanitized report to:
```
${TMPDIR:-/tmp}/release1b_cp0_<suffix>/release1b_cp0_report_<suffix>.md
```

Before the harness cleans up the isolated root, copy the report:

```zsh
# The harness emits the report path to stdout on completion.
# Copy before cleanup (cleanup runs automatically on EXIT trap).
# The harness retains the root on cleanup failure — check CLEANUP_FAILURE.

# Alternatively, set a retention directory:
_retain_dir="${HOME}/cp0_reports/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$_retain_dir"
# Then copy the report from the path printed by the harness.
```

---

## Step 9 — Integrity Verification of the R19 Package

Before running, verify the R19 package against the authoritative checksums in `release1b_round19_checksums.sha256`:

```zsh
cd /path/to/release1b_round19/

# Verify each artifact (format: SHA256  BYTES  FILENAME)
while read -r sha bytes fname; do
  [[ "$sha" == \#* ]] && continue
  [[ -z "$sha" ]] && continue

  actual_sha=$(shasum -a 256 "$fname" | awk '{print $1}')
  actual_bytes=$(wc -c < "$fname" | tr -d ' ')

  if [[ "$actual_sha" == "$sha" && "$actual_bytes" == "$bytes" ]]; then
    print "OK: $fname"
  else
    print "FAIL: $fname"
    print "  Expected: $sha  $bytes"
    print "  Actual:   $actual_sha  $actual_bytes"
  fi
done < release1b_round19_checksums.sha256
```

---

## Step 10 — Cleanup

The harness performs deterministic cleanup via its EXIT trap:
- Sends SIGTERM to the isolated PocketBase instance
- Watchdog enforces 6-second grace before SIGKILL
- Wipes credential files via `dd` + `rm`
- Removes isolated root directory

If the harness exits with `CLEANUP_FAILURE=1`, the isolated root is retained for inspection. Manually clean up:

```zsh
# Manual cleanup (only if harness cleanup failed)
_root="/tmp/release1b_cp0_<suffix>"  # from harness output
rm -rf "$_root"
print "Manual cleanup done."
```

---

## Prohibited Actions

During this entire procedure:

- Do not contact `app.sihatdarimula.my` or any production endpoint
- Do not copy `pb_data/` from production
- Do not use production credentials, tokens, or settings files
- Do not send WhatsApp messages, emails, or push notifications
- Do not start any service that could connect to Meta, OneSignal, Brevo, or any live provider
- Do not proceed to Checkpoint 1 after the report is produced

---

## Report Section Template

The operator must include the following in the Checkpoint 0 report:

```
## PocketBase v0.29.3 Provenance

- Release page: https://github.com/pocketbase/pocketbase/releases/tag/v0.29.3
- Platform: <darwin_arm64 | darwin_amd64 | linux_amd64 | linux_arm64>
- Archive filename: <pocketbase_0.29.3_PLATFORM.zip>
- Download URL: <exact URL used>
- Archive size (bytes): <wc -c output>
- Archive SHA-256: <shasum -a 256 output>
- Authoritative checksum published: <YES with URL and value | NO>
- Integrity verification result: <VERIFIED | LOCALLY OBSERVED ONLY | BLOCKED>
- Binary version output: <./pocketbase version output verbatim>
- Version verified: <YES | NO>

## Network Activity

- Authorized downloads: <list>
- Production contacted: NO
- Other network: NONE
```

---

## Stopping Conditions

Stop the procedure and do not run the harness if:

1. The binary version does not report `v0.29.3`.
2. An authoritative checksum is available but the download does not match it.
3. Port 8090 is in use and cannot be freed.
4. Any emergency blocking test (`T-INJECT-CREATE-ANON-ADMIN` etc.) fails — stop after recording the result and do not proceed to publication.
5. `CLEANUP_FAILURE=1` — inspect isolated root before concluding.

---

*Round 19 | Prepared for operator execution | Application publication remains unauthorized*
