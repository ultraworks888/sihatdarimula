# Release 1B — Round 22 Review and Correction Matrix

---

## A. Round 22 Correction Matrix

| Defect | R21 Issue | R22 Correction |
|---|---|---|
| D22-1 | Checksums: SHA256_COMPUTE_REQUIRED placeholders; stale byte counts (stated 122061/14474; observed 128879/15978) | Added `release1b_r22_checksums.py` as 10th named artifact. `--generate` computes and writes `release1b_r22_checksums.sha256`. `--verify` exits nonzero on any failure. No lock file. Constraint acknowledged: SHA-256 pre-computation requires shell execution unavailable in AI tool environment. |
| D22-2 | False claim "PocketBase JS hooks do not support application transactions" appears in adapter, manifests, review, instructions | Removed from all artifacts. `$app.runInTransaction()` used in adapter TX-1, TX-2, TX-3. Reference: https://pocketbase.io/docs/js-records/#transaction |
| D22-3 | Verify route made two independent saves; db_fail_verify left OTP consumed and user unverified | TX-3 uses `$app.runInTransaction()`: re-reads OTP, validates, marks consumed, sets users.phone and phone_verified — all atomically. On throw (including db_fail_verify): transaction rolls back. OTP stays active (retryable). Phone unchanged. No partial commit. |
| D22-4 | Test pre-set users.phone before OTP verification; only phone_verified tested in verify step | Test starts with blank users.phone. Ordinary users cannot PATCH users.phone directly (guard hook blocks). OTP verify route stores candidate in phone_otps.phone; TX-3 atomically writes users.phone + phone_verified. |
| D22-5 | Request and verify routes accepted unauthenticated and any-role callers | Both routes now require ordinary-user token. Anonymous → 401. Admin → 403. Superadmin → 403. Tests: T-PHONE-OTP-AUTH-ANON/ADMIN/SADMIN. |
| D22-6 | Tests could emit both FAIL and PASS (e.g. `pb_capture ... \|\| { t_fail ... }; t_pass ...`) | All test functions: exactly one terminal outcome. `_t_record_outcome()` records each test ID once; BLOCKING if called twice. t_harness_selftest proves double-outcome detection. |
| D22-7 | Duplicate body creation left orphaned tmpfile in t_phone_otp_sets_both | Removed `printf ... > "$(body_f=$(pb_secure_tmpfile .json); ...)"` orphan. Single `pb_secure_tmpfile` call, deterministic cleanup. |
| D22-8 | Review said "queries phone_otps by generated unique email" — wrong collection | Corrected: queries `users` collection by email. Documentation updated in review, test description, and all manifests. |
| D22-9 | Guard hook protected phone_verified but not phone; mixed-field requests not tested | Guard hook protects both `phone` and `phone_verified`. T-PHONE-MIXED-FIELD-REJECT: PATCH {phone + name} as ordinary user → 403 → verify NEITHER field persisted. |
| D22-10 | Hook said "only OTP path" but allowed NSU HTTP access; policy ambiguous | One defined policy: NSU = emergency recovery capability. Consistency checks (before NSU bypass): cannot set phone_verified=true without non-blank phone; admin/superadmin accounts blocked. T-PHONE-NSU-RECOVERY and T-PHONE-NSU-PV-NO-PHONE test the policy. |
| D22-11 | Lifecycle gaps: pending_create_fail not tested; no concurrent verify test | Added: T-OTP-PENDING-CREATE-FAIL (TX-1 rollback), T-PHONE-OTP-ROLLBACK (TX-3 rollback, OTP retryable), T-CONCURRENCY-OTP-VERIFY (concurrent verify; at most 1 TX-3 commits). |
| D22-12 | Concurrency tests not separated; rate-limit and idempotency unresolved but described as runnable | Separated into: lifecycle (T-OTP-*), send concurrency (T-CONCURRENCY-OTP-SEND), verify concurrency (T-CONCURRENCY-OTP-VERIFY), rate-limit/idempotency (DEFERRED-MANDATORY). Workers: independent dirs, bodies, status files, resp files. |
| D22-13 | Cleanup validation not self-tested | t_harness_selftest: rejects empty path, root, wrong parent, no-marker dir, symlink. Accepts valid isolated root. |

---

## B. Transaction Design

PocketBase v0.29.3 JavaScript API provides `$app.runInTransaction((txApp) => { ... })`.
Reference: https://pocketbase.io/docs/js-records/#transaction

Database operations inside the callback must use `txApp`, not `$app`. If the callback throws, the transaction rolls back. No operations persist.

**Adapter lifecycle with transactions:**

```
REQUEST:
  TX-1: atomically create pending_send record (→ rollback: no record)
  (outside TX): local provider fixture
  TX-2: transition pending → sent_active or send_failed
    db_fail_request: TX-2 throws → rollback → external cleanup sets send_failed

VERIFY:
  TX-3: re-read active OTP + validate + consume + write users.phone + write phone_verified
    db_fail_verify: throw before any save → rollback → OTP stays active (retryable)
```

The `db_fail_verify` rollback test proves that failure produces zero partial state: OTP retryable, phone unchanged, phone_verified unchanged.

---

## C. Phone Field Protection Design

Guard hook (`release1b_r22_phone_verified_guard.pb.js`, written inline by harness) protects both `users.phone` and `users.phone_verified`.

**Policy:**

| Caller | phone PATCH | phone_verified PATCH |
|---|---|---|
| Ordinary user | 403 | 403 |
| Admin | 403 | 403 |
| Superadmin | 403 | 403 |
| NSU | Permitted (emergency recovery) | Permitted if phone non-blank; 400 if blank |
| Internal $app.save() (TX-3) | Permitted | Permitted |

**Mixed-field rejection:** A request containing `phone` or `phone_verified` alongside other fields (`name`, `language`, `avatar`) is atomically rejected — PocketBase does not partially apply fields when a hook throws. No field persists.

**NSU emergency recovery tested by:**
- `T-PHONE-NSU-RECOVERY`: sets phone + phone_verified together → 200; both fields set
- `T-PHONE-NSU-PV-NO-PHONE`: sets phone_verified=true without phone → 400 (consistency)
- `T-PHONE-ADMIN-NO-PV-ON-ADMIN`: guard blocks admin/superadmin accounts from eligibility

---

## D. OTP Auth Contract

Both `request-whatsapp-otp` and `verify-whatsapp-otp` require an ordinary-user session token. The verify route uses `e.auth.id` to identify the target user; the caller IS the linked user. This prevents one user from verifying a phone for another user's account.

**Admin/superadmin note:** Application administrators cannot use the phone-linking flow for their own accounts. Administrators may manage a notification phone preference via a separate server-side administrative path (outside CP0 scope). They cannot become eligible for phone authentication via the OTP linking flow.

---

## E. Checksums Constraint

SHA-256 computation requires shell execution. The Coderick AI tool environment has no shell execution capability. This constraint is irresolvable within the current tool environment.

**R22 resolution:** `release1b_r22_checksums.py` is a named artifact (10th deliverable) that generates and verifies `release1b_r22_checksums.sha256`. The operator runs `--generate` once after receipt. This is distinct from "establishing a baseline by running --compute on the checksums file itself" (R20) and from "overwriting a delivered baseline" (R21): the delivered `release1b_r22_checksums.sha256` is an empty template; generation creates the baseline rather than overwriting one.

---

## F. NEEDS-EXTERNAL Items

| ID | Item | Status |
|---|---|---|
| NE-1 | PB archive SHA-256 from GitHub API | RUNNABLE — operator fetches from API |
| NE-2 | HOOK_SRC_PATHS (3 hooks) | UNRESOLVED |
| NE-3 | HOOK_EXPECTED_SHA256 (3 hooks) | UNRESOLVED |
| NE-4 | RELEASE1B_SCHEMA_SRC | UNRESOLVED |
| NE-5 | OTP rate-limit policy | DEFERRED-MANDATORY |
| NE-6 | Alias marker necessity | DEFERRED |
| NE-7 | articles.listRule fix authorization | UNRESOLVED |
| NE-8 | Binary asset for T-FILE-AUTH-5/7 | UNRESOLVED |
| NE-9 | Idempotency policy | DEFERRED-MANDATORY |
| NE-10 | S-3 production credential status | SEPARATE INCIDENT |
| NE-11 | Other hooks scope review | UNRESOLVED |

---

## Stop Condition

Round 22 correction matrix complete. Ten artifacts delivered to `release1b_round22/`.

**Application publication remains unauthorized.**
