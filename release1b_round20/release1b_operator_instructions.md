# Release 1B — Round 20 Operator Instructions
# Checkpoint 0 Authorization Status: AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

---

## Prerequisites

- macOS (Apple Silicon or Intel) running zsh 5.9+
- `curl`, `unzip`, `openssl`, `shasum`, `wc`, `python3 ≥ 3.9`, `lsof` installed
- No production access; no network contact with `app.sihatdarimula.my`
- Isolated working directory; no other PocketBase process on port 8090

---

## §1 Package Integrity

Before any other step, verify the package.

```zsh
# From the release1b_round20/ directory:
chmod +x release1b_round20_checksums.sha256
./release1b_round20_checksums.sha256 --compute
```

The `--compute` run hashes all nine covered artifacts and writes
`release1b_round20_checksums.lock`. Record the self-integrity values printed
at the end (SHA-256 and byte count of `release1b_round20_checksums.sha256`
itself). Archive the lock file separately.

On any subsequent verification:

```zsh
./release1b_round20_checksums.sha256 --verify
```

Stop if `--verify` exits nonzero. Do not proceed with a modified package.

---

## §2 Resolve NEEDS-EXTERNAL Constants

Before running the harness, fill in every `UNRESOLVED__NEEDS_EXTERNAL__*`
constant at the top of `release1b_cp0.zsh`:

| Constant | How to fill |
|---|---|
| `HOOK_SRC_PATHS[emergency_hardening]` | Absolute path to `emergency_users_hardening.pb.js` in the project repository |
| `HOOK_SRC_PATHS[push_broadcast]` | Absolute path to `push_broadcast.pb.js` |
| `HOOK_SRC_PATHS[whatsapp]` | Absolute path to `whatsapp.pb.js` |
| `HOOK_EXPECTED_SHA256[*]` | `shasum -a 256 <hookfile>` for each hook source |
| `HOOK_PROBE_ROUTES[push_broadcast]` | The registered HTTP route for push_broadcast smoke probe |
| `HOOK_PROBE_ROUTES[whatsapp]` | The registered HTTP route for whatsapp smoke probe |
| `RELEASE1B_SCHEMA_SRC` | Absolute path to `pb_migrations/` directory |

**Note:** `auth_whatsapp_otp.pb.js` is intentionally absent from `HOOK_SRC_PATHS`.
The OTP test adapter (`release1b_otp_test_adapter.pb.js`) replaces it in the
isolated environment. The source project hook is never modified.

---

## §3 PocketBase v0.29.3 Download and Integrity Verification

### 3a. Retrieve Release Metadata via GitHub API (mandatory)

```zsh
# Public endpoint — no authentication required.
curl -sf \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/pocketbase/pocketbase/releases/tags/v0.29.3" \
  -o pb_release_v0.29.3.json
```

**Stop immediately** if curl returns nonzero or the file is missing.

### 3b. Extract Asset Metadata for Your Platform

Determine your archive filename from the `PB_ARCHIVE_NAME` map in
`release1b_cp0.zsh` (e.g., `pocketbase_0.29.3_darwin_arm64.zip`).

```python3
# Run this Python snippet to extract asset metadata:
import json, sys

archive_name = "pocketbase_0.29.3_darwin_arm64.zip"  # adjust for your platform

with open("pb_release_v0.29.3.json") as f:
    release = json.load(f)

assets = [a for a in release.get("assets", []) if a["name"] == archive_name]
if len(assets) != 1:
    print(f"ERROR: expected exactly 1 matching asset, found {len(assets)}")
    sys.exit(1)

asset = assets[0]
print(f"asset_id:             {asset['id']}")
print(f"size:                 {asset['size']}")
print(f"digest:               {asset.get('digest', 'null')}")
print(f"browser_download_url: {asset['browser_download_url']}")
print(f"name:                 {asset['name']}")
```

**Stop immediately** if:
- Exactly one matching asset is not found
- The `digest` field is `null` or absent
- The `digest` value does not begin with `sha256:`
- The `browser_download_url` does not match `https://github.com/pocketbase/pocketbase/releases/download/v0.29.3/<archive_name>`

Record all five values before continuing.

### 3c. Download from the Authoritative URL

```zsh
ARCHIVE_NAME="pocketbase_0.29.3_darwin_arm64.zip"   # adjust
DL_URL="<browser_download_url from step 3b>"
API_DIGEST="<digest value from step 3b, e.g. sha256:abc123...>"
API_SIZE=<size from step 3b>

curl -fL -o "${ARCHIVE_NAME}" "${DL_URL}"
```

**Stop immediately** if curl returns nonzero.

### 3d. Verify Size and SHA-256

```zsh
# Extract the SHA-256 hex from the API digest string.
API_SHA256="${API_DIGEST#sha256:}"

ACTUAL_SHA256=$(shasum -a 256 "${ARCHIVE_NAME}" | awk '{print $1}')
ACTUAL_SIZE=$(wc -c < "${ARCHIVE_NAME}" | tr -d ' ')

echo "API SHA-256:    ${API_SHA256}"
echo "Actual SHA-256: ${ACTUAL_SHA256}"
echo "API size:       ${API_SIZE}"
echo "Actual size:    ${ACTUAL_SIZE}"

if [[ "${ACTUAL_SHA256}" != "${API_SHA256}" ]]; then
  echo "STOP: SHA-256 mismatch. Do not extract." >&2; exit 1
fi
if [[ "${ACTUAL_SIZE}" != "${API_SIZE}" ]]; then
  echo "STOP: File size mismatch. Do not extract." >&2; exit 1
fi
echo "Archive integrity: OK"
```

**Stop before extraction if either check fails.**

Place the verified archive path in `RELEASE1B_SCHEMA_SRC`'s directory so
the harness can find it, or set the extraction path manually in §3e.

### 3e. Extract

```zsh
ISOLATED_ROOT="/tmp/release1b_cp0_MANUAL_SETUP"  # example only
mkdir -p "${ISOLATED_ROOT}"
unzip -o "${ARCHIVE_NAME}" pocketbase -d "${ISOLATED_ROOT}"
chmod 700 "${ISOLATED_ROOT}/pocketbase"
"${ISOLATED_ROOT}/pocketbase" version  # must print 0.29.3
```

The harness handles its own extraction at `--run` time; this step is for
manual verification only. The harness uses the archive directly.

---

## §4 Self-Test Before Full Run

```zsh
chmod +x release1b_cp0.zsh

# Syntax check (must exit 0):
zsh -n release1b_cp0.zsh

# Package completeness (fill all UNRESOLVED constants first):
./release1b_cp0.zsh --package-check

# Harness self-test (no PocketBase required):
./release1b_cp0.zsh --harness-check
```

Stop if any check exits nonzero.

---

## §5 Pre-Run Safety Checklist

Confirm all items before `--run`:

- [ ] Port 8090 is free: `lsof -iTCP:8090 -sTCP:LISTEN`
- [ ] No VPN, proxy, or firewall redirecting loopback traffic
- [ ] All `UNRESOLVED__NEEDS_EXTERNAL__*` constants replaced
- [ ] `RELEASE1B_SCHEMA_SRC` points to a directory containing the project's `pb_migrations/*.js` files
- [ ] The seed migration `1782898775_seed_superadmin_user_4fd7.js` is present in that directory (the harness excludes it automatically)
- [ ] `release1b_otp_test_adapter.pb.js` is in the same directory as `release1b_cp0.zsh`
- [ ] `release1b_cp0.zsh --package-check` exits 0
- [ ] `release1b_cp0.zsh --harness-check` exits 0
- [ ] Production at `app.sihatdarimula.my` is NOT reachable from this machine, or network is isolated

---

## §6 Run the Harness

```zsh
# Recommended: choose a report destination outside the isolated root
# before the run, so it survives cleanup.
REPORT_PATH="${HOME}/release1b_cp0_report_$(date +%Y%m%d_%H%M%S).md"

./release1b_cp0.zsh \
  --run \
  --authorize-cp0 \
  --report-dest="${REPORT_PATH}"
```

The harness runs to completion (or halts on BLOCKING findings), exports the
sanitized report to `${REPORT_PATH}`, and removes the isolated root. Retain
the report file.

**Exit codes:**

| Code | Meaning |
|---|---|
| 0 | PASS — all executed tests passed, no deferred items |
| 1 | FAIL — one or more tests failed or BLOCKING |
| 2 | INCOMPLETE — deferred or unresolved items remain |

---

## §7 Report Retention

- The exported report is written atomically to `--report-dest` before cleanup.
- The report is sanitized: isolated root paths, HOME paths, and seed identity patterns are replaced with safe placeholders.
- Retain the report for inclusion with the R20 package review.
- The isolated root (`/tmp/release1b_cp0_<suffix>/`) is removed automatically unless cleanup fails. If it is retained after an error, clean it up per §8.

---

## §8 Manual Cleanup (if the isolated root is retained after error)

**Do not use a placeholder path.** Obtain the exact root from the harness output or from the `.release1b_marker` file. The cleanup commands below must be validated before execution.

```zsh
# Step 1: Obtain root from harness output.
# The harness prints: === Isolated root: [/tmp/release1b_cp0_XXXXXX] ===
# Use that exact path. Do not guess.

ISOLATED_ROOT="/tmp/release1b_cp0_XXXXXX"  # REPLACE with actual suffix from harness output

# Step 2: Validate before removing.
python3 - "${ISOLATED_ROOT}" << 'PYEOF'
import os,sys,stat,re
path = sys.argv[1]
if not path:
    print("REJECT: empty"); sys.exit(1)
try:
    canonical = os.path.realpath(path)
except Exception as e:
    print(f"REJECT: realpath error: {e}"); sys.exit(1)
if not canonical:
    print("REJECT: empty canonical"); sys.exit(1)
# Must be a direct child of /tmp (or TMPDIR).
parent = os.path.dirname(canonical)
import tempfile
approved_parent = os.path.realpath(tempfile.gettempdir())
if parent != approved_parent:
    print(f"REJECT: parent {parent!r} != {approved_parent!r}"); sys.exit(1)
# Must have required prefix.
base = os.path.basename(canonical)
if not base.startswith("release1b_cp0_"):
    print(f"REJECT: missing prefix, got {base!r}"); sys.exit(1)
# Must not be a symlink.
s = os.lstat(canonical)
if stat.S_ISLNK(s.st_mode):
    print("REJECT: symlink"); sys.exit(1)
# Must contain the run marker.
marker = os.path.join(canonical, ".release1b_marker")
if not os.path.isfile(marker):
    print("REJECT: no .release1b_marker"); sys.exit(1)
# Prohibited targets.
for prohibited in ["/", "/tmp", "/var", "/usr", "/etc", "/home", "/root"]:
    if canonical == prohibited:
        print(f"REJECT: prohibited: {canonical}"); sys.exit(1)
print(f"OK: {canonical}")
PYEOF

# Only if the above prints OK, proceed:
rm -rf "${ISOLATED_ROOT}"
```

**Stop if the Python validation does not print `OK`.** Never run `rm -rf` without this check.

---

## §9 S-3 Credential Incident (Separate from CP0)

The seed migration `pb_migrations/1782898775_seed_superadmin_user_4fd7.js`
contains a committed plaintext credential.

This is a **separate incident response item**, not a CP0 execution task.

The operator must determine — without contacting production — whether:
1. This migration was applied to the production database.
2. The password was rotated after application.

If the migration was applied and the password was not rotated, treat the
credential as compromised and follow your incident response procedure
independently of this test run.

**The harness does not use this credential. It excludes the migration from the
isolated run. No action on this item is required to run the harness.**

No destructive repository-history operation (filter-branch, BFG, force-push)
is authorized as part of this package. Treat that decision separately.

---

## §10 Prohibited Actions

At all times during and after this test run:

- Do not execute the harness against production
- Do not contact `app.sihatdarimula.my` or any non-loopback address
- Do not use or test the credential in the seed migration
- Do not modify production credentials, schema, hooks, or migrations
- Do not deploy or publish the application
- Do not modify repository history
- Do not start any service or database other than the isolated PocketBase instance
- Do not proceed to Checkpoint 1

**Application publication remains unauthorized.**
