# Release 1B — Round 15 Correction Review
**Status:** DRAFTED  
**Round:** 15 (narrowly corrected from Round 14)  
**Basis:** R14 static validation findings; authoritative R14 checksums recorded below  
**Checkpoint 0:** NOT AUTHORIZED  

---

## §A — Round 14 Authoritative Static Results (from static validation)

These values are recorded from the static validator and apply to R14 artifacts only.

| Artifact | Actual bytes | SHA-256 |
|---|---:|---|
| `release1b_cp0.zsh` | 144,055 | `39dc0424556a3a2598aaabcf0d79d809d25a0ebaafc5b4cf2107993ef47951d9` |
| `release1b_cp0_manifest.json` | 3,444 | `59221ade149c27b4ecaca8a1a9e282d17743fee11eed6170d624de482ab7892b` |
| `release1b_schema_manifest.json` | 11,292 | `60f8764b82c8fafd091779b8b80d7418d60af6278e62371e7315de3d557c6402` |
| `release1b_hook_manifest.json` | 5,407 | `14dc2b613ed1414630eee452366b46a2ef57f0ebe497ddb57ed7dff5b9215fe0` |
| `release1b_test_manifest.json` | 14,260 | `a38ae879d24f1632d870dbc450c2c11609fab92a3c52fb98b92ebc496fad04d8` |
| `release1b_round14_review.md` | 12,923 | `d37cff1aafe0ffd73f8c1e43c279e0e4a70232cae47de0c19c08566f6b9b87d1` |
| `release1b_round14_checksums.sha256` | 1,518 | `3dce26452ef94120c88446d7f1cca6589f1aa758515495be2eb244a6f0cff12d` |

R14 validation results: `zsh -n` PASS; strict JSON parsing all four manifests PASS;
no duplicate function definitions; no executable `eval`; one `main "$@"` call; 121
functions detected; 27 `pb_run_stage` call sites; 8 executable `|| true` found.

---

## §B — Round 15 Blocking Findings and Fixes

### Finding 1 — E4/E6/E8 historically wrong (defect-21, R14 incomplete)

**R14 recorded:**  
- E4 = proxy IP  
- E6 = push broadcast  
- E8 = WhatsApp  

**Correct historical meanings:**  
- E4 = Production email-change lifecycle diagnostic  
- E6 = Production OTP endpoint reachability  
- E8 = Production WARN-log observability  

**R15 fix:** `pb_record_production_exclusions()` rewritten with correct labels and
descriptions. `release1b_test_manifest.json` `authorized_exclusions` section updated.
`release1b_hook_manifest.json` descriptions updated.

---

### Finding 2 — Migration copy/chmod fail-open (defect-11, R14 incomplete)

**R14 code:**
```zsh
cp "${RELEASE1B_SCHEMA_SRC}"/*.js "$RELEASE1B_PB_MIGRATIONS_DIR"/ 2>/dev/null || true
chmod 600 "${RELEASE1B_PB_MIGRATIONS_DIR}"/*.js 2>/dev/null || true
t_pass "T-SCHEMA-MIGRATIONS-COPY"
```
A glob that matches no `.js` files causes `cp` to fail; `|| true` suppresses it and
`t_pass` is called regardless.

**R15 fix:** `pb_apply_schema_migrations` rewrites to file-by-file copy using `(N)`
glob qualifier (no-match = empty loop). Zero-js-files case calls `t_blocking`. Each
`cp` and `chmod` failure calls `t_blocking` and returns 1.

---

### Finding 3 — Legacy fixture deletion fail-open (defect-11, R14 incomplete)

**R14 code (line 1997-1998):**
```zsh
pb_delete_record "children" "$f" 2>/dev/null || \
  pb_delete_record "growth_records" "$f" 2>/dev/null || true
```
If both calls fail, `CLEANUP_FAILURE` is not set.

**R15 fix:**
```zsh
if ! pb_delete_record "children" "$f"; then
  if ! pb_delete_record "growth_records" "$f"; then
    CLEANUP_FAILURE=1
    print "[legacy-del] WARNING: could not delete record (id_file: ${f})" >&2
  fi
fi
```

---

### Finding 4 — Concurrency wait `|| true` undocumented (defect-11)

**R14 code (line 3444):**
```zsh
wait "$pid" 2>/dev/null || true
```
Non-zero exit suppressed without comment.

**R15 fix:** `|| true` removed. Replaced with bare `:` and inline comment explaining
that worker exit code is not checked (results are verified via result_files).

---

### Finding 5 — Archive hash verification fail-open (security-critical, defect-11)

**R14 code (line 3849):**
```zsh
pb_verify_archive_hash "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || true
pb_extract_pocketbase "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || exit 1
```
A mismatched or missing hash did not prevent extraction.

**R15 fix:**
```zsh
pb_verify_archive_hash "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || {
  print "[main] HALT: archive hash verification failed — extraction aborted" >&2
  exit 1
}
pb_extract_pocketbase "${PB_ARCHIVE_NAME[${PLATFORM_KEY}]:-}" || exit 1
```

---

### Finding 6 — Defect-16 overstated as IMPL (R14 classification wrong)

**R14 claimed:** defect-16 = IMPL  
**Actual:** `HOOK_EXPECTED_REMOVED_STATUS[alias_intercept]` is
`UNRESOLVED__NEEDS_EXTERNAL__interceptor_baseline` because the alias_intercept hook
shares the PocketBase core auth route; the correct post-removal status cannot be
determined without operator specification.

**R15 fix:** defect-16 reclassified to IMPL-MD. Count updates:
- IMPL: 22 (was 23 in R14)
- IMPL-MD: 7 (was 6 in R14)

---

### Finding 7 — `|| true` inventory stale and inaccurate (defect-11)

**R14 manifest claimed:** 19 executable occurrences (inherited from R13 baseline).
**Actual R14 executable count:** 8 (confirmed by static validator grep).
**R15 retained:** 2 (benign).

**R15 inventory:**

| # | Location | Code | Classification |
|---|---|---|---|
| 1 | `pb_wipe_secret_file` | `dd ... \|\| true` | BENIGN-RETAINED: dd may return non-zero on partial write; rm -f below unconditionally removes the file |
| 2 | `pb_trap_cleanup` | `wait "$RELEASE1B_PB_PID" 2>/dev/null \|\| true` | BENIGN-RETAINED: wait returns non-zero for kill'd process; expected behavior |
| 3 | `pb_apply_schema_migrations` line 1132 | `cp ... \|\| true` | ELIMINATED → t_blocking |
| 4 | `pb_apply_schema_migrations` line 1136 | `chmod ... \|\| true` | ELIMINATED → t_blocking |
| 5 | `pb_delete_legacy_fixture` line 1998 | chained `\|\| true` | ELIMINATED → CLEANUP_FAILURE=1 |
| 6 | `t_concurrency_auth_group` line 3444 | `wait "$pid" ... \|\| true` | ELIMINATED → bare `:` with comment |
| 7 | `main()` line 3849 | `pb_verify_archive_hash ... \|\| true` | ELIMINATED → halt-on-failure block |

Total R15 executable `|| true`: **2** (both BENIGN-RETAINED).

---

## §C — Defect Disposition Matrix (R15 complete)

| # | Summary | Classification | Notes |
|---|---|---|---|
| 1 | Double-invocation | IMPL | Not reproduced in R13; guard retained |
| 2 | Group wrapper functions | IMPL | 15 group functions; orchestrator calls each once |
| 3 | Quoted compound strings | IMPL | Eliminated |
| 4 | Duplicate orchestration calls | IMPL | Eliminated |
| 5 | pb_verify_schema before superuser auth | IMPL | Moved after create_local_superuser |
| 7 | Stale anonymous-fallback comment | IMPL | Removed |
| 8 | pb_copy_field for ID / su_w | IMPL | Replaced with pbj_extract.py; su_w removed |
| 9 | Alias enum case 1-4 inconsistent 400 | IMPL | All four expect 400 |
| 10 | Case 5 missing stored credentials | IMPL | TIMING_LEGACY_PW_FILE stored and used |
| 11 | `\|\| true` in security/cleanup paths | IMPL | R15: 5 eliminated; 2 benign retained with documentation |
| 12 | pb_apply_rule_local null vs "" | IMPL | `__pb_null__` sentinel |
| 13 | Rule tests absent | IMPL | t_rule_apply_restore_children() |
| 14 | pb_restore_rule_local no re-read | IMPL | Re-read + compare; CLEANUP_FAILURE=1 on mismatch |
| 15 | Hook smoke matrix hardcoded routes | IMPL | HOOK_PROBE_ROUTES / HOOK_PROBE_METHODS per hook |
| 16 | pb_remove_hook_verified wrong status | IMPL-MD | HOOK_EXPECTED_REMOVED_STATUS per hook; interceptor baseline NEEDS-EXTERNAL |
| 17 | t_native_superuser_hook_behavior | IMPL-MD | MANDATORY-DEFERRED; hook source NEEDS-EXTERNAL |
| 18 | /onboarding semantic | IMPL | Patient antenatal phase; t_articles_antenatal_visible |
| 19 | /admin semantic / debug print | IMPL | Privileged panel note; debug print absent |
| 20 | Email lifecycle test | IMPL | t_email_lifecycle_isolated() mandatory Mailhog stage |
| 21 | Production exclusions | IMPL | E4/E6/E8 correct historical meanings (R15 corrected) |
| 22 | Proxy IP investigation | IMPL-MD | t_proxy_ip_investigation() MANDATORY-DEFERRED |
| 23 | Concurrency auth tests | IMPL | t_concurrency_auth_group() with background processes |
| 25 | OTP test structure | IMPL-MD | t_otp_flow() deferred if Mailhog/OTP unavailable |
| 26 | Field injection allowlist | IMPL | Server-side allowlist check on 200 response |
| 27 | Actor-role rule | IMPL | t_actor_role_rule() expects 400 |
| 28 | Package integrity key-set match | IMPL | pb_check_package_completeness() exact key-set verify |
| 29 | Path disclosure in report | IMPL | PBJ_SCAN_PY sanitizes paths |
| 30 | Non-atomic report export | IMPL | os.replace() atomic rename |
| 31 | Entry-point authorization guard | IMPL | --authorize-cp0 guard preserved |

*Defects 6 and 24 not in authorized correction matrix.*

**Summary:** IMPL=22, IMPL-MD=7, NEEDS-EXTERNAL=2

---

## §D — Unresolved Items

| Item | Status |
|---|---|
| R13 EOF parse error cause | UNRESOLVED — not positively identified |
| All hook source paths | NEEDS-EXTERNAL |
| All hook SHA-256 hashes | NEEDS-EXTERNAL |
| All hook probe routes | NEEDS-EXTERNAL |
| alias_intercept post-removal status | NEEDS-EXTERNAL (interceptor baseline) |
| PocketBase archive SHA-256 hashes | NEEDS-EXTERNAL |
| All collection access rule expressions | NEEDS-EXTERNAL (verify against migration JS) |
| Email verification authRule | NEEDS-EXTERNAL |
| T-FILE-AUTH-5, T-FILE-AUTH-7 | NEEDS-EXTERNAL (binary test assets) |
| T-AVATAR-LIFECYCLE | NEEDS-EXTERNAL (binary image asset) |
| T-EMAIL-LIFECYCLE (if no docker) | NEEDS-EXTERNAL (Mailhog requires docker) |
| T-PROXY-IP-INVESTIGATE | NEEDS-EXTERNAL (network fixture) |
| T-NSU-HOOK-BEHAVIOR | NEEDS-EXTERNAL (hook source defines NSU intercept semantics) |

---

## §E — Validations Performed / Not Performed

| Validation | Status |
|---|---|
| `zsh -n` syntax check | **NOT PERFORMED** — tool interface limitation |
| Strict JSON parsing of manifests | **NOT PERFORMED** — tool interface limitation |
| SHA-256 hash computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Byte count computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Visual inspection of script structure | PERFORMED |
| `grep \|\| true` count in R15 script | PERFORMED — 2 executable occurrences confirmed (both benign, both documented) |

---

## §F — Confirmation Statements

- **R13 artifacts unchanged:** All six Round 13 artifacts at workspace root are untouched.
- **R14 artifacts unchanged:** All seven Round 14 artifacts in `release1b_round14/` are untouched.
- **No script execution:** R15 script was not executed in any mode.
- **No service started.** No database touched. No network request. No production contact.
- **Checkpoint 0 remains unauthorized.** `--authorize-cp0` guard is present in `main()`.
