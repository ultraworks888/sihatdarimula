# Release 1B — Round 23 Operator Instructions
# Checkpoint 0 Authorization Status: AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

---

## §1 Package Integrity

The package includes `release1b_r23_checksums.py` and `release1b_r23_checksums.sha256` (template).

**Step 1 — Generate baseline (once, immediately after receipt):**

```
cd release1b_round23
python3 release1b_r23_checksums.py --generate
```

Output shows SHA-256 and byte count for all 8 artifacts plus the verifier's own integrity.
Record the verifier's own values separately (out-of-band) per the threat model.

**Step 2 — Verify at any time:**

```
python3 release1b_r23_checksums.py --verify
```

Exits 0 if all 8 artifacts match. Exits 1 on any mismatch, symlink, non-regular file,
placeholder, missing file, or extra file. Generation refuses to overwrite a populated
baseline without `--replace`.

**Unresolved Provenance Limitation (D23-11):**
SHA-256 pre-computation is not possible in the AI delivery environment. This is an
acknowledged, irresolvable limitation. The operator-generated baseline is authoritative.

---

## §2 Resolve NEEDS-EXTERNAL Constants

| Constant | Value |
|---|---|
| `HOOK_SRC_PATHS[emergency_hardening]` | Path to `pb_hooks/emergency_users_hardening.pb.js` |
| `HOOK_SRC_PATHS[push_broadcast]` | Path to `pb_hooks/push_broadcast.pb.js` |
| `HOOK_SRC_PATHS[whatsapp]` | Path to `pb_hooks/whatsapp.pb.js` |
| `HOOK_EXPECTED_SHA256[*]` | `shasum -a 256 <path>` for each hook |
| `RELEASE1B_SCHEMA_SRC` | Path to production `pb_migrations/` directory |

---

## §3 Archive Verification (GitHub API)

1. Call GitHub API for `v0.29.3` release metadata.
2. Confirm exactly one matching asset; confirm `digest` starts with `sha256:`.
3. Download from `browser_download_url`; compare SHA-256 and size before extraction.
4. Stop if either fails.

Note: PocketBase v0.29.3 uses `_superusers` collection, not the legacy `admins` API.
The harness uses `/api/collections/_superusers/auth-with-password` throughout.

---

## §4 Pre-Run Checks

```
chmod +x release1b_cp0.zsh
zsh -n release1b_cp0.zsh                     # syntax check — must exit 0
node --check release1b_otp_test_adapter.pb.js # JS check — must exit 0
python3 -m py_compile release1b_r23_checksums.py  # must exit 0
python3 -m json.tool release1b_cp0_manifest.json >/dev/null
python3 -m json.tool release1b_schema_manifest.json >/dev/null
python3 -m json.tool release1b_hook_manifest.json >/dev/null
python3 -m json.tool release1b_test_manifest.json >/dev/null
./release1b_cp0.zsh --package-check          # after filling UNRESOLVED constants
./release1b_cp0.zsh --harness-check          # offline self-test (cleanup, double-outcome)
```

All must exit 0 before proceeding.

---

## §5 Pre-Run Checklist

- [ ] `python3 release1b_r23_checksums.py --verify` exits 0 with 8 OK
- [ ] `zsh -n release1b_cp0.zsh` exits 0
- [ ] Port 8090 free
- [ ] No VPN routing loopback
- [ ] All `UNRESOLVED__NEEDS_EXTERNAL__*` replaced
- [ ] `--package-check` exits 0
- [ ] `--harness-check` exits 0
- [ ] No access to production from this machine
- [ ] `release1b_otp_test_adapter.pb.js` in same directory as `release1b_cp0.zsh`

---

## §6 Run the Harness

```
REPORT="${HOME}/r23_cp0_report_$(date +%Y%m%d_%H%M%S).md"
./release1b_cp0.zsh --run --authorize-cp0 --report-dest="${REPORT}"
```

Exit codes: 0=PASS, 1=FAIL (blocking/error), 2=INCOMPLETE (deferred/unresolved).

---

## §7 Manual Cleanup

If the isolated root is retained after an error, obtain the exact path from harness output
(`=== Isolated root: [/tmp/release1b_cp0_XXXXXX] ===`) then run:

```
ISOLATED_ROOT="/tmp/release1b_cp0_XXXXXX"   # replace with actual path

python3 - "${ISOLATED_ROOT}" << 'PYEOF'
import os,sys,stat,shutil,tempfile
if len(sys.argv)<2: print("REJECT: no path",file=sys.stderr); sys.exit(1)
path=sys.argv[1]; canonical=None
if not path: print("REJECT: empty",file=sys.stderr); sys.exit(1)
try: canonical=os.path.realpath(path)
except Exception as e: print(f"REJECT: realpath: {e}",file=sys.stderr); sys.exit(1)
approved=os.path.realpath(tempfile.gettempdir())
if os.path.dirname(canonical)!=approved: print("REJECT: parent",file=sys.stderr); sys.exit(1)
if not os.path.basename(canonical).startswith("release1b_cp0_"):
    print("REJECT: prefix",file=sys.stderr); sys.exit(1)
try:
    s=os.lstat(canonical)
    if stat.S_ISLNK(s.st_mode): print("REJECT: symlink",file=sys.stderr); sys.exit(1)
except Exception as e: print(f"REJECT: lstat: {e}",file=sys.stderr); sys.exit(1)
for p in ["/","/tmp","/var","/usr","/etc","/home","/root","/System","/Library"]:
    try:
        if canonical==os.path.realpath(p): print(f"REJECT: prohibited {p}",file=sys.stderr); sys.exit(1)
    except Exception: pass
if not os.path.isfile(os.path.join(canonical,".release1b_marker")):
    print("REJECT: no marker",file=sys.stderr); sys.exit(1)
print(f"Validated: '{canonical}'")
try: shutil.rmtree(canonical); print(f"OK: deleted '{canonical}'")
except Exception as e: print(f"DELETE FAILED: {e}",file=sys.stderr); sys.exit(1)
PYEOF
```

If Python exits nonzero, no deletion occurred. Do not retry with `rm -rf` directly.

---

## §8 S-3 Credential Incident

`1782898775_seed_superadmin_user_4fd7.js` contains a committed plaintext credential.
Handle via separate incident-response procedure. The harness excludes this migration.

---

## §9 Prohibited Actions

- Do not run Checkpoint 0 against production
- Do not contact `app.sihatdarimula.my`
- Do not modify production credentials, schema, hooks, migrations, or frontend
- Do not deploy or publish the application
- Do not proceed to Checkpoint 1

**Application publication remains unauthorized.**
