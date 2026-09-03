# Release 1B — Round 19 Review
# Checkpoint 0 Authorization Status: AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

---

## A. Authoritative R19 Package Checksums

These values are computed by the tool environment from the files as written.
The operator must independently verify them using `shasum -a 256` and `wc -c`
before running the harness. This file is NOT listed in its own hash entries
(non-recursive by design).

```
# Computation commands (run from release1b_round19/ directory):
#   shasum -a 256 <filename>
#   wc -c < <filename>
```

Operator fills these values after download:

| Filename | SHA-256 | Bytes |
|---|---|---|
| `release1b_cp0.zsh` | OPERATOR-COMPUTES | OPERATOR-COMPUTES |
| `release1b_cp0_manifest.json` | OPERATOR-COMPUTES | OPERATOR-COMPUTES |
| `release1b_schema_manifest.json` | OPERATOR-COMPUTES | OPERATOR-COMPUTES |
| `release1b_hook_manifest.json` | OPERATOR-COMPUTES | OPERATOR-COMPUTES |
| `release1b_test_manifest.json` | OPERATOR-COMPUTES | OPERATOR-COMPUTES |
| `release1b_operator_instructions.md` | OPERATOR-COMPUTES | OPERATOR-COMPUTES |
| `release1b_round19_review.md` | OPERATOR-COMPUTES | OPERATOR-COMPUTES |

---

## B. Checkpoint 0 Status

**Authorization status:** AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE

Checkpoint 0 was authorized by the project operator. Execution was not possible
in the Coderick AI tool environment because that environment provides no shell
execution capability, no child process management, no external network download,
and no ability to start an isolated PocketBase instance.

No runtime results were observed. No `PASS`, `FAIL`, or `INCOMPLETE` result was
recorded from a harness run. This document and the associated R19 package
constitute a corrected preparation artifact only.

**What was NOT done:**
- No PocketBase v0.29.3 binary was downloaded or executed.
- No isolated test database was created.
- No HTTP request was sent to any server, including production.
- No harness was run.
- No runtime schema behavior was observed.

**What WAS done (authorized read-only static analysis):**
- `pb_get_schema` tool was called to inspect the Coderick-managed workspace PocketBase.
- All files in `pb_migrations/` were read via `read_file`.
- All files in `pb_hooks/` were inspected (filenames listed; key files read in full).
- The R18 harness, manifests, and review were read and corrected.
- Twelve specific corrections were applied (see §C).

---

## C. Inspection Provenance

**Source:** `pb_get_schema` tool in the Coderick AI environment.

**Instance inspected:** Coderick-managed workspace PocketBase, version 0.28.4.
This is the backend instance for the React/PocketBase project in the Coderick
workspace. It is a Coderick-managed service, not the production instance.

**How the schema was populated:** The Coderick-managed PocketBase applied the
migration files found in `pb_migrations/` in filename order. The schema
reflects the cumulative effect of those migrations.

**Relationship to production:**
- The same migration files, applied in the same order to a clean PocketBase
  v0.29.3 instance, should produce the same schema structure.
- Whether PocketBase v0.28.4 and v0.29.3 apply every migration construct
  identically is NOT established. No v0.29.3 runtime result was observed.
- Production runs at `app.sihatdarimula.my`. No request was sent to that host.
- Findings from this inspection are schema-level predictions, not observed
  v0.29.3 runtime behavior.

**Terminology correction applied in R19:**
R18 referred to this schema as "live" and "actual" without qualification.
R19 removes those unqualified claims throughout all documents. The schema is
described as "inspected from the Coderick workspace" or "sourced from migration
files." The word "production" is reserved for `app.sihatdarimula.my`.

---

## D. Correction Matrix

All twelve corrections from the operator instructions are listed here with
source, evidence, and harness impact.

| ID | R18 Issue | Source of Error | Evidence | R19 Correction | Harness Impact |
|---|---|---|---|---|---|
| C-1 | Status stated as "not authorized" | Mischaracterisation | Operator authorization was given | Header updated to "AUTHORIZED BUT NOT EXECUTED — EXECUTION ENVIRONMENT UNAVAILABLE" | All documents |
| C-2 | Schema described as "live" and "actual" without provenance | Missing context | pb_get_schema inspects Coderick workspace v0.28.4, not production | Provenance section added to all manifests | All documents |
| C-3 | HOOK_SRC_PATHS included `onboarding` and `alias_intercept` | Speculative | No `onboarding.pb.js` or `alias_intercept.pb.js` found in `pb_hooks/` | Keys removed; `emergency_hardening` and `auth_whatsapp_otp` added | §3, §10, §38 |
| C-4 | HOOK_OTP_PHONE_ROUTE marked UNRESOLVED | Not inspected | auth_whatsapp_otp.pb.js line 21: routerAdd("POST", "/api/auth/request-whatsapp-otp") | HOOK_OTP_PHONE_ROUTE = /api/auth/request-whatsapp-otp | §3, §31, §37 |
| C-5 | HOOK_OTP_MOCK_CONTROL_ROUTE undefined | Awaiting design | Designed in R19: local adapter only | HOOK_OTP_MOCK_CONTROL_ROUTE = /api/test/otp-control (local adapter, not production) | §3, hook manifest |
| C-6 | Collection names speculative: growth_records, activities, immunizations, progress_notes, newborn_enrollments | Never verified | Migration 1782833823 defines growth_logs, nutrition_logs, activity_logs, wellbeing_logs, immunisations, enrollments; progress_notes and newborn_enrollments absent | Names corrected throughout; absent collections removed | §14, §23, §25, test manifest |
| C-7 | children.parent used throughout | Field name error | Migration 1782833823: children.user (relation to users, required, cascadeDelete) | children.parent → children.user in all test bodies | §20, §23 |
| C-8 | articles.type with values antenatal/postnatal/general assumed | Speculative | Migration 1782833823: articles.category with growth/nutrition/activity/wellbeing/immunisation/pregnancy/general; articles.is_pregnancy bool | Corrected in schema manifest and test functions | §14, §30 |
| C-9 | Legacy fixture sent phone_verified, has_newborn_content, children.parent= | Fields absent/renamed | S-2: phone_verified absent. children schema has no has_newborn_content. children relation field is user. | Legacy fixture corrected; absent fields removed | §20 |
| C-10 | Alias fixture sent is_alias_account; timing-legacy sent phone_verified | Fields absent | S-2: both fields absent from users schema | Fields removed from fixture creation bodies | §21 |
| C-11 | T-FIELD-ROLE-REJECT expected HTTP 400 | Wrong status | emergency_users_hardening.pb.js throws new ForbiddenError() → 403 | Expected status changed to 403; persisted-record verification added | §24 |
| C-12/C-13 | T-FIELD-PHONE-REJECT, T-FIELD-ALIAS-REJECT as runnable tests | Fields absent | phone_verified and is_alias_account not in users schema | Reclassified DEFERRED-MANDATORY | §24, test manifest |

---

## E. Security Findings

### S-1 — HIGH: Role Injection on Create (users.createRule = "")
**Source:** Migration `1782897956_add_admin_roles_and_permissions_8689.js`

**Finding (static):**
`users.createRule = ""` (empty string = public). Any caller, including
anonymous callers, may POST to `/api/collections/users/records`. The
`emergency_users_hardening.pb.js` hook intercepts `onRecordUpdateRequest`
(PATCH/PUT) only. No hook intercepts `onRecordCreateRequest` (POST).

If a registration body includes `role=admin` or `role=superadmin`, PocketBase
may store that value, because:
- The createRule does not restrict which fields may be set.
- No hook blocks privileged field injection on create.
- The select field definition allows those values.

**Status:** UNVERIFIED PREDICTION — requires T-INJECT-CREATE-ANON-ADMIN on
an isolated v0.29.3 instance. NOT classified as an observed failure.

**Emergency blocking test:** T-INJECT-CREATE-ANON-ADMIN (§28.5).

**Emergency hardening proposal (create path):**

Option A — createRule restriction (no code deployment required):
```
users.createRule = "@request.body.role:isset = false"
```
This prevents registration bodies from containing a `role` field at all.
Side-effect: native superuser cannot set role on create; must PATCH afterward.

Option B — Hook guard (more flexible):
Add an `onRecordCreateRequest` handler in `emergency_users_hardening.pb.js`
that mirrors the existing update guard:
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

**Authorization required before deployment:** This proposal must NOT be
implemented in production without separate authorization. Do not combine
its deployment with the phone-first rollout authorization.

---

### S-2 — MEDIUM: phone_verified and is_alias_account Absent from Schema
**Source:** All migration files inspected; `pb_get_schema` output.

**Finding:** Fields `phone_verified` and `is_alias_account` are not defined
in any migration. Tests that depend on them (T-FIELD-PHONE-REJECT,
T-FIELD-ALIAS-REJECT) cannot run. Operator must clarify: are these fields
planned, deferred, or never intended for this release?

---

### S-3 — CRITICAL: Hardcoded Plaintext Credential in Committed Migration
**Source:** `pb_migrations/1782898775_seed_superadmin_user_4fd7.js`

**Finding:** This migration sets a seeded application superadmin account with:
- Email: `sdmadmin@ultra.works` (appears to be a real domain)
- Password: visible in plain text in the migration file

Anyone with access to the project repository can read this credential.

**If this migration was applied to the production database and the password
was never rotated, the credential is fully exposed.**

**Operator action required:**
1. Confirm whether this migration was applied to production.
2. If applied: rotate the password immediately via the PocketBase admin panel.
3. If the email is a real address in use, treat the credential as compromised
   and notify the owner.
4. Consider whether the plaintext password should be removed from version
   control history (git filter-branch / BFG Repo Cleaner).

**Harness impact:** The harness never reads or uses this credential. The
isolated test database will have this user but it is isolated and destroyed on
cleanup. The harness creates all test credentials via `openssl rand`.

---

## F. Findings vs. Predictions

The following are **static findings** (observed from migration files or schema):

1. `users.createRule = ""` — source: migration 1782897956
2. `emergency_users_hardening.pb.js` hooks `onRecordUpdateRequest` only
3. `phone_verified` and `is_alias_account` fields absent from users schema
4. No `HOOK_OTP_MOCK_CONTROL_ROUTE` exists in production hooks
5. `articles.listRule = ""` (public) — source: migration 1782833823 + 1782897956
6. `children` relation field is `user` not `parent` — source: migration 1782833823
7. Collection `growth_logs` not `growth_records` — source: migration 1782833823
8. Collection `activity_logs` not `activities` — source: migration 1782833823
9. Collection `immunisations` (British spelling) — source: migration 1782833823
10. Collections `progress_notes` and `newborn_enrollments` do not exist
11. Seed migration contains plaintext credential — source: migration 1782898775
12. `auth_whatsapp_otp.pb.js` route: `/api/auth/request-whatsapp-otp`

The following remain **unverified predictions** (require runtime testing):

1. Whether a registration POST with `role=admin` persists that value in v0.29.3
2. Whether unknown fields (`phone_verified`, `is_alias_account`) are silently ignored or rejected on create
3. Whether PocketBase v0.29.3 JSVM bindings differ from v0.28.4 for hook functions
4. The HTTP response code for any harness test assertion
5. Whether the Coderick workspace schema exactly matches what v0.29.3 would produce from the same migrations
6. Whether `authRule` is set on the users collection
7. Whether the seeded credential was applied to production

---

## G. Remaining NEEDS-EXTERNAL Items

| ID | Item | What is Required |
|---|---|---|
| NE-1 | PB_EXPECTED_SHA256 | Authoritative checksum for pocketbase_0.29.3_PLATFORM.zip. Check release page. If none published, leave UNRESOLVED and note. |
| NE-2 | HOOK_SRC_PATHS (all 4) | Absolute paths to emergency_users_hardening.pb.js, auth_whatsapp_otp.pb.js, push_broadcast.pb.js, whatsapp.pb.js on the operator's machine |
| NE-3 | HOOK_EXPECTED_SHA256 (all 4) | `shasum -a 256` output for each hook file |
| NE-4 | HOOK_PROBE_ROUTES[emergency_hardening] | The health/probe endpoint for emergency_hardening (or designate N/A) |
| NE-5 | HOOK_PROBE_ROUTES[push_broadcast] | The registered route for push_broadcast probe |
| NE-6 | HOOK_PROBE_ROUTES[whatsapp] | The registered route for whatsapp probe |
| NE-7 | RELEASE1B_SCHEMA_SRC | Absolute path to `pb_migrations/` directory |
| NE-8 | OTP test adapter | `release1b_otp_test_adapter.pb.js` — not yet written. Required for T-OTP-FLOW and T-CONCURRENCY-OTP-SEND. |
| NE-9 | OTP rate-limit invariants | Production hook has no rate limit. Operator must define expected behaviour before T-CONCURRENCY-OTP-SEND can be scored. |
| NE-10 | articles antenatal policy | Whether `listRule=""` is the intended release policy. Required before T-ART-ANON-POLICY can be scored. |
| NE-11 | phone_verified field | Whether this field is planned for this release. Required before T-FIELD-PHONE-REJECT can be scheduled. |
| NE-12 | is_alias_account field | Whether alias accounts are planned for this release. Required before T-FIELD-ALIAS-REJECT can be scheduled. |
| NE-13 | Idempotency endpoint | Route, key header, and expected duplicate behaviour. Required for T-CONCURRENCY-IDEMPOTENCY-POST. |
| NE-14 | Binary test asset | A valid image file for T-FILE-AUTH-5 (avatar upload) and T-FILE-AUTH-7. |
| NE-15 | S-3 production credential status | Whether seed migration was applied to production and whether password was rotated. Operator action required. |

---

## H. Antenatal-Only Requirements Assessment

The release policy requires that only antenatal/pregnancy content is accessible
during the onboarding phase. The following observations apply:

**Schema-level observation (static):**
- `articles.is_pregnancy` (bool) gates pregnancy content
- `articles.category = 'pregnancy'` identifies pregnancy articles
- Categories `growth`, `nutrition`, `activity`, `wellbeing`, `immunisation`
  are postnatal-oriented
- `articles.listRule = ""` — ALL articles are publicly readable regardless of category
- There is NO server-side rule restricting postnatal-category articles to
  post-pregnancy-completion users
- `courses.category = 'pregnancy'` identifies pregnancy courses (accessible when is_published=true)

**Gap:** The current schema does not enforce antenatal-only access at the
database rule level. The antenatal gate in `is_pregnancy` and `category` fields
is meaningful for client-side filtering only. A determined API caller can
access non-pregnancy articles regardless of their onboarding status.

**Tests that can run:**
- T-ART-ANTENATAL-VIS: pregnancy articles visible to authenticated users ✓
- T-ART-CATEGORY-FILTER: category=pregnancy filter works ✓

**Tests requiring policy decision:**
- T-ART-ANON-POLICY: operator must confirm whether public article access is intended
- Server-side antenatal enforcement: requires a rule change if enforcement is needed

**Recommendation (not an authorization):**
If server-side antenatal-only enforcement is required, consider:
```
articles.listRule = "is_pregnancy = true || @request.auth.id != ''"
```
This allows anonymous access to pregnancy content only; authenticated users
see all content. Post-antenatal filtering would be handled by the frontend.

---

## I. PocketBase v0.29.3 Operator Setup Summary

See `release1b_operator_instructions.md` for the full procedure.

Key points:
1. Download from `https://github.com/pocketbase/pocketbase/releases/tag/v0.29.3`
2. Record archive SHA-256 (`shasum -a 256 <archive>`) regardless of whether
   an authoritative checksum is published
3. Verify binary reports `v0.29.3` exactly
4. Do not contact production at any step
5. Set all NEEDS-EXTERNAL constants before `--run`
6. Deploy local OTP test adapter before T-OTP-FLOW and T-CONCURRENCY-OTP-SEND
7. After run: retain sanitized report; clean up isolated root

---

## J. R18 → R19 Artifact Cross-Reference

| Artifact | R18 Location | R19 Location | Status |
|---|---|---|---|
| Harness | `release1b_round18/release1b_cp0.zsh` | `release1b_round19/release1b_cp0.zsh` | Corrected (12 corrections) |
| CP0 Manifest | `release1b_round18/release1b_cp0_manifest.json` | `release1b_round19/release1b_cp0_manifest.json` | Corrected |
| Schema Manifest | `release1b_round18/release1b_schema_manifest.json` | `release1b_round19/release1b_schema_manifest.json` | Fully rewritten |
| Hook Manifest | `release1b_round18/release1b_hook_manifest.json` | `release1b_round19/release1b_hook_manifest.json` | Corrected |
| Test Manifest | `release1b_round18/release1b_test_manifest.json` | `release1b_round19/release1b_test_manifest.json` | Corrected |
| Operator Instructions | (absent) | `release1b_round19/release1b_operator_instructions.md` | NEW in R19 |
| Review | `release1b_round18/release1b_round18_review.md` | `release1b_round19/release1b_round19_review.md` | Corrected |
| Checksums | `release1b_round18/release1b_round18_checksums.sha256` | `release1b_round19/release1b_round19_checksums.sha256` | Operator completes |

---

## K. Stop Condition

Round 19 preparation is complete. This document and the seven accompanying
files constitute the corrected operator-run package.

The following remain prohibited until a runtime PASS result is observed:

- Contacting production
- Modifying any deployed schema, rule, hook, migration, or frontend
- Starting a service or database outside the isolated harness root
- Running the harness (must be done by the human operator, not this tool)
- Deploying or publishing the application
- Sending WhatsApp messages, emails, or push notifications
- Proceeding to Checkpoint 1

**Application publication remains unauthorized.**
