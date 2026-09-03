# Release 1B — Round 23 Correction Matrix and Review

---

## A. Round 23 Correction Matrix

| Defect | R22 Issue | R23 Correction |
|---|---|---|
| D23-1 | Fatal zsh syntax error: `return 1 fi` (3 occurrences) — harness could not parse | All `if` blocks use proper newline-terminated `fi`. Pattern `return N; fi` eliminated throughout. |
| D23-2 | Used `pocketbase admin create` and `/api/admins/auth-with-password` (pre-v0.28 terminology) | NSU created via migration `0000000001_r23_nsu_bootstrap.js`. Auth endpoint: `/api/collections/_superusers/auth-with-password`. Runtime tests verify collectionName==_superusers and token validity. |
| D23-3 | Password passed via `"$(cat "$su_pw_file")"` in CLI arguments | Migration-based bootstrap: password in local non-exported shell variable (cleared immediately after writing migration file). Migration file mode 600, isolated root mode 700. File deleted after PB startup. No password in process args, env listings, history, or retained files. |
| D23-4 | OTP adapter stored no requesting user ID; any authenticated user could verify another user's OTP | `requesting_user_id` stored in TX-1. TX-3 verifies `otp.requesting_user_id == e.auth.id`. T-PHONE-OTP-CROSS-USER: User B's verify attempt (User A's OTP) rejected 403/400; OTP stays active. |
| D23-5 | Throw after save inside TX-3 rolled back the save; expired state was not committed. Comment was false. | Return-from-TX pattern: TX commits expired state, control returns from callback, throw happens outside. T-OTP-EXPIRED verifies adapter_status=expired persists. |
| D23-6 | TX-2 cleanup used empty `catch (_) {}` — cleanup failures silently swallowed; 400 claimed even when state unknown | Cleanup uses `$app.runInTransaction()`; catch is not empty; 500 returned on cleanup failure. T-OTP-DB-FAIL-CLEANUP-FAIL verifies 500 and pending record remains. |
| D23-7 | Concurrent verify passed on `success_count <= 1` (zero successes passed) | Condition is now `success_count == 1`. DB-state verified: consumed=1, active=0, correct user has phone+pv. Concurrent send verified: DB state and HTTP outcomes. |
| D23-8 | Worker loops called `t_fail` per worker, creating multiple identical IDs → double-outcome | Workers collect evidence without terminal calls. Single `t_pass/t_fail/t_harness_err` per group after aggregation. Applied to all concurrent tests. |
| D23-9 | `_t_record_outcome` detected duplicate and called `t_blocking`, which re-entered `_t_record_outcome` | `_t_fatal_internal` directly manipulates counters without calling any terminal function. Non-recursive by design. Selftest: PASS/PASS, PASS/FAIL, FAIL/PASS detected via isolated `_st_rec`. |
| D23-10 | OTP request/verify bodies used `printf '{"phone":"%s"}'` (raw shell interpolation) | All OTP bodies use `_otp_body_request()` and `_otp_body_verify()` which call `PBJ_PY`. Applied to sequential and concurrent workers. |
| D23-11 | Checksum limitation claimed corrected; byte counts inaccurate; no protection against overwriting baseline | Limitation documented as irresolvable provenance (not a corrected defect). Verifier rejects symlinks and non-regular files. `--generate` refuses to overwrite populated baseline without `--replace`. |
| D23-12 | Rate-limit safety implied while DEFERRED-MANDATORY | D23-12 note in every manifest and review. No claim of rate-limit safety. Transactional capability vs. policy explicitly separated. |
| D23-13 | No static acceptance gate reported in delivery | Gate results reported in delivery message. Patterns scanned: obsolete `/api/admins/`, `pocketbase admin create`, raw OTP JSON, swallowed errors, duplicate terminal calls. |

---

## B. NSU Bootstrap Design (D23-2, D23-3)

**Why migration instead of CLI:**

PocketBase v0.29.3 CLI commands for superuser management (`superuser upsert` or similar) require the password as a positional argument, which appears in process listings. The migration approach avoids all CLI usage for credential operations.

**Credential handling chain:**

```
openssl rand → write to _NSU_PW_FILE (mode 600)
          │
          └─ printf to migration file (mode 600, isolated root mode 700)
             local _su_pw cleared immediately
          │
PocketBase starts → migration runs → NSU created → migration file deleted
          │
          └─ pb_create_local_superuser(): auth via API
             PBJ_PY reads password from _NSU_PW_FILE (never in process args)
             CURL reads body from file (--data-binary @file)
             pb_wipe_secret_file(_NSU_PW_FILE) called after successful auth
```

The password exposure window is: between migration file write and PocketBase processing it (sub-second at local startup). The file is then deleted.

**Runtime verification (D23-2):**

```
T-SU-CREATE-AUTH:  HTTP 200 from /api/collections/_superusers/auth-with-password
T-SU-COLL-CHECK:   response.record.collectionName == "_superusers"
T-SU-TOKEN-VALID:  token matches ^[A-Za-z0-9._\-]{10,}$ pattern
T-SU-DELETE:       NSU token and auth config wiped
```

---

## C. OTP User Binding Design (D23-4)

The `phone_otps.requesting_user_id` field (text, added by future schema migration) stores `e.auth.id` from the OTP request route. TX-3 verifies this field matches the current caller before consuming the OTP.

**Cross-user attack test:**

```
User A: POST /api/auth/request-whatsapp-otp {phone: SYNTH_PHONE_XUSER}
        → OTP created with requesting_user_id = A.id

User B: POST /api/auth/verify-whatsapp-otp {phone: SYNTH_PHONE_XUSER, code: <A's code>}
        → TX-3: otp.requesting_user_id (A.id) != e.auth.id (B.id)
        → 403 Forbidden

Verify: User B's phone unchanged, pv unchanged.
        OTP still active (not consumed by rejected attempt).
```

---

## D. Expiry Handling Design (D23-5)

**Wrong pattern (R22):**
```javascript
// Inside TX:
matched.set("adapter_status", _ST_EXPIRED);
txApp.save(matched);
throw new BadRequestError("OTP expired.");   // ← rolls back the save above
// Expired state NOT committed.
```

**Correct pattern (R23):**
```javascript
// Inside TX:
if (exp < now) {
  matched.set("adapter_status", _ST_EXPIRED);
  txApp.save(matched);
  outcome.action = "expired";
  return;   // ← exit callback; TX COMMITS the expired state
}
// ... verification proceeds

// After TX exits:
if (outcome.action === "expired") {
  throw new BadRequestError("OTP expired.");   // throw OUTSIDE TX
}
```

TX commits the expired state. Throw happens after the TX has already committed.

---

## E. TX-2 Cleanup Design (D23-6)

**Wrong pattern (R22):**
```javascript
try {
  // ... cleanup save
} catch (_) {}   // ← silently swallows failure
throw new BadRequestError("db_fail_request: ... record cleaned to send_failed.");
// If catch fired, this claim is false.
```

**Correct pattern (R23):**
```javascript
var cleanupSucceeded = false;
try {
  $app.runInTransaction(function(txApp) {
    if (currentMode === "db_fail_request_cleanup_fail") {
      throw new Error("simulated cleanup failure.");
    }
    var rec = txApp.findRecordById("phone_otps", otpRecId);
    rec.set("adapter_status", _ST_FAILED);
    txApp.save(rec);
  });
  cleanupSucceeded = true;
} catch (cleanupEx) {
  cleanupErrMsg = String(cleanupEx);
}
if (!cleanupSucceeded) {
  throw new InternalServerError("TX-2 rollback cleanup failed. State unresolved.");
}
throw new BadRequestError("TX-2 rolled back. Record cleaned to send_failed.");
```

---

## F. Concurrent Verification Design (D23-7, D23-8)

**D23-7: Exactly 1 success (corrected from ≤1):**

```zsh
# D23-7: must be EXACTLY 1 success
if (( success_count != 1 )); then
  t_fail "T-CONCURRENCY-OTP-VERIFY" "Expected exactly 1 success; got ${success_count}"
  return
fi
```

DB-state verification: `consumed=1`, `active=0`, correct user has `phone+pv` set.

**D23-8: Single terminal result per group:**

Workers write status to independent files. After `wait`, aggregate counts are computed. Only then is a single `t_pass/t_fail/t_harness_err` emitted for the group.

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
| NE-11 | PocketBase v0.29.3 CLI command for superuser | NOT NEEDED (migration bootstrap used) |

---

**Application publication remains unauthorized.**
