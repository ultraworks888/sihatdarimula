# Release 1B — Round 16 Correction Review
**Status:** DRAFTED  
**Round:** 16 (narrowly corrected from Round 15)  
**Basis:** R16 static validation findings  
**Checkpoint 0:** NOT AUTHORIZED

---

## §A — Round 15 Authoritative Static Results (from Round 16 review)

| Artifact | Actual bytes | SHA-256 |
|---|---:|---|
| `release1b_cp0.zsh` | 128,945 | `349ecd1f398ff796d35bf184535f1f787cdae610deaad4625693a0c44b9dbc0f` |
| `release1b_cp0_manifest.json` | 6,239 | `8bc4207f097b5836eba4e2e7f345c0c3c503b361908ff1b37908bb163be14ef5` |
| `release1b_schema_manifest.json` | 8,397 | `b470991e0deb5fe4925e781abab30522f6d900c27e52352837bce319c23857ed` |
| `release1b_hook_manifest.json` | 3,927 | `fc492e714b0cdafbe6b7378c7a55cc2db80d61ab19d8f5052e6dc8a620a601ee` |
| `release1b_test_manifest.json` | 9,527 | `a148308c9fc654adb4d94b22521e7aea7a5f869f3976513d13b3353a31c0a85f` |
| `release1b_round15_review.md` | 10,635 | `dc7ca38b8c8a78c35b2d907187956b5eac20064dea56a6ba5f117d393baaa2b2` |
| `release1b_round15_checksums.sha256` | 1,603 | `4429e951a262f2d5b3bc4e7d3f03774fe43c405b699026383bf8cf22fa39cfee` |

R15 validation: `zsh -n` PASS; strict JSON PASS; no duplicate functions; no executable
`eval`; 2 executable `|| true`; correct E4/E6/E8; archive hash blocks extraction.

**Correction to R14 review:** R14 had seven executable `|| true`, not eight. One
grep match was a comment (`# ... rather than || true`). R15's accounting of five
eliminated plus two retained is numerically correct.

---

## §B — Round 16 Blocking Findings and Fixes

### Finding 1 — Stage failures silently ignored in `cp0_run` (defect-11, R15 incomplete)

**R15 calls without consequence:**
```zsh
pb_run_stage pb_apply_schema_migrations   # failure ignored
pb_run_stage pb_verify_hook_directory     # failure ignored; hooks installed regardless
pb_run_stage pb_cleanup_normal            # failure not set in CLEANUP_FAILURE
pb_run_stage pb_scan_and_export_report    # failure not set in CLEANUP_FAILURE
```

**R16 fix:** Explicit result policy for every `pb_run_stage` call, documented
inline:

| Stage | R16 Policy |
|---|---|
| `pb_preflight_ports` | HALT |
| `pb_apply_schema_migrations` | HALT (R16 change) |
| `pb_start_pocketbase` | HALT |
| `pb_start_mailhog` | CONTINUE — t_unresolved if unavailable |
| `pb_create_local_superuser` | HALT |
| `pb_verify_schema` | CONTINUE — t_blocking sets HALT_DEPENDENTS |
| Hook phase | GATED on HALT_DEPENDENTS; t_skip if set |
| `pb_verify_hook_directory` | CONTINUE — t_blocking sets HALT_DEPENDENTS |
| `pb_install_hook_verified` per hook | CONTINUE — t_unresolved/t_blocking recorded |
| `pb_hook_smoke_matrix` | CONTINUE — t_fail/t_unresolved recorded |
| `pb_create_test_user` (three users) | HALT |
| `pb_create_legacy_fixture` | CONTINUE — t_harness_err; tests gate on file existence |
| `pb_setup_alias_group` | CONTINUE — t_harness_err; tests gate on file existence |
| All 15 test groups | CONTINUE — failures conclusively recorded internally |
| `pb_cleanup_normal` | SET CLEANUP_FAILURE (R16 change) |
| `pb_scan_and_export_report` | SET CLEANUP_FAILURE (R16 change) |

---

### Finding 2 — Final exit condition excludes `T_HARNESS_ERR` and `CLEANUP_FAILURE`

**R15:**
```zsh
(( T_BLOCKING > 0 || T_FAIL > 0 )) && return 1
return 0
```

**R16:**
```zsh
if (( T_BLOCKING > 0 || T_FAIL > 0 || T_HARNESS_ERR > 0 || CLEANUP_FAILURE > 0 )); then
  print "=== RESULT: FAIL ===" >&2
  return 1
fi
print "=== RESULT: PASS ==="
return 0
```

**Treatment of unresolved/deferred:** `T_UNRESOLVED` and `T_DEFERRED` are
informational. They represent items requiring NEEDS-EXTERNAL prerequisites and do
not affect exit status. This is explicitly documented in `cp0_run` output.

---

### Finding 3 — Concurrency worker failures not classifiable

**R15:** Worker exit code captured but then discarded via bare `:`. A missing or
malformed result file incremented `fail_count` without distinguishing a helper
crash from a functional test failure.

**R16 fix — subshell propagates helper exit code:**
```zsh
(
  python3 "$PBJ_HTTP_PY" "$http_f" "$resp_f" ... "POST"
  _wrc=$?
  rm -f "$body_f" "$resp_f"
  exit $_wrc
) &
```

**R16 fix — four-category result classification:**

| Category | Detection | Action |
|---|---|---|
| Worker nonzero | `worker_rcs[$idx] != 0` | `t_harness_err` |
| Result file absent | `[[ ! -f "$rf" ]]` | `t_harness_err` |
| Result file malformed | not a `[0-9]{3}` string | `t_harness_err` |
| Functional wrong status | `[[ "$s" != "400" ]]` | increments `fail_count` |

Harness errors and functional failures are reported independently.

---

### Finding 4 — PocketBase termination not confirmed before PID cleared

**R15:**
```zsh
kill "$RELEASE1B_PB_PID" 2>/dev/null
wait "$RELEASE1B_PB_PID" 2>/dev/null || true
RELEASE1B_PB_PID=0   # cleared unconditionally
```

**R16 fix:** After `wait`, poll `kill -0 $RELEASE1B_PB_PID` for up to 5 seconds
(10 × 0.5s). If the process is still alive after polling:
- send SIGKILL
- set `CLEANUP_FAILURE=1`

Then clear `RELEASE1B_PB_PID=0` unconditionally. `CLEANUP_FAILURE=1` propagates
to the final exit condition.

---

## §C — Defect Disposition Matrix (R16 final)

| # | Summary | Classification | Round Resolved |
|---|---|---|---|
| 1 | Double-invocation | IMPL | R14 (not reproduced) |
| 2 | Group wrapper functions | IMPL | R14 |
| 3 | Quoted compound strings | IMPL | R14 |
| 4 | Duplicate orchestration calls | IMPL | R14 |
| 5 | verify_schema before superuser auth | IMPL | R14 |
| 7 | Stale anonymous-fallback comment | IMPL | R14 |
| 8 | pbj_extract.py / su_w removal | IMPL | R14 |
| 9 | Alias enum 1-4 expect 400 | IMPL | R14 |
| 10 | Case 5 stored credentials | IMPL | R14 |
| 11 | Failure propagation / || true | IMPL | R16 (final) |
| 12 | Null vs "" sentinel in rules | IMPL | R14 |
| 13 | Rule tests absent | IMPL | R14 |
| 14 | Rule restore no re-read | IMPL | R14 |
| 15 | Hook smoke hardcoded routes | IMPL | R14 |
| 16 | Hook removal wrong status | IMPL-MD | R15 (reclassified) |
| 17 | NSU hook behavior | IMPL-MD | R14 (mandatory-deferred) |
| 18 | /onboarding semantic | IMPL | R14 |
| 19 | /admin semantic / debug print | IMPL | R14 |
| 20 | Email lifecycle test | IMPL | R14 |
| 21 | Production exclusions E4/E6/E8 | IMPL | R15 (corrected) |
| 22 | Proxy IP investigation | IMPL-MD | R14 (mandatory-deferred) |
| 23 | Concurrency auth tests | IMPL | R16 (worker classification) |
| 25 | OTP test structure | IMPL-MD | R14 (mandatory-deferred) |
| 26 | Field injection allowlist | IMPL | R14 |
| 27 | Actor-role rule | IMPL | R14 |
| 28 | Package integrity key-set match | IMPL | R14 |
| 29 | Path disclosure in report | IMPL | R14 |
| 30 | Non-atomic report export | IMPL | R14 |
| 31 | Entry-point authorization guard | IMPL | R14 |

**Summary:** IMPL=22, IMPL-MD=7, NEEDS-EXTERNAL=2

---

## §D — `|| true` Inventory (R16, unchanged from R15)

| # | Location | Classification | Rationale |
|---|---|---|---|
| 1 | `pb_wipe_secret_file` | BENIGN-RETAINED | `dd` may return nonzero on partial write; `rm -f` unconditionally removes the file |
| 2 | `pb_trap_cleanup` kill-wait | BENIGN-RETAINED | `wait` returns nonzero for a killed process; expected; PB termination now confirmed independently via `kill -0` polling |

Total R16 executable `|| true`: **2**.

---

## §E — Unresolved Items

| Item | Status |
|---|---|
| R13 EOF parse error cause | UNRESOLVED — not positively identified |
| All hook source paths | NEEDS-EXTERNAL |
| All hook SHA-256 hashes | NEEDS-EXTERNAL |
| All hook probe routes | NEEDS-EXTERNAL |
| `alias_intercept` post-removal status | NEEDS-EXTERNAL (interceptor baseline) |
| PocketBase archive SHA-256 hashes | NEEDS-EXTERNAL |
| All collection access rule expressions | NEEDS-EXTERNAL (verify against migration JS) |
| Email verification authRule | NEEDS-EXTERNAL |
| T-FILE-AUTH-5, T-FILE-AUTH-7 | NEEDS-EXTERNAL (binary test assets) |
| T-AVATAR-LIFECYCLE | NEEDS-EXTERNAL (binary image asset) |
| T-EMAIL-LIFECYCLE (if no docker) | NEEDS-EXTERNAL (Mailhog) |
| T-PROXY-IP-INVESTIGATE | NEEDS-EXTERNAL (network fixture) |
| T-NSU-HOOK-BEHAVIOR | NEEDS-EXTERNAL (hook source defines NSU intercept semantics) |

---

## §F — Validations Performed / Not Performed

| Validation | Status |
|---|---|
| `zsh -n` syntax check | **NOT PERFORMED** — tool-interface limitation |
| Strict JSON parsing | **NOT PERFORMED** — tool-interface limitation |
| SHA-256 hash computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Byte count computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Visual inspection | PERFORMED |
| `grep \|\| true` on R16 script | PERFORMED — 2 executable occurrences; both benign; both documented |

---

## §G — Confirmation Statements

- **R13 artifacts unchanged:** All six Round 13 artifacts at workspace root untouched.
- **R14 artifacts unchanged:** All seven Round 14 artifacts in `release1b_round14/` untouched.
- **R15 artifacts unchanged:** All seven Round 15 artifacts in `release1b_round15/` untouched.
- **No script execution:** R16 script was not executed in any mode.
- **No service started. No database touched. No network request. No production contact.**
- **Checkpoint 0 remains unauthorized.** `--authorize-cp0` guard is present in `main()`.
