# Release 1B — Round 24 Correction Matrix and Review

---

## A. Round 24 Correction Matrix

| Defect | R23 Issue | R24 Correction |
|---|---|---|
| D24-1 | `t_phone_future_state_group()` and `pb_run_all_tests()` both invoked the same four OTP test functions, triggering `_t_fatal_internal` on every run | All OTP lifecycle tests consolidated in `t_otp_lifecycle_group()`. `pb_run_all_tests()` calls only `t_otp_lifecycle_group`. Static deduplication checker (`pbj_dupeid.py`) added to `t_harness_selftest`; fails if any literal test ID appears more than once. |
| D24-2 | `pb_delete_local_superuser()` wiped credential files but never called the API to delete the `_superusers` record. `T-SU-DELETE` passed without performing the declared operation. | `pb_create_local_superuser()` stores the record ID in `_NSU_REC_FILE` (permission-600) via `pbj_tok.py`. `pb_delete_local_superuser()` reads the ID, DELETEs via API (using NSU token before it's wiped), verifies absence (GET returns 404 or 401), then wipes all credential files. `CLEANUP_FAILURE=1` on any failure; `T-SU-DELETE` PASS only after deletion and absence verification. |
| D24-3 | `pbj_http.py` appended the bearer token to curl subprocess argv (`cmd += ['-H', hdr]`), exposing it in process listings. | Bearer token written to a permission-600 single-use curl configuration file (`--config`). Token never appears in subprocess argv. Config file deleted in a `finally` block immediately after the request. |
| D24-4 | `pbj_field.py` used only a BLOCKED list; allowed `token`, `email`, `phone`, and other sensitive values to be printed. | Explicit `ALLOWED` allowlist in `pbj_field.py`; BLOCKED list permanently prohibits token, email, phone, code, password, passwordHash, tokenKey, alias, phone_verified. New `pbj_tok.py`: non-printing token extractor writes directly to protected file. New `pbj_cmp.py`: field comparison returns MATCH/MISMATCH without printing the value. All phone/phone_verified reads replaced with `_assert_user_field()` → `pbj_cmp.py`. |
| D24-5 | HTTP helper captured only status and response body path; no headers, content-type, size, or timing evidence. | `pbj_http.py` now accepts up to 4 additional caller-supplied output files: sanitized headers, content-type, response size, time_total. New `pb_capture_full()` exposes all evidence. Alias-enumeration uses `pb_capture_full()` and adds `T-ALIAS-ENUM-CT-UNIFORM`, `T-ALIAS-ENUM-SIZE-UNIFORM`, `T-ALIAS-ENUM-TIMING` tests. |
| D24-6 | `pbj_http.py` proceeded as anonymous when the auth file was missing, unreadable, or malformed — silent security downgrade. | `pbj_http.py` takes explicit `auth_mode` argument (`anon`\|`auth`). If `auth_mode='auth'` and the auth file fails any validation (missing, not a regular file, symlink, malformed header), the helper writes `000` to status_out and exits non-zero before invoking curl. Anonymous and authenticated requests are never conflated. |
| D24-7 | Concurrent-send test passed when `active_cnt <= 1` — zero successes, zero active OTPs, unresolved pending records all passed. | Test now requires: at least 1 successful worker, exactly 1 sent_active, 0 pending_send, 5 total attempt records (active + failed + consumed), all in terminal states. |
| D24-8 | Cleanup-failure response included the internal OTP record ID and raw exception text. | All adapter error responses use generic client-safe messages. No record IDs, no raw exceptions, no phone/code values in any response body. |
| D24-9 | Manifests did not contain a traceability matrix mapping CP0 requirements to test IDs. | Complete traceability matrix added to `release1b_test_manifest.json` covering all mandatory requirements, test IDs, harness functions, expected results, and blocking/unresolved classifications. |
| D24-10 | Antenatal route inventory absent from harness and manifests. | Static route inventory added to `release1b_test_manifest.json` listing all required frontend surfaces with gating requirements and CP0 concerns. NEEDS-EXTERNAL items flagged. CP0 inventories surfaces only; does not implement the frontend gatekeeper. |
| D24-11 | Email lifecycle classified as `t_authorized_exclusion` citing "Requires production SMTP." | Reclassified as `t_unresolved "T-EMAIL-LIFECYCLE-CHANGE"` with documented prerequisite (local SMTP fixture). Operator instructions §9 describe the resolution path. |
| D24-12 | Byte counts in delivery message differed from uploaded files; no post-writing correction. | Byte counts reported after all writing is complete (final tool output). Provenance limitation documented accurately: template is a template, not pre-populated. |

---

## B. Duplicate Test Execution Design (D24-1)

**Root cause:** `t_phone_future_state_group()` called the four OTP lifecycle functions. `pb_run_all_tests()` also called them directly. When the first group ran, IDs were registered. When `pb_run_all_tests()` called them again, `_t_record_outcome()` detected duplicates and invoked `_t_fatal_internal()` for each one.

**Fix:** `t_otp_lifecycle_group()` is the single, authoritative group containing all phone and OTP lifecycle tests. `pb_run_all_tests()` calls `t_otp_lifecycle_group` exactly once. The old separate group function is gone.

**Static dedup checker:** `pbj_dupeid.py` scans the harness source for literal `t_pass/t_fail/...` calls whose quoted ID starts with `T-`. Any ID appearing more than once causes the checker to fail. Dynamic IDs (containing `${...}`) are excluded from static analysis.

---

## C. NSU Deletion Design (D24-2)

**Lifecycle:**
```
pb_create_local_superuser():
  → pbj_tok.py: validate response, write token to _NSU_TOK_FILE, write rec_id to _NSU_REC_FILE
  → pbj_auth.py: build auth config file

pb_delete_local_superuser():
  → read rec_id from _NSU_REC_FILE
  → DELETE /api/collections/_superusers/records/{rec_id} using _NSU_AUTH_CFG
  → GET    /api/collections/_superusers/records/{rec_id} using _NSU_AUTH_CFG
     - 404: record gone, token briefly valid for verification
     - 401: token invalidated because record was deleted (both prove deletion)
  → pb_wipe_secret_file: _NSU_TOK_FILE, _NSU_AUTH_CFG, _NSU_REC_FILE
  → T-SU-DELETE: PASS only if verification returned 404 or 401
     FAIL + CLEANUP_FAILURE=1 if any step fails
```

---

## D. Token Security Design (D24-3, D24-4)

**Process args (D24-3):**
- Before: `cmd += ['-H', 'Authorization: Bearer TOKEN']` — token visible in `ps`
- After: token written to permission-600 curl config file → `cmd += ['--config', cfg_path]` — only the config file path appears in `ps`; config file deleted after request

**Token extraction (D24-4):**
- Before: inline Python printed token to stdout → captured in shell variable
- After: `pbj_tok.py` writes token directly to permission-600 file; prints only `OK` or `ERROR:reason`

**Sensitive field comparison (D24-4):**
- Before: `_read_user_field "$id" "phone"` returned and printed the phone value
- After: `_assert_user_field "$id" "phone" "$expected"` calls `pbj_cmp.py`; returns MATCH or MISMATCH without printing the actual value

---

## E. HTTP Evidence Design (D24-5, D24-6)

**D24-5 outputs (all caller-supplied, concurrency-safe):**
```
status_out     HTTP status code (always written)
resp_path_out  path to response body file (always written)
hdr_out        sanitized response headers (optional; BLOCKED_HDR list applied)
ct_out         content-type (optional)
size_out       response size in bytes (optional)
time_out       total request time in seconds (optional)
```

**D24-6 auth mode contract:**
```
auth_mode='anon'  → no auth header; auth_file ignored
auth_mode='auth'  → auth_file required and validated before curl is invoked
                    failure → status_out='000', exit non-zero (no curl call)
```

Alias enumeration tests use `pb_capture_full()` with all evidence files, then compare:
- `T-ALIAS-ENUM-CT-UNIFORM`: all four content-types identical
- `T-ALIAS-ENUM-SIZE-UNIFORM`: response sizes within 70% of each other
- `T-ALIAS-ENUM-TIMING`: max/min timing ratio < 10× (potential timing oracle detection)

---

## F. Concurrent Send Design (D24-7)

**Required result for 5 concurrent OTP request workers (success mode):**

| Check | Requirement |
|---|---|
| At least 1 success | `w_success >= 1` |
| No unexpected statuses | `w_other == 0` |
| Exactly 1 sent_active | `active_cnt == 1` |
| No pending_send leftover | `pending_cnt == 0` |
| Total records | `active + failed + consumed == 5` |

Each worker creates one pending_send in TX-1. TX-2 either activates it (setting prior actives to send_failed via `_invalidatePriorActive`) or marks it send_failed. Result: exactly 1 active, 4 failed.

---

## G. NEEDS-EXTERNAL Items

| ID | Item | Status |
|---|---|---|
| NE-1 | PB archive SHA-256 from GitHub API | RUNNABLE |
| NE-2 | HOOK_SRC_PATHS (3 hooks) | UNRESOLVED |
| NE-3 | HOOK_EXPECTED_SHA256 (3 hooks) | UNRESOLVED |
| NE-4 | RELEASE1B_SCHEMA_SRC | UNRESOLVED |
| NE-5 | OTP rate-limit policy | DEFERRED-MANDATORY |
| NE-6 | Idempotency policy | DEFERRED-MANDATORY |
| NE-7 | articles.listRule fix authorization | UNRESOLVED |
| NE-8 | Binary test asset for T-FILE-AUTH-5/7 | UNRESOLVED |
| NE-9 | Other hooks scope review | UNRESOLVED |
| NE-10 | S-3 production credential status | SEPARATE INCIDENT |
| NE-11 | Local SMTP fixture for T-EMAIL-LIFECYCLE-CHANGE | UNRESOLVED |
| NE-12 | Frontend route exact paths (route inventory) | NEEDS-EXTERNAL |
| NE-13 | Service worker cached route inventory | NEEDS-EXTERNAL |

---

**Application publication remains unauthorized.**
