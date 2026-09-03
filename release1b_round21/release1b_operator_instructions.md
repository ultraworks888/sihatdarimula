# Release 1B — Round 21 Operator Instructions
# Checkpoint 0 Authorization Status: AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

---

## §1 Package Integrity

The checksums file (`release1b_r21_checksums.sha256`) cannot be pre-populated by the AI tool environment, which has no shell execution capability. Populate it immediately after receiving the package using one command, then verify.

**Step 1 — Populate (run once):**

```zsh
cd release1b_round21
shasum -a 256 \
  release1b_cp0.zsh \
  release1b_otp_test_adapter.pb.js \
  release1b_cp0_manifest.json \
  release1b_schema_manifest.json \
  release1b_hook_manifest.json \
  release1b_test_manifest.json \
  release1b_operator_instructions.md \
  release1b_round21_review.md \
  > release1b_r21_checksums.sha256
```

Verify the command produced exactly 8 lines (one per artifact) and no `SHA256_COMPUTE_REQUIRED` placeholder remains in the file:

```zsh
grep -c SHA256_COMPUTE_REQUIRED release1b_r21_checksums.sha256
# Must print 0
wc -l < release1b_r21_checksums.sha256
# Must print 8
```

**Step 2 — Record checksums file self-integrity:**

```zsh
shasum -a 256 release1b_r21_checksums.sha256
wc -c < release1b_r21_checksums.sha256
```

Record these two values separately. They cannot be embedded in the file (non-recursive design).

**Step 3 — Verify at any time:**

```zsh
cd release1b_round21
shasum -a 256 --check release1b_r21_checksums.sha256
# All 8 lines must print: OK
# Exit code must be 0
```

`shasum --check` exits nonzero if any file is missing, changed, or the hash does not match.

---

## §2 Resolve NEEDS-EXTERNAL Constants

Open `release1b_cp0.zsh` and fill in every `UNRESOLVED__NEEDS_EXTERNAL__*` value:

| Constant | How to fill |
|---|---|
| `HOOK_SRC_PATHS[emergency_hardening]` | Absolute path to `pb_hooks/emergency_users_hardening.pb.js` |
| `HOOK_SRC_PATHS[push_broadcast]`      | Absolute path to `pb_hooks/push_broadcast.pb.js` |
| `HOOK_SRC_PATHS[whatsapp]`            | Absolute path to `pb_hooks/whatsapp.pb.js` |
| `HOOK_EXPECTED_SHA256[*]`             | `shasum -a 256 <path>` for each hook file |
| `RELEASE1B_SCHEMA_SRC`               | Absolute path to `pb_migrations/` directory |

Note: `auth_whatsapp_otp.pb.js` is intentionally absent from `HOOK_SRC_PATHS`. The OTP adapter replaces it in the isolated environment.

---

## §3 PocketBase v0.29.3 Archive Verification

### 3a. Retrieve Release Metadata (GitHub API, no auth required)

```zsh
curl -sf \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/pocketbase/pocketbase/releases/tags/v0.29.3" \
  -o pb_release_v0.29.3.json
```

Stop if curl exits nonzero.

### 3b. Verify Asset Metadata

```python3
import json, sys

# Adjust for your platform: darwin_arm64, darwin_amd64, linux_amd64, linux_arm64
ARCHIVE = "pocketbase_0.29.3_darwin_arm64.zip"

with open("pb_release_v0.29.3.json") as f:
    release = json.load(f)

assets = [a for a in release.get("assets", []) if a["name"] == ARCHIVE]
if len(assets) != 1:
    print(f"STOP: expected 1 asset, found {len(assets)}"); sys.exit(1)

a = assets[0]
digest = a.get("digest") or ""
if not digest.startswith("sha256:"):
    print(f"STOP: digest is null or not sha256: '{digest}'"); sys.exit(1)

print(f"asset_id:    {a['id']}")
print(f"size:        {a['size']}")
print(f"digest:      {digest}")
print(f"download:    {a['browser_download_url']}")
```

Stop if the script exits nonzero or digest does not start with `sha256:`.

### 3c. Download and Verify

```zsh
ARCHIVE="pocketbase_0.29.3_darwin_arm64.zip"
DL_URL="<browser_download_url from step 3b>"
API_DIGEST="<digest from step 3b, e.g. sha256:abc123>"
API_SIZE=<size from step 3b>

curl -fL -o "${ARCHIVE}" "${DL_URL}" || { echo "STOP: download failed"; exit 1; }

API_SHA256="${API_DIGEST#sha256:}"
ACTUAL_SHA256=$(shasum -a 256 "${ARCHIVE}" | awk '{print $1}')
ACTUAL_SIZE=$(wc -c < "${ARCHIVE}" | tr -d ' ')

[[ "${ACTUAL_SHA256}" == "${API_SHA256}" ]] || { echo "STOP: SHA-256 mismatch"; exit 1; }
[[ "${ACTUAL_SIZE}"   == "${API_SIZE}"   ]] || { echo "STOP: size mismatch";   exit 1; }
echo "Archive integrity: OK"
```

Do not extract if either check fails.

---

## §4 Pre-Run Checks

```zsh
chmod +x release1b_cp0.zsh

# Syntax check (must exit 0, no output):
zsh -n release1b_cp0.zsh

# Package completeness (all UNRESOLVED constants must be resolved first):
./release1b_cp0.zsh --package-check

# Offline self-test (no DNS, no PocketBase):
./release1b_cp0.zsh --harness-check
```

Stop if any exits nonzero.

---

## §5 Pre-Run Checklist

- [ ] Port 8090 free: `lsof -iTCP:8090 -sTCP:LISTEN`
- [ ] No VPN or proxy routing loopback traffic
- [ ] All `UNRESOLVED__NEEDS_EXTERNAL__*` replaced in harness
- [ ] `RELEASE1B_SCHEMA_SRC` points to the `pb_migrations/` directory
- [ ] Seed migration `1782898775_seed_superadmin_user_4fd7.js` is present in that directory (harness excludes it automatically)
- [ ] `release1b_otp_test_adapter.pb.js` is in the same directory as `release1b_cp0.zsh`
- [ ] `--package-check` exits 0
- [ ] `--harness-check` exits 0
- [ ] `shasum -a 256 --check release1b_r21_checksums.sha256` exits 0 with 8 OK lines
- [ ] No access to `app.sihatdarimula.my` from this machine (network isolation confirmed)

---

## §6 Run the Harness

```zsh
REPORT="${HOME}/r21_cp0_report_$(date +%Y%m%d_%H%M%S).md"

./release1b_cp0.zsh \
  --run \
  --authorize-cp0 \
  --report-dest="${REPORT}"
```

**Exit codes:** 0 = PASS, 1 = FAIL, 2 = INCOMPLETE

The harness exports a sanitized report to `${REPORT}` before cleaning up the isolated root.

---

## §7 Manual Cleanup (only if isolated root is retained after error)

Obtain the exact root from the harness output line:
```
=== Isolated root: [/tmp/release1b_cp0_XXXXXX] ===
```

Use the Python script below. **Validation and deletion are in one process.** If validation fails, `sys.exit(1)` runs before deletion — the operator cannot accidentally proceed.

```zsh
# Replace /tmp/release1b_cp0_XXXXXX with the actual path from harness output.
ISOLATED_ROOT="/tmp/release1b_cp0_XXXXXX"

python3 - "${ISOLATED_ROOT}" << 'PYEOF'
import os, sys, stat, shutil, tempfile

if len(sys.argv) < 2:
    print("REJECT: no path supplied", file=sys.stderr); sys.exit(1)
path = sys.argv[1]
errors = []

if not path:
    errors.append("REJECT: empty path argument")

canonical = None
if not errors:
    try:
        canonical = os.path.realpath(path)
    except Exception as e:
        errors.append(f"REJECT: realpath failed: {e}")

if not errors and not canonical:
    errors.append("REJECT: canonical path is empty")

if not errors:
    approved = os.path.realpath(tempfile.gettempdir())
    parent   = os.path.dirname(canonical)
    if parent != approved:
        errors.append(f"REJECT: parent '{parent}' != approved '{approved}'")

if not errors:
    base = os.path.basename(canonical)
    if not base.startswith("release1b_cp0_"):
        errors.append(f"REJECT: missing prefix, got '{base}'")

if not errors:
    try:
        s = os.lstat(canonical)
        if stat.S_ISLNK(s.st_mode):
            errors.append("REJECT: target is a symlink")
    except Exception as e:
        errors.append(f"REJECT: lstat failed: {e}")

if not errors:
    marker = os.path.join(canonical, ".release1b_marker")
    if not os.path.isfile(marker):
        errors.append("REJECT: no .release1b_marker in target")

if not errors:
    home = os.path.expanduser("~")
    for prohibited in ["/", "/tmp", "/var", "/usr", "/etc",
                       "/home", "/root", "/System", "/Library"]:
        try:
            if canonical == os.path.realpath(prohibited):
                errors.append(f"REJECT: prohibited path '{canonical}'")
                break
        except Exception:
            pass
    if home and home != "~":
        try:
            if canonical == os.path.realpath(home):
                errors.append(f"REJECT: target is HOME")
        except Exception:
            pass

if errors:
    for err in errors:
        print(err, file=sys.stderr)
    print("Cleanup aborted — no files deleted.", file=sys.stderr)
    sys.exit(1)

# All validations passed — delete in this same Python process.
print(f"Validated: '{canonical}'")
try:
    shutil.rmtree(canonical)
    print(f"OK: deleted '{canonical}'")
except Exception as e:
    print(f"DELETE FAILED: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
```

If Python exits nonzero, no deletion occurred. Do not retry with `rm -rf` directly.

---

## §8 S-3 Credential Incident (separate from CP0)

The migration `pb_migrations/1782898775_seed_superadmin_user_4fd7.js` contains a committed plaintext credential. This is a separate incident-response item. The harness excludes this migration. No CP0 action is required.

The operator must determine (without contacting production):
1. Was this migration applied to the production database?
2. If applied, was the password rotated?

Handle via your standard incident-response procedure independently.

---

## §9 Prohibited Actions

- Do not execute the harness against production
- Do not contact `app.sihatdarimula.my` or any non-loopback address
- Do not use or test the seed migration credential
- Do not modify production credentials, schema, hooks, migrations, or frontend
- Do not deploy or publish the application
- Do not modify repository history
- Do not start any service other than the isolated PocketBase instance
- Do not proceed to Checkpoint 1

**Application publication remains unauthorized.**
