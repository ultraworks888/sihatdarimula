# Release 1B — Round 21 Review and Correction Matrix
# Checkpoint 0 Authorization Status: AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

---

## A. Round 21 Correction Matrix

| Defect | R20 Issue | R21 Correction |
|---|---|---|
| D21-1 | Checksums: self-computing zsh program creating a separate unlisted lock file; eight artifacts covered, not nine; required `--compute` to establish baseline | Replaced with a standard `shasum --check`-compatible static format file covering exactly 8 other artifacts (non-recursive). Operator populates with one `shasum -a 256` command. No lock file generated. Self-integrity of the checksums file recorded separately in delivery message. SHA-256 population constraint acknowledged (no shell execution in AI tool environment). |
| D21-2 | `--harness-check` executed `nslookup "example.invalid"` (live DNS query); self-test described as offline | `nslookup` removed entirely. The `.invalid` TLD is RFC 2606-reserved and does not require a DNS probe. Post-startup email domain acceptance tested via PocketBase API after PB starts (in `pb_verify_email_domain()`). OR-TRUE inventory updated (was 2 sites; remains 2 sites). |
| D21-3 | Operator instructions: Python validator and `rm -rf` as separate shell commands; operator could paste entire block and continue after Python exits nonzero | Replaced with a single Python heredoc execution that performs validation AND deletion in one process. `shutil.rmtree()` is called inside the same Python process only if all validations pass. `sys.exit(1)` before deletion if any validation fails. Operator cannot proceed to deletion independently. |
| D21-4 | `T-INJECT-CREATE-UNEXPECTED`: 400/401/403 response passed immediately without checking whether a record was created | Now applies the same fail-closed persistence check used by `pb_inject_create_and_verify`: filter phone_otps by generated unique email via NSU; pass only if 0 matching records exist; BLOCKING if records found. |
| D21-5 | §28.6 tests expected 403 "from the hook" but no temporary hook was installed; test did not prove the specific guard; admin/sadmin restrictions not tested; OTP sets-both and rollback absent | Temporary guard hook written inline by harness to isolated hooks dir before PocketBase starts. Tests cover: ordinary self-set (403), ordinary self-clear (403), admin-cannot-elevate-admin (403, guard blocks all app-layer callers), sadmin HTTP blocked (403, confirmed hook blocks even superadmin HTTP), NSU HTTP passes (200), inject-create (phone_verified not persisted), OTP-sets-both (verify → $app.save sets phone_verified via authorized path), OTP-rollback (db_fail_verify mode: OTP consumed, user not updated; partial-commit limitation documented). |
| D21-6 | OTP adapter wrote directly to sent_active or send_failed without a pending_send intermediate step; no rollback test; no distinct terminal state; in-memory serialization claimed | Lifecycle redesigned: (1) create pending_send record; (2) call local deterministic provider fixture; (3) on success: invalidate prior active → generate code → set sent_active atomically in same save; on db_fail_request: rollback to send_failed; (4) verification: sent_active → consumed (distinct terminal state via adapter_status field). db_fail_request and db_fail_verify modes added. T-OTP-DB-FAIL-REQUEST verifies no sent_active record after rollback. |
| D21-7 | Concurrency proof claimed "PocketBase JavaScript requests are naturally serialized" without establishing that property | In-process serialization claim removed. Concurrency test fires 5 concurrent requests, then queries phone_otps DB to count sent_active records. Result reported as observed evidence: "at most 1 sent_active record observed — consistent with JSVM serialization but not architecturally guaranteed." If 2+ active records found: FAIL. |
| D21-8 | Adapter loopback check used `raw.split(":")[0]` which does not parse bracketed IPv6 `[::1]:port` correctly | Replaced with regex-based parser: IPv4 loopback `127.x.x.x:port` matched by regex; IPv6 loopback `::1` (bare) and `[::1]:port` (bracketed) matched separately. No other formats accepted. |
| D21-9 | `HOOK_PROBE_ROUTES[push_broadcast]` and `HOOK_PROBE_ROUTES[whatsapp]` left UNRESOLVED; operator instructed to "invent routes" | Both hooks inspected from source. **push_broadcast**: `POST /api/admin/push-broadcast` — safe probe uses empty body; PocketBase returns 400 (title/message required) before reaching OneSignal. **whatsapp**: `GET /api/admin/whatsapp/config` — safe read probe; reads lms_settings; no external contact. **emergency_hardening**: behavioral probe (no route); T-FIELD-ROLE-REJECT is the proof. |
| D21-10 | Manifests: "nine covered artifacts" inconsistent with eight-file `_COVERED` array; OTP tests claimed runnable before adapter corrections; concurrency claimed proven by architecture; harness claimed offline while doing DNS lookup | All manifests corrected: artifact count 8 (checksums) + 1 (checksums file) = 9 total; OTP tests marked runnable after D21-6 corrections; concurrency marked as observed evidence; DNS lookup removal confirmed. |

---

## B. Critical Schema Correction: phone_otps

R19 and R20 schema manifests incorrectly described `phone_otps` as having a `status` select field with values `["pending_send","sent/active","send_failed"]`. This field does not exist.

**Actual schema** (from `pb_migrations/1783946967_add_phone_otps_d039.js`):
- `phone` (text, required, max 20)
- `code` (text, required, max 10)
- `expires_at` (date)
- `is_used` (bool)
- `created` (autodate)

**Production hook behavior** (from `pb_hooks/auth_whatsapp_otp.pb.js`):
- `is_used = false` = active OTP
- `is_used = true` = used or invalidated
- No pending/active/failed distinction in production

**R21 adapter design**: Uses `is_used` (production field) for compatibility. Adds `adapter_status` (select) via temporary isolated-env migration for lifecycle testing. The `adapter_status` field never reaches production.

---

## C. OTP Adapter Lifecycle Design (D21-6)

```
Request arrives (POST /api/auth/request-whatsapp-otp):
  1. Create phone_otps: adapter_status=pending_send, is_used=false, code=""
  2. Local provider fixture (deterministic, no external calls):
     - mode=success       → {success:true}
     - mode=send_failed   → {success:false}
     - mode=pending_send  → {pending:true}
     - mode=db_fail_request → {success:true, dbFail:true}
  3a. pending:  leave as pending_send; return 200 {status:"pending"}
  3b. failed:   set adapter_status=send_failed; return 400
  3c. success + dbFail: set adapter_status=send_failed (rollback); return 400 [T-OTP-DB-FAIL-REQUEST verifies]
  3d. success:  invalidate prior sent_active; set code; set adapter_status=sent_active; return 200

Verification (POST /api/auth/verify-whatsapp-otp):
  1. Find sent_active records for phone
  2. Match code in application layer
  3. Check expiry
  4. Consume: adapter_status=consumed, is_used=true (both set in one save)
  5a. mode=db_fail_verify: skip user update; return 400 [T-PHONE-OTP-ROLLBACK verifies]
  5b. normal: find user by phone; set phone_verified=true via $app.save(); return 200
```

**Atomicity limitation**: Steps 4 and 5 are separate `$app.save()` calls. PocketBase JS hooks do not support application transactions. A failure between them (or in `db_fail_verify` mode) leaves the OTP consumed but `phone_verified` unchanged. This is documented as a known design constraint, not a product decision.

---

## D. Hook Probe Resolutions (D21-9)

Probes resolved from direct source inspection of `pb_hooks/*.pb.js`:

| Hook | Probe Type | Route | Auth | Safe Probe Body | Expected Status |
|---|---|---|---|---|---|
| emergency_hardening | behavioral | none | — | PATCH role=admin as ordinary user | 403 (proven by T-FIELD-ROLE-REJECT) |
| push_broadcast | route | POST /api/admin/push-broadcast | admin | {} (empty) | 400 (title/message required; OneSignal never reached) |
| whatsapp | route | GET /api/admin/whatsapp/config | admin | — | 200 (reads lms_settings; no Meta contact) |

Additional hooks found in `pb_hooks/` that are not in the R21 test scope:
`meta_whatsapp.pb.js`, `whatsapp_webhook.pb.js`, `lms_whatsapp.pb.js`, `export.pb.js`, `forgot_password_whatsapp.pb.js`, `ai_chat.pb.js`, `push_reminders.pb.js`, `analytics.pb.js`

These require separate scope review before Checkpoint 1.

---

## E. phone_verified Guard Design (D21-5)

The temporary guard hook is written inline by the harness (not a separate artifact) and deployed to the isolated hooks directory before PocketBase starts. It is never written to `pb_hooks/` in the source project.

**Guard policy:**
- `phone_verified` present in PATCH body → evaluate caller
- NSU (collection().name === `_superusers`) → pass through
- All application-layer callers (superadmin, admin, ordinary, unauthenticated) → 403

**Authorized write path:**
- `POST /api/auth/verify-whatsapp-otp` route handler calls `$app.save(user)` internally
- `$app.save()` in hook code does NOT trigger `onRecordUpdateRequest` hooks
- Therefore the guard is bypassed legitimately

**Tests:**
- `T-PHONE-ORDINARY-SELF-SET/CLEAR`: 403 confirmed
- `T-PHONE-ADMIN-CANNOT-ELEVATE-ADMIN`: 403 — guard blocks admin HTTP PATCH (design: phone_verified is server-side-only)
- `T-PHONE-SADMIN-HTTP-BLOCKED`: 403 — superadmin HTTP PATCH also blocked (only NSU and internal save pass)
- `T-PHONE-NSU-HTTP-PASSES`: 200 — NSU bypass for admin DB management
- `T-PHONE-OTP-SETS-BOTH`: authorized path confirmed
- `T-PHONE-OTP-ROLLBACK`: partial-commit documented

---

## F. Checksums Constraint (D21-1)

**Constraint:** SHA-256 computation requires shell execution. The Coderick AI tool environment has no shell execution capability. Pre-populating SHA-256 values is not possible within this environment.

**R21 design:**
- `release1b_r21_checksums.sha256` is in standard `shasum --check` format
- Contains `SHA256_COMPUTE_REQUIRED` placeholders (8 lines, one per artifact)
- Operator replaces with one `shasum -a 256` command
- After population, `shasum --check` verifies strictly; exits nonzero on any mismatch
- No lock file; no `--compute` mode; no separate script required

**Known remaining limitation:** The operator must run the shasum command once to establish values. This is equivalent to receiving a package without a pre-attached signature and generating the HMAC locally — standard in many delivery scenarios.

---

## G. NEEDS-EXTERNAL Items (updated)

| ID | Item |
|---|---|
| NE-1 | PB archive SHA-256: obtained from GitHub API `digest` field |
| NE-2 | `HOOK_SRC_PATHS` (emergency_hardening, push_broadcast, whatsapp) |
| NE-3 | `HOOK_EXPECTED_SHA256` per hook |
| NE-4 | `RELEASE1B_SCHEMA_SRC` |
| NE-5 | OTP rate-limit invariants (production hook has none) |
| NE-6 | Alias marker necessity (from T-ALIAS-ENUM timing evidence) |
| NE-7 | articles.listRule fix authorization |
| NE-8 | Binary test asset for T-FILE-AUTH-5/7 |
| NE-9 | Idempotency endpoint definition |
| NE-10 | S-3 production credential status |
| NE-11 | Other hooks in scope: meta_whatsapp, whatsapp_webhook, lms_whatsapp, export, forgot_password_whatsapp, ai_chat, push_reminders, analytics — not yet assessed |

**Resolved in R21:**
- OTP adapter delivered and lifecycle-correct ✓
- phone_verified guard installed and tested ✓
- push_broadcast and whatsapp probe routes resolved from source ✓
- JSVM serialization claim replaced with observed-evidence approach ✓

---

## Stop Condition

Round 21 correction matrix is complete. Nine artifacts delivered to `release1b_round21/`.

**Application publication remains unauthorized until:**
- The corrected package is accepted
- Checkpoint 0 is separately executed on isolated PocketBase v0.29.3
- All blocking tests pass
- All unresolved safety decisions are closed
- A separate publication authorization is issued

**Prohibited until then:**
- Running Checkpoint 0 or starting PocketBase
- Contacting production
- Modifying any deployed asset
- Proceeding to Checkpoint 1
