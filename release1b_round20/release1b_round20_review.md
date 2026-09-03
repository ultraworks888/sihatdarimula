# Release 1B — Round 20 Review
# Checkpoint 0 Authorization Status: AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

---

## A. Round 20 Correction Matrix

| Defect | R19 Issue | R20 Correction |
|---|---|---|
| D-1 | Checksum file contained OPERATOR-COMPUTES placeholders; verifier printed FAIL and continued | Replaced with self-computing zsh script (`--compute`/`--verify`). `--verify` exits nonzero (exit 1) on malformed records, placeholders, missing/extra artifacts, duplicates, hash mismatches, byte-count mismatches. Self-integrity computed separately (non-recursive). |
| D-2 | Operator instructions stated GitHub "provides only archive downloads"; checksum pre-stored in harness constant | Operator instructions updated: use GitHub release-assets API, require exactly one matching asset, require non-null `sha256:` digest, verify downloaded size and SHA-256 against API metadata, stop before extraction on any mismatch. No secret required. |
| D-3 | `pb_apply_schema_migrations()` copied all `*.js` files and explicitly noted the isolated db would apply the seed credential migration | Seed migration excluded by exact validated filename. New `pbj_cred_scan.py` helper scans all other migrations for credential patterns; fail-closed if suspected; outputs filename+line number only (never content). If SEED_MIGRATION_EXCLUDE not found in source dir, harness BLOCKS (unexpected). Report sanitizer redacts seed identity patterns. Git history modification is not authorized and not mentioned. |
| D-4 | `pb_inject_create_and_verify()` treated all non-200 HTTP statuses as pass (transport failure, 5xx, empty status passed silently) | Strict contract: 400/401/403 = check no record was created (filter by generated unique email via NSU), then PASS if absence confirmed; 200 = verify persisted record; 000/empty/5xx = HARNESS_ERROR; unexpected status = FAIL; inability to verify persistence = BLOCKING. |
| D-5 | `T-INJECT-CREATE-UNEXPECTED` accepted HTTP 200 or 400 without reading persisted record | After 200, reads full persisted record via NSU. Verifies: `role` not admin/superadmin, `verified` not true, system-auth fields (`tokenKey`, `passwordHash`) not exposed, absent-schema fields not stored. Findings emitted as BLOCKING if violated. |
| D-6 | S-3 seed credential incident included in CP0 execution (harness applied migration to isolated db) | S-3 is a separate incident-response item documented in the review and operator instructions. Harness excludes the migration. Harness never reads, uses, or references the credential. Report sanitizer redacts seed identity patterns. No action on S-3 required to execute the harness. |
| D-7 | OTP adapter referenced in operator instructions but not delivered; T-OTP-FLOW and T-CONCURRENCY-OTP-SEND remained DEFERRED-MANDATORY | `release1b_otp_test_adapter.pb.js` delivered as the ninth covered artifact. Harness deploys it automatically (replaces `auth_whatsapp_otp.pb.js` in isolated hooks dir; source project hook is never modified). T-OTP-FLOW and T-CONCURRENCY-OTP-SEND are now executable. |
| D-8 | Report exported "before cleanup" but EXIT trap completes cleanup before the operator can run a copy command | Added `--report-dest=<path>` option. Before cleanup, harness sanitizes report, scans for residual disclosures (fail-closed), creates destination securely, copies atomically, verifies retained file, then removes isolated root. Destination validated: outside isolated root, no symlink, parent must exist. |
| D-9 | Manual cleanup used a placeholder `rm -rf "$_root"`; automatic `rm -rf` lacked canonical validation | `pb_validate_cleanup_target()` added. Required before all `rm -rf`. Checks: non-empty target, canonical parent matches `RELEASE1B_CANONICAL_PARENT`, `release1b_cp0_` prefix, not a symlink, not a prohibited path (`/`, `/tmp`, `$HOME`, etc.), `.release1b_marker` present. Manual cleanup instructions (§8) use a Python validation script that applies equivalent checks. |
| D-10 | `T-ART-ANON-POLICY` classified as UNRESOLVED (policy decision outstanding) | Policy is established: authentication precedes article access; ordinary users receive antenatal content only. `T-ART-ANON-POLICY` is now a scored test: expects 401/403; FAIL if articles are publicly readable (current schema: FAIL). `T-ART-ANTENATAL-AUTH-ONLY` added: expects postnatal articles not returned; FAIL if returned. |
| D-11 | `phone_verified` classified as an undecided concept; T-FIELD-PHONE-REJECT left DEFERRED-MANDATORY with no test path | Temporary local schema migration applied in isolated env during §28.6. Tests: (a) ordinary user PATCH own record with `phone_verified=true` → expect 403 from hook; (b) admin PATCH any record with `phone_verified=true` → expect 200; (c) create-path injection with `phone_verified=true` via `pb_inject_create_and_verify`. Source project schema never modified. |
| D-12 | Test email domain `release1b.local` is not RFC-reserved; could correspond to real mailbox or DNS entry | Replaced throughout with `example.invalid` (RFC 2606 §2, reserved for testing; cannot be delivered to any real mailbox). Post-startup self-test (`pb_verify_email_domain`) verifies PocketBase accepts the domain; BLOCKS if not. |
| D-13 | `HOOK_PROBE_ROUTES[emergency_hardening]` was `UNRESOLVED__NEEDS_EXTERNAL__hook_probe_route`; smoke test would invent a health route | `HOOK_PROBE_TYPE` map added. `emergency_hardening` type = `behavioral` (no standalone route). `t_hook_smoke_group()` skips route probe for behavioral type; notes that behavioral proof is in T-FIELD-ROLE-REJECT (§24). |

---

## B. Security Findings (carried from R19 with updates)

### S-1 — HIGH: Role Injection on Create

**Unchanged from R19.** `users.createRule = ""`. Emergency blocking test group (§28.5) verifies whether role injection is possible on the isolated v0.29.3 instance. If T-INJECT-CREATE-ANON-ADMIN BLOCKS, publication is halted until a create-path guard is applied.

**Emergency hardening proposal (unchanged; requires separate authorization):**

Option A (createRule restriction):
```
users.createRule = "@request.body.role:isset = false"
```

Option B (hook guard in `emergency_users_hardening.pb.js`):
```js
onRecordCreateRequest((e) => {
  const body = e.requestInfo().body;
  if (!("role" in body)) return e.next();
  try {
    if (e.auth && e.auth.collection().name === "_superusers") return e.next();
  } catch (_) {}
  if (e.auth && e.auth.getString("role") === "superadmin") return e.next();
  throw new ForbiddenError("Role cannot be set during registration.");
}, "users");
```

### S-2 — MEDIUM: phone_verified and is_alias_account Absent

`phone_verified` is now tested via a temporary local schema migration in §28.6.
`is_alias_account` alias design is tested in §26 using ordinary role=user accounts.
Whether a dedicated alias marker is required depends on whether enumeration timing
is uniform (T-ALIAS-ENUM results). If timing is uniform, the marker may not be needed.

### S-3 — CRITICAL: Committed Plaintext Credential

**Removed from CP0 execution scope (D-6).** The seed migration is excluded from
the isolated run. The harness never reads, uses, or references the credential.

**Operator incident-response items (independent of this test run):**
1. Determine whether the seed migration was applied to production.
2. If applied: verify the password was rotated.
3. If the email address is a live account: treat credential as compromised.
4. Manage repository history through your standard incident-response procedure.
   No destructive history operation is authorized as part of this package.

---

## C. Antenatal Policy Assessment (D-10)

The release requirements establish:
- Authentication and setup precede the antenatal content experience.
- Ordinary users in the antenatal phase receive only pregnancy-classified content.
- Postnatal, child-related, and unclassified content must fail closed.

**Current schema status (static finding):**
- `articles.listRule = ""` — all articles publicly readable. FAILS the first requirement.
- No server-side filter restricts postnatal articles from ordinary users. FAILS the second requirement.

**Scored tests:**
- `T-ART-ANON-POLICY`: expects 401/403. With current schema: predicted FAIL.
- `T-ART-ANTENATAL-AUTH-ONLY`: expects postnatal articles not returned. With current schema: predicted FAIL if postnatal articles exist.

**Required schema fix before publication:**
```
articles.listRule = "@request.auth.id != ''"
```

Server-side antenatal enforcement additionally requires either:
- A listRule that filters by `is_pregnancy = true` when the user's onboarding phase is active, OR
- Frontend-only enforcement (current approach; server exposes all articles to any authenticated user)

If server-side enforcement is required, this must be added before publication. Operator must confirm which approach is authorized.

---

## D. Phone Future State Summary (D-11)

Round 20 harness applies a temporary migration in the isolated environment
adding `phone_verified` (bool) to the users schema. Tests (§28.6):

| Test | Expected with S-1 fix (hook guard) | Expected without fix |
|---|---|---|
| `T-PHONE-FUTURE-SELF-SET` | PASS (403 from hook) | FAIL (user sets own phone_verified) |
| `T-PHONE-FUTURE-ADMIN-SET` | PASS (200, admin sets phone_verified) | may vary |
| `T-PHONE-FUTURE-INJECT-CREATE` | PASS (phone_verified not persisted on create) | FAIL (injection succeeds) |

These results inform whether the emergency_hardening hook needs updating
before `phone_verified` is added to the production schema.

---

## E. OTP Adapter Summary (D-7)

**File:** `release1b_otp_test_adapter.pb.js`

**Deployment:** harness copies to isolated hooks dir automatically; replaces `auth_whatsapp_otp.pb.js` for testing; source project hook is never modified.

**Safety constraints enforced by the adapter:**
- Rejects all non-loopback connections (127.0.0.1 / ::1 only)
- Rejects non-synthetic phone identifiers (pattern: `+601_R20TEST_<4-16 digits>`)
- Never calls Meta, WhatsApp API, or any external service
- Never logs phone numbers or OTP codes
- Rate-limit counter records attempt count only (no phone stored)
- Only `sent/active` records are verifiable by the harness (via NSU read of phone_otps)

**States modelled:** `sent/active`, `send_failed`, `pending_send`

**Routes provided:**
- `POST /api/test/otp-control` — NSU only; set delivery mode; reset counter
- `GET /api/test/otp-rate-count` — NSU only; read attempt count (no phone/OTP values)
- `POST /api/auth/request-whatsapp-otp` — test behavior; writes to phone_otps
- `POST /api/auth/verify-whatsapp-otp` — test behavior; reads phone_otps

---

## F. Checksum Design (D-1)

`release1b_round20_checksums.sha256` is a self-computing zsh script:
- `--compute`: hashes all nine covered artifacts; writes `release1b_round20_checksums.lock`; prints self-integrity values (SHA-256 and bytes of the script itself)
- `--verify`: re-computes; compares against lock file; exits nonzero on any failure

The script's own hash must be recorded by the operator separately (non-recursive design). The lock file is the persisted checksum record; archive it alongside the package.

The verifier halts with exit 1 on: malformed records, placeholder values, missing/extra artifacts, duplicate filenames, hash mismatches, byte-count mismatches.

---

## G. NEEDS-EXTERNAL Items (updated from R19)

| ID | Item |
|---|---|
| NE-1 | PB archive SHA-256: now obtained from GitHub API `digest` field (D-2) |
| NE-2 | `HOOK_SRC_PATHS` (emergency_hardening, push_broadcast, whatsapp) |
| NE-3 | `HOOK_EXPECTED_SHA256` for each hook |
| NE-4 | `HOOK_PROBE_ROUTES[push_broadcast]` |
| NE-5 | `HOOK_PROBE_ROUTES[whatsapp]` |
| NE-6 | `RELEASE1B_SCHEMA_SRC` |
| NE-7 | OTP rate-limit invariants — production hook has no rate limit; operator must define |
| NE-8 | Alias marker decision — T-ALIAS-ENUM results determine if `is_alias_account` is required |
| NE-9 | articles.listRule fix authorization — whether server-side antenatal enforcement is required |
| NE-10 | Binary test asset for T-FILE-AUTH-5/7 (upload/delete) |
| NE-11 | Idempotency endpoint — route, key header, duplicate behaviour |
| NE-12 | S-3 production credential status — operator determines without contacting production |

**Resolved in R20 (previously NEEDS-EXTERNAL):**
- NE-8 (R19): OTP adapter — now delivered ✓
- NE-10 (R19): T-OTP-FLOW adapter — now delivered ✓
- NE-11 (R19): `phone_verified` future state — now tested via temporary schema ✓

---

## H. Stop Condition

Round 20 preparation is complete. Nine artifacts delivered to `release1b_round20/`.

**The following remain prohibited until a runtime PASS result is observed on an isolated v0.29.3 instance:**

- Contacting production
- Modifying any deployed schema, rule, hook, migration, or frontend
- Running the harness in any environment other than an isolated machine per §6 of operator instructions
- Starting any service or database outside the harness's isolated root
- Using or testing the seed credential
- Modifying production credentials
- Deploying or publishing the application
- Modifying repository history
- Proceeding to Checkpoint 1

**Application publication remains unauthorized.**
