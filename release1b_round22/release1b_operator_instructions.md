# Release 1B — Round 22 Operator Instructions
# Checkpoint 0 Authorization Status: AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

---

## §1 Package Integrity

The package includes `release1b_r22_checksums.py` (a Python integrity tool) and `release1b_r22_checksums.sha256` (the checksums data file, initially a template).

**Step 1 — Generate checksums (run once after receipt):**

```
cd release1b_round22
python3 release1b_r22_checksums.py --generate
```

This computes SHA-256 and writes 8 entries to `release1b_r22_checksums.sha256`. Output shows each artifact's digest and byte count.

**Step 2 — Record the integrity tool's own self-integrity:**

The `--generate` output includes the SHA-256 and byte count of `release1b_r22_checksums.py` itself. Record these separately. They are also provided in the delivery message.

**Step 3 — Verify at any time:**

```
cd release1b_round22
python3 release1b_r22_checksums.py --verify
```

Exits 0 if all 8 artifacts match. Exits 1 on any mismatch, missing file, extra file, duplicate, or placeholder. Also compatible with `shasum -a 256 --check release1b_r22_checksums.sha256` after generation.

---

## §2 Resolve NEEDS-EXTERNAL Constants

Fill all `UNRESOLVED__NEEDS_EXTERNAL__*` values in `release1b_cp0.zsh`:

| Constant | Value |
|---|---|
| `HOOK_SRC_PATHS[emergency_hardening]` | Path to `pb_hooks/emergency_users_hardening.pb.js` |
| `HOOK_SRC_PATHS[push_broadcast]` | Path to `pb_hooks/push_broadcast.pb.js` |
| `HOOK_SRC_PATHS[whatsapp]` | Path to `pb_hooks/whatsapp.pb.js` |
| `HOOK_EXPECTED_SHA256[*]` | `shasum -a 256 <path>` for each hook |
| `RELEASE1B_SCHEMA_SRC` | Path to `pb_migrations/` directory |

---

## §3 Archive Verification (GitHub API)

See Round 21 §3 for the full procedure. In brief:
1. Call GitHub API for `v0.29.3` release metadata.
2. Confirm exactly one matching asset; confirm `digest` starts with `sha256:`.
3. Download from `browser_download_url`; compare SHA-256 and size before extraction.
4. Stop if either fails.

---

## §4 Pre-Run Checks

```
chmod +x release1b_cp0.zsh
zsh -n release1b_cp0.zsh                     # syntax check
./release1b_cp0.zsh --package-check          # after filling UNRESOLVED constants
./release1b_cp0.zsh --harness-check          # offline self-test (includes cleanup tests)
```

All must exit 0.

---

## §5 Pre-Run Checklist

- [ ] `python3 release1b_r22_checksums.py --verify` exits 0 with 8 OK
- [ ] Port 8090 free
- [ ] No VPN routing loopback
- [ ] All `UNRESOLVED__NEEDS_EXTERNAL__*` replaced
- [ ] `--package-check` exits 0
- [ ] `--harness-check` exits 0
- [ ] No access to `app.sihatdarimula.my` from this machine
- [ ] `release1b_otp_test_adapter.pb.js` in same directory as `release1b_cp0.zsh`

---

## §6 Run the Harness

```
REPORT="${HOME}/r22_cp0_report_$(date +%Y%m%d_%H%M%S).md"
./release1b_cp0.zsh --run --authorize-cp0 --report-dest="${REPORT}"
```

Exit codes: 0=PASS, 1=FAIL, 2=INCOMPLETE.

---

## §7 Manual Cleanup (if isolated root retained after error)

Obtain the exact root from harness output: `=== Isolated root: [/tmp/release1b_cp0_XXXXXX] ===`

```
ISOLATED_ROOT="/tmp/release1b_cp0_XXXXXX"   # replace with actual path

python3 - "${ISOLATED_ROOT}" << 'PYEOF'
import os, sys, stat, shutil, tempfile

if len(sys.argv) < 2:
    print("REJECT: no path", file=sys.stderr); sys.exit(1)
path = sys.argv[1]; errors = []; canonical = None

if not path: errors.append("REJECT: empty path")
if not errors:
    try: canonical = os.path.realpath(path)
    except Exception as e: errors.append(f"REJECT: realpath: {e}")
if not errors and not canonical: errors.append("REJECT: empty canonical")
if not errors:
    approved = os.path.realpath(tempfile.gettempdir())
    if os.path.dirname(canonical) != approved:
        errors.append(f"REJECT: parent not approved tmpdir")
if not errors and not os.path.basename(canonical).startswith("release1b_cp0_"):
    errors.append("REJECT: missing prefix")
if not errors:
    try:
        s = os.lstat(canonical)
        if stat.S_ISLNK(s.st_mode): errors.append("REJECT: symlink")
    except Exception as e: errors.append(f"REJECT: lstat: {e}")
if not errors and not os.path.isfile(os.path.join(canonical, ".release1b_marker")):
    errors.append("REJECT: no marker")
if not errors:
    home = os.path.expanduser("~")
    for p in ["/", "/tmp", "/var", "/usr", "/etc", "/home", "/root", "/System", "/Library"]:
        try:
            if canonical == os.path.realpath(p): errors.append(f"REJECT: prohibited {p}"); break
        except Exception: pass
    try:
        if home and home != "~" and canonical == os.path.realpath(home):
            errors.append("REJECT: HOME")
    except Exception: pass

if errors:
    for e in errors: print(e, file=sys.stderr)
    print("Aborted — no files deleted.", file=sys.stderr); sys.exit(1)

print(f"Validated: '{canonical}'")
try:
    shutil.rmtree(canonical); print(f"OK: deleted '{canonical}'")
except Exception as e:
    print(f"DELETE FAILED: {e}", file=sys.stderr); sys.exit(1)
PYEOF
```

If Python exits nonzero, no deletion occurred. Do not retry with `rm -rf` directly.

---

## §8 S-3 Credential Incident

The seed migration `1782898775_seed_superadmin_user_4fd7.js` contains a committed plaintext credential. Handle via separate incident-response procedure. Harness excludes this migration automatically.

---

## §9 Prohibited Actions

- Do not run Checkpoint 0 against production
- Do not contact `app.sihatdarimula.my`
- Do not modify production credentials, schema, hooks, migrations, or frontend
- Do not deploy or publish the application
- Do not proceed to Checkpoint 1

**Application publication remains unauthorized.**
