# AGENTS.md — Sihat Dari Mula / My Healthy Start

> Repository operating rules for AI coding agents and human-assisted development.
>
> **Project:** My Healthy Start / Sihat Dari Mula
> **Production origin:** `https://app.sihatdarimula.my`
> **Aligned to observed SiteGround/Coderick project structure:** 2026-08-29
>
> This file is intentionally conservative. If the live repository differs from any path or behavior documented here, inspect the repository and report the discrepancy before changing code. Repository evidence wins over stale documentation, but the security, scope, and release constraints below remain mandatory unless explicitly changed by the project owner.

---

## 1. Mission

This is a production PWA. Changes must be:

- small;
- reviewable;
- testable;
- reversible;
- security-preserving;
- scoped to the requested task.

Before any substantial change:

1. Read this file completely.
2. Inspect the current project tree.
3. Run `git status` and `git branch --show-current` if Git is available in the environment.
4. Inspect the relevant implementation before proposing edits.
5. Identify affected files, data flows, security implications, migrations, and tests.
6. Propose the smallest coherent change.
7. Implement only the approved/requested scope.
8. Run relevant validation.
9. Inspect the resulting diff.
10. Report exactly what changed, what ran, what passed, what failed, and what was not tested.

Never claim that a test, build, migration, deployment, or verification succeeded unless it actually ran and produced evidence.

---

## 2. Observed SiteGround/Coderick project layout

The following top-level structure has been observed in the SiteGround Coderick project:

```text
PROJECT ROOT/
├── AGENTS.md
├── cloudflare-worker/
├── codebase/
├── pb_data/
├── pb_hooks/
├── push-server/
├── release1b_round14/
├── release1b_round15/
├── release1b_round16/
├── release1b_round17/
├── release1b_round18/
├── release1b_round19/
├── release1b_round20/
├── release1b_round21/
├── release1b_round22/
├── release1b_round23/
├── release1b_round24/
├── .gitignore
├── release1b_cp0_manifest.json
├── release1b_cp0.zsh
├── release1b_hook_manifest.json
├── release1b_schema_manifest.json
├── release1b_static_validation_auth_request.md
├── release1b_test_manifest.json
└── ...
```

Do not assume an unlisted directory does not exist. Inspect the current tree before relying on this map.

### Directory intent

#### `codebase/`
Treat as the primary application source area unless repository inspection proves otherwise.

Before editing:
- inspect its `package.json`, build scripts, source folders, router, service worker/PWA setup, and API client;
- identify whether frontend, backend-support code, or build artifacts are present;
- do not assume a specific framework substructure without inspection.

#### `pb_hooks/`
PocketBase runtime hooks and backend logic.

This is security-sensitive and production-critical.

#### `pb_data/`
PocketBase runtime/database data.

**Do not edit, delete, rename, normalize, migrate, copy, or regenerate anything in `pb_data/` unless the project owner explicitly authorizes that exact operation.**

Treat this directory as live/stateful data rather than ordinary source code.

Never use `pb_data/` as a convenient test fixture.

#### `push-server/`
Push-notification subsystem.

Inspect before modifying. Do not assume the known deferred `push_broadcast_scheduler` defect is the only issue in this area.

#### `cloudflare-worker/`
WhatsApp/Meta security gateway area.

A more-specific `cloudflare-worker/AGENTS.md` governs edits inside this subtree. Read both this root file and the nested Worker file before changing Worker code.

#### `release1b_round14/` through `release1b_round24/`
Treat these as historical/release/audit artifacts, not ordinary application source.

Rules:
- do not bulk-format them;
- do not rename them;
- do not delete or consolidate them;
- do not "clean up" duplicate-looking artifacts;
- do not update historical round content during unrelated work;
- if a new release round is explicitly requested, follow the existing repository pattern rather than rewriting old rounds.

#### Root Release 1B files
Files such as:

```text
release1b_cp0.zsh
release1b_cp0_manifest.json
release1b_hook_manifest.json
release1b_schema_manifest.json
release1b_test_manifest.json
release1b_static_validation_auth_request.md
```

are release-control / validation artifacts.

Do not alter them casually. If a release task requires changes, inspect the harness and manifests together and preserve their acceptance semantics.

---

## 3. Source-of-truth hierarchy

When there is a conflict, use this order:

1. explicit current instruction from the project owner;
2. current repository evidence;
3. current migration/schema/runtime configuration;
4. this `AGENTS.md`;
5. historical notes or prior round artifacts.

Do not guess when two sources conflict.

For consequential ambiguity:
- stop;
- describe the conflict;
- preserve security and data integrity;
- request clarification.

---

## 4. Frontend / PWA boundary

The application is a mobile-first PWA for My Healthy Start / Sihat Dari Mula.

Production origin:

```text
https://app.sihatdarimula.my
```

Known routing contract:

```text
/api/*  -> PocketBase
all other routes -> PWA/frontend
```

Do not alter reverse-proxy behavior as a side effect of unrelated work.

Frontend requirements:
- mobile-first layout;
- accessible tap targets;
- simple language;
- explicit validation;
- clear loading and error states;
- resilient browser back/refresh behavior;
- preserve PWA installability/offline behavior unless explicitly changing it;
- avoid unnecessary dependencies;
- avoid framework or state-management rewrites for small changes.

For registration and OTP screens, pay special attention to:
- mobile input modes;
- Malaysian phone formatting;
- duplicate submissions;
- loading states;
- resend cooldown;
- OTP expiry;
- refresh/back navigation;
- intermittent connectivity;
- route transition to `/verified`.

---

## 5. PocketBase security rules

### General hook rule

Before editing anything under `pb_hooks/`:

1. inspect all related hooks;
2. identify collections/routes touched;
3. identify auth/authorization impact;
4. identify interactions with existing data;
5. identify rollback/recovery implications;
6. check release harness coverage.

Do not weaken security controls to make a test pass.

### Role hardening invariant

A security hook has existed at:

```text
pb_hooks/emergency_users_hardening.pb.js
```

Required invariant:

> Only a `superadmin` token may modify the `role` field on a user record.

Required behavior:
- non-superadmin role writes are rejected;
- ordinary non-role updates still work;
- a request containing a forbidden `role` write plus otherwise-valid fields is rejected atomically;
- no partial update survives the rejection;
- privileged cross-user role changes remain limited to authorized superadmin behavior.

Previously validated regression expectations included:
- admin self-escalation blocked;
- superadmin cross-user role update allowed;
- ordinary self-update unaffected;
- avatar + phone write/restore unaffected;
- mixed role + ordinary fields rejected atomically.

Treat those as regression expectations, not proof that the current tree still passes.

---

## 6. PocketBase version and migrations

The project has previously been operated on PocketBase `v0.29.3`.

Do **not** assume that is the current runtime version.

Before using version-specific behavior:
- inspect the installed/runtime version;
- inspect current hooks and migrations;
- confirm `$security`, hook APIs, migration APIs, and event semantics against the actual version.

If a `pb_migrations/` directory exists now or is introduced later:
- schema changes must use migrations rather than ad-hoc live edits;
- do not delete or rewrite applied historical migrations;
- migrations should be deterministic;
- migrations should be reversible where practical;
- destructive changes require explicit owner approval.

If no migration directory exists, report that fact rather than inventing one.

---

## 7. Registration and identity requirements

Registration is intended for Malaysian users only.

Canonical phone format:

```text
+60...
```

Requirements:
- fixed `+60` prefix;
- no country selector unless explicitly requested;
- normalize and validate phone numbers at the backend boundary;
- do not rely only on frontend formatting.

Intended onboarding flow:

1. User enters name.
2. User enters Malaysian mobile number.
3. User gives consent to receive a WhatsApp verification code.
4. WhatsApp OTP is sent.
5. User enters OTP.
6. Backend verifies OTP.
7. User accepts required Privacy Policy / Terms consent.
8. Email is optional/fallback rather than the primary identity gate.
9. Successful verification routes to `/verified`.
10. The verified page leads into the antenatal journey.

Do not silently revert to an email-first registration flow.

### Consent separation

Keep these distinct:
- pre-OTP WhatsApp verification-message consent;
- post-OTP Privacy Policy / Terms acceptance.

Do not merge, pre-check, or bypass required consent.

### OTP safety

Never:
- log OTP values;
- expose OTPs unnecessarily;
- store OTPs in insecure plaintext locations;
- weaken expiry or verification rules without explicit security review;
- accept OTP verification purely from frontend state.

---

## 8. Historical legacy-phone risk

A prior audit reported:

```text
users total:                5
empty phone:                3
valid canonical phone:      2
normalizable phone:         0
invalid phone:              0
duplicate phone groups:     0
empty-phone users with child records: 0
child records belonging to them:      0
```

This is historical, not a current database query.

Release rules:
- new phone-required flows must handle legacy users with no phone;
- do not assume all users have canonical phones;
- re-audit before enforcing non-null/unique constraints or destructive normalization;
- never modify production user records merely to make tests pass.

---

## 9. Antenatal course and child-profile gate

Current product requirement:

> Child-profile details remain locked until the required antenatal course/video requirements are completed.

Rules:
- frontend hiding alone is not authorization;
- enforce protected data/action access at the backend boundary where applicable;
- do not bypass the gate for demos or convenience;
- inspect current progress/completion models before changing semantics.

Known historical state:
- `Antenatal Care Essentials` was unpublished;
- `Newborn Care Essentials` was unpublished;
- both had YouTube placeholders;
- `lesson_progress` was `0` at a recorded snapshot.

Re-check current state before release decisions.

---

## 10. WhatsApp security boundary

The WhatsApp integration trust chain is:

```text
Meta -> Cloudflare Worker -> PocketBase webhook
```

Known PocketBase webhook target:

```text
/api/whatsapp/webhook
```

PocketBase must not trust arbitrary internet callers as though they passed the Worker verification layer.

Known secret names only:

```text
META_APP_SECRET
WA_WEBHOOK_VERIFY_TOKEN
WA_INTERNAL_FORWARD_SECRET
```

Never print, commit, expose, infer, duplicate, or echo secret values.

All code inside `cloudflare-worker/` is also governed by the nested Worker `AGENTS.md`.

---

## 11. Known deferred defect — Push Broadcast

A known deferred defect exists in the push-broadcast subsystem.

Historical behavior:
- `push_broadcast_scheduler` cron is broken by handler-scope isolation;
- an error has historically occurred every five minutes;
- immediate broadcast behavior is believed likely affected/broken but has not been conclusively tested;
- creation/cancellation of future scheduled records was believed unaffected, but this is not current proof.

Historical idempotency work has included or contemplated:
- UUID support;
- `$security` generation under PocketBase `v0.29.3`;
- partial uniqueness index;
- HTTP `202`.

Known unresolved area:

> request-level idempotency is not fully resolved.

Agent rule:
- do not opportunistically fix this during unrelated tasks;
- report it as a known deferred defect;
- distinguish current evidence from historical notes;
- do not suppress the cron error merely to make logs appear clean;
- do not alter scheduler behavior without a dedicated task and acceptance criteria.

---

## 12. Hard safety boundaries

Unless explicitly authorized for that exact action, do not:

- deploy to production;
- push to remote Git branches;
- create/merge pull requests;
- commit automatically;
- force-push;
- rewrite Git history;
- run `git reset --hard`;
- delete branches;
- edit production server files over SSH;
- mutate production PocketBase records;
- modify `pb_data/`;
- run destructive database operations;
- delete historical release artifacts;
- delete/rewrite applied migrations;
- expose `.env` contents or secret values;
- weaken authentication, authorization, role protections, OTP verification, webhook verification, or course-access controls;
- bypass or disable failing tests merely to obtain a green result.

Passing tests does not authorize deployment.

---

## 13. Scope discipline

Do not fix unrelated issues during a targeted task.

If unrelated problems are discovered, report them under:

```text
Out-of-scope Findings
```

Do not modify them unless:
- they directly block the requested task; or
- the project owner explicitly approves the added scope.

Prefer the smallest safe change that satisfies acceptance criteria.

Avoid broad refactors during bug fixes.

---

## 14. ChatGPT / Codex / Coderick coexistence

Multiple AI coding tools may be used.

Core rule:

> **One active writer per worktree.**

Do not let Codex and Coderick modify the same checkout concurrently.

### Before handing work to an agent

If Git is available:

```bash
git status
git branch --show-current
```

Confirm:
- current branch;
- existing uncommitted changes;
- which agent owns the current work;
- intended scope.

### Before switching agents

1. stop the current agent;
2. inspect `git status`;
3. inspect the diff;
4. accept/commit/stash/discard intentionally;
5. confirm the next agent will not overwrite active work.

### Coderick simple-change rule

For a simple modification, use a narrow prompt such as:

```text
Read AGENTS.md if your environment supports it.

Make only this requested change:
<change>

Do not refactor unrelated code.
Do not alter PocketBase schema, auth rules, deployment config, pb_data, release artifacts, or the WhatsApp Worker.
Run the smallest relevant validation.
Show the resulting diff.
Do not commit, push, or deploy.
```

### Codex substantial-change rule

For substantial work:

```text
Read AGENTS.md first.
Inspect the current implementation before editing.
Report current behavior, affected files, risks, and the smallest safe plan.
Do not modify files yet.
Stop for approval.
```

After approval:

```text
Implement only the approved plan.
Keep the diff narrow.
Run all relevant validation.
Do not commit, push, deploy, or modify production data.
Finish with the AGENTS.md completion report.
```

---

## 15. Git rules

If Git is available, run before substantial work:

```bash
git status
git branch --show-current
```

After modifications:

```bash
git diff --check
git diff
```

Do not automatically:
- commit;
- push;
- merge;
- rebase;
- force-push;
- reset hard;
- delete branches.

If this SiteGround/Coderick environment is not a Git checkout, say so explicitly and use the platform's change/diff/history facilities where available.

---

## 16. Release 1B artifact rules

The Release 1B rounds and root manifests/harnesses represent release-control history.

Do not treat `release1b_round14/` ... `release1b_round24/` as disposable scratch directories.

When a Release 1B task is requested:
1. identify the current intended round;
2. inspect the previous round for format/contract;
3. do not rewrite earlier rounds;
4. preserve manifest/harness relationships;
5. validate checksums according to the actual repository tooling;
6. distinguish static acceptance from runtime acceptance;
7. do not claim production publication unless explicitly authorized and actually performed.

Known harness:

```text
release1b_cp0.zsh
```

When relevant:
- run `zsh -n release1b_cp0.zsh`;
- execute it only according to its documented usage;
- inspect failures rather than weakening checks.

Do not invent acceptance commands that the repository does not provide.

---

## 17. Release acceptance gates

A gate may be marked **NOT APPLICABLE** only with an explanation.

### Gate A — repository/project state
- project tree inspected;
- current branch recorded if Git exists;
- pre-existing edits identified;
- no unexplained edits overwritten.

### Gate B — static/syntax checks
Run relevant checks actually provided by the project, such as:

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

only if they exist.

For shell scripts:

```bash
zsh -n <script>
```

For Release 1B work, use the actual harness/manifest tooling present in the project.

### Gate C — role/auth regression
For changes touching users/auth/profile/phone/roles:
- unauthorized role escalation rejected;
- authorized superadmin role change works;
- ordinary self-update works;
- forbidden mixed-field role request rejected atomically;
- ordinary phone/avatar/profile writes do not regress.

### Gate D — registration/OTP
For registration changes validate:
- Malaysia phone normalization;
- invalid phone rejection;
- duplicate/legacy phone behavior;
- pre-OTP WhatsApp consent;
- OTP send;
- valid OTP verification;
- invalid OTP;
- expired OTP;
- resend/cooldown behavior;
- duplicate submission/race behavior;
- post-OTP consent;
- `/verified` routing;
- refresh/back recovery;
- no OTP/secret leakage in logs.

### Gate E — course gate
For child-profile/course changes:
- incomplete requirement remains blocked;
- completed requirement works;
- direct API access cannot bypass protection;
- frontend route manipulation cannot bypass backend authorization.

### Gate F — Worker boundary
For Worker changes, use the nested `cloudflare-worker/AGENTS.md`.

### Gate G — build/runtime smoke
Before calling a release candidate ready:
- production build succeeds;
- affected routes load;
- auth/session behavior works where affected;
- affected API behavior is verified;
- relevant console/server logs show no new errors.

### Gate H — secrets/diff review
Inspect for:
- secrets;
- OTP leakage;
- debug logging;
- temporary test routes;
- commented-out security checks;
- unrelated formatting churn;
- accidental generated/binary artifacts;
- unintended dependency changes.

### Gate I — deferred defect separation
The push-broadcast defect must remain explicitly separated unless a dedicated task proves it fixed.

### Gate J — deployment approval
Deployment requires explicit owner approval even after all tests pass.

---

## 18. Severity classification

### P0 — stop immediately
Examples:
- secret exposure;
- auth bypass;
- unauthorized privilege escalation;
- destructive data loss;
- production-wide outage risk;
- webhook signature verification removed/bypassed.

### P1 — release blocker
Examples:
- registration cannot complete;
- OTP materially broken;
- child-profile authorization bypass;
- migration could strand/corrupt users;
- build failure;
- required acceptance test failure.

### P2 — important but potentially deferrable
Examples:
- non-critical UX defect;
- degraded error messaging;
- accepted known scheduler defect;
- missing non-critical coverage.

Do not downgrade security/data-integrity issues merely because a workaround exists.

---

## 19. Required completion report

Every substantial task must end with:

```markdown
## Changed
- `<file>` — what changed and why

## Validation
- `<command/check>` — PASS / FAIL
- `<command/check>` — PASS / FAIL

## Not Tested
- anything not actually verified

## Security / Data Impact
- auth, roles, personal data, migrations, secrets, or "None identified"

## Out-of-scope Findings
- unrelated issues discovered, if any

## Risks / Follow-up
- remaining risks or next steps

## Diff Summary
- files changed
- insertions/deletions if available
- `git diff --check` result if Git exists

## Deployment
- NOT DEPLOYED unless explicitly requested and approved
```

If a command could not run, say **NOT RUN** and explain why.

---

## 20. Final rule

Optimize for:

**correctness > security > reviewability > recoverability > speed > autonomy**

A good change should be easy for another engineer or AI agent to understand, verify, and undo.
