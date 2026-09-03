# Release 1B — Round 17 Correction Review
**Status:** DRAFTED  
**Round:** 17 (narrowly corrected from Round 16)  
**Basis:** R17 static validation findings  
**Checkpoint 0:** NOT AUTHORIZED

---

## §A — Round 16 Authoritative Static Results (from Round 17 review)

| Artifact | Actual bytes | SHA-256 |
|---|---:|---|
| `release1b_cp0.zsh` | 133,233 | `8190d39a3482edb3b85a986c007fa5e969f9c0e81e9e98d4d338d11e3653e792` |
| `release1b_cp0_manifest.json` | 7,096 | `99c415a46bfb91ba351f3aa26af27a66f51fed5ae4a26950680c819e9c211bdf` |
| `release1b_schema_manifest.json` | 8,380 | `94554d92f13f028114d6debb12e571524084633a1b5b8a2153f3459ac96a2e94` |
| `release1b_hook_manifest.json` | 3,663 | `8c0ce54a57ef893cf229f324f33d82cd3dcb07e8a0c9b17bd3f94cec6ad54c06` |
| `release1b_test_manifest.json` | 9,492 | `1864fc2cbabfeeb915d0a76423bd680b221737f73957a6f1774a17d0e9afa65e` |
| `release1b_round16_review.md` | 9,319 | `67b54e4bdac3dd233df1446e5b9017b536442336538c204ed7570af4db900cca` |
| `release1b_round16_checksums.sha256` | 1,527 | `8c71ca7e1dfec723155b8c6df85622fe6428486c6a4f5e3df9ad999b9a8985ea` |

R16 validation: `zsh -n` PASS; strict JSON PASS; no duplicate functions; no executable
`eval`; 2 executable `|| true`; correct E4/E6/E8; archive hash blocks extraction.

---

## §B — Round 17 Blocking Findings and Fixes

### Finding 1 — Mandatory-deferred tests can produce `RESULT: PASS`

**R16 behavior:** `T_DEFERRED` and `T_UNRESOLVED` were explicitly informational;
final exit checked only `T_BLOCKING`, `T_FAIL`, `T_HARNESS_ERR`, `CLEANUP_FAILURE`.
A run with all tests DEFERRED-MANDATORY could print `RESULT: PASS`.

**R17 fix — three-state result:**

| Exit code | State | Condition |
|---|---|---|
| 0 | `PASS` | No failures and no mandatory gaps |
| 1 | `FAIL` | `T_BLOCKING > 0` ∨ `T_FAIL > 0` ∨ `T_HARNESS_ERR > 0` ∨ `CLEANUP_FAILURE > 0` |
| 2 | `INCOMPLETE` | No failures, but `T_DEFERRED > 0` ∨ `T_UNRESOLVED > 0` |

`INCOMPLETE` (rc=2) is documented in the script, in `main()`'s usage text, and
in all manifests. An INCOMPLETE result explicitly cannot support Checkpoint 0
authorization. PASS (rc=0) requires all mandatory tests to have been reached.

---

### Finding 2 — Defect 23 not fully implemented (OTP and idempotency scenarios missing)

**R16:** Only `T-CONCURRENCY-AUTH` existed (concurrent wrong-password auth).

**R17 fix:**

| Test ID | Implementation | Classification |
|---|---|---|
| `T-CONCURRENCY-AUTH` | Implemented; per-worker dirs and pre-worker validation added | IMPL |
| `T-CONCURRENCY-OTP-SEND` | Implemented with MANDATORY-DEFERRED gate | IMPL-MD |
| `T-CONCURRENCY-IDEMPOTENCY-POST` | Unconditionally MANDATORY-DEFERRED | IMPL-MD |

**`T-CONCURRENCY-OTP-SEND`** validates each pre-worker setup step, probes the OTP
endpoint, and if available launches N=4 concurrent OTP-send requests with per-worker
isolation. Defers if Mailhog is absent or endpoint returns 404.

**`T-CONCURRENCY-IDEMPOTENCY-POST`** is unconditionally MANDATORY-DEFERRED because
the idempotency endpoint route, key header, and duplicate-record behavior are
all NEEDS-EXTERNAL.

**Defect 23 classification:** `IMPL-MD`.

---

### Finding 3 — PocketBase termination ordering incorrect

**R16 ordering (wrong):**
```zsh
kill "$RELEASE1B_PB_PID"
wait "$RELEASE1B_PB_PID" || true   # unbounded before poll
kill -0 "$RELEASE1B_PB_PID"        # may never be reached
```

**R17 fix — correct ordering:**

1. SIGTERM; rc noted.
2. Bounded `kill -0` poll: 10 × 0.5s using new `pb_pid_exists()`.
3. If still present: SIGKILL + `CLEANUP_FAILURE=1` + brief poll 6 × 0.5s.
4. Bounded `wait` for zombie reap only — placed after termination confirmed.
5. `RELEASE1B_PB_PID=0` unconditionally.

**New `pb_pid_exists()` helper** distinguishes three states from `kill -0`:
- `rc=0`: process exists and is signalable
- `rc=1`: process not found (ESRCH) — gone
- `rc=2`: EPERM — process exists but cannot be signaled (should not occur for
  a child we own; sets `CLEANUP_FAILURE=1`)

**`|| true` at step 4** remains BENIGN: `wait` is bounded because process state
was already determined by `pb_pid_exists` polling; it returns immediately for
a zombie and quickly for a confirmed exit.

---

### Finding 4 — Concurrency pre-worker setup insufficiently validated

**R16:** User ID retrieved from file without checking non-empty; record HTTP
status not validated before extracting email; `WRONG_PW_FILE` existence not
checked before launching workers.

**R17 fix — five explicit pre-worker steps, each with `t_harness_err` on failure:**

1. `ORDINARY_ID_FILE` content non-empty.
2. User record HTTP status equals 200.
3. Response path file exists.
4. Email extraction exit code and content valid.
5. `WRONG_PW_FILE` non-empty and present.

Per-worker body generation also validated: `t_harness_err` recorded, temporary
directory cleaned, worker not launched if body generation fails.

---

### Finding 5 — `wait || true` redesigned as part of termination fix

The `wait || true` site was previously in an incorrect position (before the
poll/SIGKILL loop). After the R17 termination reordering, `wait` is placed
after `pb_pid_exists` has confirmed the process is gone or
`CLEANUP_FAILURE=1` has been set. In this position:

- The wait is bounded in practice (process state confirmed before it runs).
- The nonzero exit from `wait` on a signal-killed process is still expected.
- The `|| true` remains benign and correctly classified.

---

## §C — Defect Disposition Matrix (R17 final)

| # | Summary | Classification | Round Resolved |
|---|---|---|---|
| 1 | Double-invocation | IMPL | R14 |
| 2 | Group wrapper functions | IMPL | R14 |
| 3 | Quoted compound strings | IMPL | R14 |
| 4 | Duplicate orchestration calls | IMPL | R14 |
| 5 | verify_schema before superuser auth | IMPL | R14 |
| 7 | Stale anonymous-fallback comment | IMPL | R14 |
| 8 | pbj_extract.py / su_w removal | IMPL | R14 |
| 9 | Alias enum 1-4 expect 400 | IMPL | R14 |
| 10 | Case 5 stored credentials | IMPL | R14 |
| 11 | Failure propagation / termination ordering | IMPL | R17 (final) |
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
| 23 | Concurrency auth, OTP, idempotency | IMPL-MD | R17 (auth IMPL; OTP+idempotency MD) |
| 25 | OTP test structure | IMPL-MD | R14 (mandatory-deferred) |
| 26 | Field injection allowlist | IMPL | R14 |
| 27 | Actor-role rule | IMPL | R14 |
| 28 | Package integrity key-set match | IMPL | R14 |
| 29 | Path disclosure in report | IMPL | R14 |
| 30 | Non-atomic report export | IMPL | R14 |
| 31 | Entry-point authorization guard | IMPL | R14 |

**Summary:** IMPL=21, IMPL-MD=8, NEEDS-EXTERNAL=2

Recalculation: R16 IMPL=22; defect 23 moved IMPL→IMPL-MD → IMPL=21, IMPL-MD=7+1=8.

---

## §D — `|| true` Inventory (R17, unchanged count from R15)

| # | Location | Classification | Rationale |
|---|---|---|---|
| 1 | `pb_wipe_secret_file` | BENIGN-RETAINED | `dd` may return nonzero on partial write; `rm -f` unconditionally removes the file |
| 2 | `pb_trap_cleanup` step 4 | BENIGN-RETAINED | `wait` returns nonzero for a signal-killed process; process termination confirmed via `pb_pid_exists` polling before this call; serves only as a bounded zombie reap |

Total R17 executable `|| true`: **2**.

---

## §E — Unresolved Items

| Item | Status |
|---|---|
| R13 EOF parse error cause | UNRESOLVED |
| All hook source paths | NEEDS-EXTERNAL |
| All hook SHA-256 hashes | NEEDS-EXTERNAL |
| All hook probe routes | NEEDS-EXTERNAL |
| `alias_intercept` post-removal status | NEEDS-EXTERNAL (interceptor baseline) |
| Idempotency hook endpoint route, key, behavior | NEEDS-EXTERNAL |
| PocketBase archive SHA-256 hashes | NEEDS-EXTERNAL |
| All collection access rule expressions | NEEDS-EXTERNAL (verify against migration JS) |
| Email verification authRule | NEEDS-EXTERNAL |
| T-FILE-AUTH-5, T-FILE-AUTH-7 | NEEDS-EXTERNAL (binary test assets) |
| T-AVATAR-LIFECYCLE | NEEDS-EXTERNAL (binary image asset) |
| T-EMAIL-LIFECYCLE, T-OTP-FLOW (if no docker/OTP) | NEEDS-EXTERNAL |
| T-CONCURRENCY-OTP-SEND | NEEDS-EXTERNAL (Mailhog + OTP endpoint) |
| T-CONCURRENCY-IDEMPOTENCY-POST | NEEDS-EXTERNAL (idempotency hook) |
| T-PROXY-IP-INVESTIGATE | NEEDS-EXTERNAL (network fixture) |
| T-NSU-HOOK-BEHAVIOR | NEEDS-EXTERNAL (hook source) |

---

## §F — Validations Performed / Not Performed

| Validation | Status |
|---|---|
| `zsh -n` syntax check | **NOT PERFORMED** — tool-interface limitation |
| Strict JSON parsing | **NOT PERFORMED** — tool-interface limitation |
| SHA-256 hash computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Byte count computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Visual inspection of all changes | PERFORMED |
| `grep \|\| true` on R17 script | PERFORMED — 2 executable occurrences; both benign |
| Concurrency test ID count vs test_manifest | PERFORMED — 3 IDs: AUTH (IMPL), OTP-SEND (IMPL-MD), IDEMPOTENCY-POST (IMPL-MD) |
| Defect count recalculation | PERFORMED — IMPL=21, IMPL-MD=8, NEEDS-EXTERNAL=2 |

---

## §G — Confirmation Statements

- **R13 artifacts unchanged:** All six Round 13 artifacts at workspace root untouched.
- **R14 artifacts unchanged:** All seven Round 14 artifacts in `release1b_round14/` untouched.
- **R15 artifacts unchanged:** All seven Round 15 artifacts in `release1b_round15/` untouched.
- **R16 artifacts unchanged:** All seven Round 16 artifacts in `release1b_round16/` untouched.
- **No script execution:** R17 script was not executed in any mode.
- **No service started. No database touched. No network request. No production contact.**
- **Checkpoint 0 remains unauthorized.** `--authorize-cp0` guard is present in `main()`.
