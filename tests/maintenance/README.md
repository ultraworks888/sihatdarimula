# Local maintenance acceptance

## Current release verdict

The suite now tests persistent admission and drain against real PocketBase
0.29.3. Only a complete run with `observations.verdict = "PASS"` is acceptance
evidence. Failed/intermediate runs remain preserved. Passing local acceptance
is a candidate for source review, NOT authorization or proof of production readiness.

## Run safely

From the repository root:

```sh
python3 tests/maintenance/run.py --binary work/maintenance/bin/pocketbase
```

The binary must already exist locally. The launcher does not download anything.
Every invocation allocates `work/maintenance/runs/<UTC timestamp>-<UUID>/` using
exclusive directory creation. It never reuses or deletes a prior run. The old
`work/maintenance/acceptance/` directory is not used or modified.

Each run contains its manifest (UTC start, run ID, Git HEAD, runtime version,
local-only mode), copied hooks/migrations, synthetic database, command/runtime
logs, results and provider-call summary. Raw provider payloads and received OTPs
remain in process memory only. Never stage or deploy these runtime artifacts.
Keep `run.py` and this README as intentional test source.

The test-only copied helper redirects provider sends to a loopback stub and
adds deterministic pause/read-failure seams. A copied test-only hook suppresses
email and exposes native-superuser-only fixture controls. None of this
instrumentation is installed in project hooks. A loopback deny proxy provides
an additional safeguard against missed HTTP(S) destinations. Hook file watching
is disabled for the disposable process to avoid copy-event restart races.
Do not rerun `work/maintenance/instrument.cjs` against the project.

## Architecture and policy

- `pb_hooks/maintenance.js` is the explicitly imported CommonJS module.
- `pb_hooks/maintenance.pb.js` registers built-in middleware and request hooks.
- Both files are necessary: `.pb.js` registers callbacks once; the CommonJS
  helper is explicitly imported inside isolated callback runtimes.
- Exactly one `maintenance_mode` setting with exact text `false` permits writes.
  Missing, duplicate, malformed and unreadable state fail closed. There is no cache.
- A short `runInTransaction` acquires SQLite's data.db writer lock with a
  no-op UPDATE of the setting, checks it, then creates an operation record.
  Application work begins only after that registration commits. A native setting
  UPDATE uses the same SQLite writer serialization, so an admission cannot cross
  an acknowledged close. Failed admission does no application work.
- `maintenance_inflight` is a locked base collection: random 15-character
  cryptographic IDs, `kind` (http/builtin/cron/event/mail), and `admitted_at`.
  No bodies, user identifiers, phones, tokens, or secrets are recorded.
  Each complete callback/handler is enclosed in try/finally. Failed release
  leaves the record blocking drain and logs only a fixed generic error.
- No integer counter, TTL, expiry, heartbeat, or generation is needed: count ALL
  unreleased records. A restart cannot discard them. An old timestamp alone
  NEVER permits deletion or a drained claim.
- Bootstrap retains the nontransactional App handle in the shared runtime store.
  This is only an API handle, not coordination state. PB 0.29.3 pooled cron VMs
  can retain a completed transaction's `$app`; cron entry normalizes that handle
  before running existing job code. All drain evidence remains persistent.
- All thirteen mutating custom routes are gated; all five read-only routes stay
  available under their existing authorization. The source inventory is checked
  before runtime startup and retained in the result JSON.
- Application admin/superadmin roles do not bypass maintenance. Native PocketBase
  superuser administration is separate; this is not PWA authentication.
- Authenticated WhatsApp webhook ingestion remains allowed and is not included
  in the claim that prohibited application writes stop.
- Both OTP cleanup jobs, daily push and the broadcast cron pause. Enrollment
  success callbacks suppress outbound messages. The broadcast handler-scope fix
  is validated locally by the full suite while OFF; production remains unverified.
  The gate-only bootstrap profile tests suppression while ON, not dispatch while OFF.
- Ordinary password login and refresh are paused while ON. Password login can
  persist authentication-origin data and send alerts; refresh is conservatively
  paused too. Native superuser login remains available.
- Outer middleware tracks non-read `/api/collections/*` and `/api/batch` handlers
  through `e.next()` completion, including persistence/transaction completion.
  Late request guards do not introduce nested, uncommitted operation records.
  Asynchronous auth-alert/verification/reset mail gets its own tracked lifetime.
- `GET /api/maintenance/status` requires native PocketBase superuser auth,
  returns aggregate state only, and is non-cacheable. One SQL read snapshot
  returns the setting plus the in-flight count. Only valid `true` + zero yields
  `drained=true`; normal `false` + zero is NOT drained.
- Native email-OTP is disabled in the current schema and unused by frontend
  source. PB's failed email-OTP send has asynchronous cleanup outside the mail
  hook lifetime. If an operator enables this unsupported auth configuration,
  status deliberately refuses to certify drain. Extending coverage is required
  before deploying with native email-OTP enabled; no app feature is disabled here.

## Migration reconciliation

The existing filename `1788676088_seed_maintenance_mode_setting_bd01.js` is used.
PocketBase 0.29.3 tracks filenames, not source hashes. Tests cover fresh UP,
repeated UP, an already-recorded filename, DOWN preserving operator state, and
reapplication preserving `true`. This matches the supplied production context;
it does not claim to have inspected the production migration's original bytes.
The three authentication migrations are unchanged.

New `1788845846_create_maintenance_inflight_42a7.js` creates the locked coordination
collection. DOWN deliberately preserves schema AND operation records, because
deletion could manufacture a false zero. UP/reapply are idempotent. Runtime tests
exercise UP, DOWN of the two maintenance migrations, and reapply with an existing
operator `true` setting and a synthetic stale operation, preserving both.

## Transition observations

1. Requests starting while ON are rejected with 503, Retry-After 3600 and
   Cache-Control no-store, without provider calls or relevant record mutations.
2. Pausing after entry but before the next irreversible operation, then activating
   maintenance, prevents OTP creation, verification/password mutation, AI send,
   and configuration mutation via the second check.
3. If OTP delivery has already happened, maintenance cannot undo it. The tested
   request returns maintenance 503 and leaves a pending, unused, inactive OTP;
   verification still fails after reopening. No automatic retry was observed.
4. An additional copied-helper seam pauses after the final state check but before
   the provider call. The provider is quiet when ON is acknowledged; releasing
   that previously admitted request produces one provider call. Neither guard
   was removed. The new persistent record stays visible until that call finishes;
   drain remains false throughout and only becomes true after finally releases it.

## Operator activation and drain verification

Do not execute this against production under the local task's authorization.

1. Through separately authorized native PocketBase administration, set the single
   `lms_settings` row `maintenance_mode` to exact text `true` and confirm it reads
   back as `true`. Do not use an application-role bypass or change collection rules.
2. Verify representative new public mutations return the maintenance 503 and
   expected headers. Keep native management available.
3. Read `/api/maintenance/status` using native superuser authentication. Require
   `state_valid=true`, `maintenance_active=true`, `admission_closed=true`,
   `in_flight_prohibited_operations=0`, AND `drained=true` together in its response.
   Do not add a timeout that converts nonzero/unknown into success.
4. Hold at nonzero/invalid state. Inspect coordination records through native
   management without disclosing other data. Continue only at authoritative zero.
5. Keep provider webhook ingestion explicitly separate from the drained set.
6. Reopen with exact `false` only after separately authorized deployment validation.

There is no certified minimum sleep interval. Completion is a predicate, not an
elapsed duration. Existing admitted work may abort at a later state check or
complete after ON; either way it stays counted until its complete local lifetime ends.

## Crash/stale-operation recovery

Keep maintenance `true`. Do not clear an operation because it looks old, has no
recent logs, or its HTTP client disconnected. A process could still resume.
Identify and prove termination of EVERY possible owning process, including old
workers; if ownership cannot be established, stop all participating workers under
separate authorization and retain management through a controlled replacement.
Reconcile uncertain external provider outcomes separately. Only then may an
explicitly authorized operator remove proven-orphan records, retaining incident
evidence and rechecking aggregate drain. Restart alone does not clear anything.
The crash test kills/reaps only its own disposable PB process and proves the
record survives restart and artificial aging before explicit synthetic recovery.

## Future production rollout order (not performed)

1. Obtain deployment authorization, incident closure, fresh backup approval,
   controlled test users, and reconciliation of the external push process.
2. SiteGround cannot supply the upstream nginx/IP-allowlisted gate. FIRST install
   therefore requires a verified STOP / HOLD / INSTALL / START process boundary,
   not a generic "restart requested" acknowledgement. Take verified Backup A and
   separately preserve existing live hook/frontend/configuration drift. Persist
   exact `maintenance_mode=true` through native administration before stopping.
   Stop external privileged writers separately, prevent automatic respawn, stop
   ALL old PocketBase workers, and prove their exit/listener closure. A temporary
   API outage is expected. Recheck the durable value in the stopped database.
   These production controls remain operator-verification items, not local facts.
3. While the old process is held stopped, install the maintenance setting migration
   `1788676088_seed_maintenance_mode_setting_bd01.js` (if pending), then
   `1788845846_create_maintenance_inflight_42a7.js`. Preserve existing `true`.
   For a gate-only bootstrap use a reviewed, isolated migration payload; do NOT
   run unrestricted `migrate up` on a directory containing pending auth migrations.
   PocketBase keys history by filename; no historical file is renumbered/reworked.
4. Install exactly the gate-only payload documented below, with NO legacy/alternate
   maintenance hook and NO hardened auth hook. Preserve displaced drift outside
   loaded hook directories. Recheck hashes and durable `true`, then start once
   with hook watching disabled. Native access and the aggregate drained predicate
   must pass before any Backup B or auth migration. Representative writes return
   503; the four omitted custom auth routes return expected 404, not a denial shim.
   An incomplete/failing release must stay stopped or closed, never fall back open.
5. Only after gate-only status certifies valid `true`, admission closed, zero
   in-flight, and drained, take and verify Backup B (final pre-auth-migration).
   Keep external privileged writers stopped. Then, under separate authorization
   and a further stop/hold, apply pending auth
   migrations in their original order:
   `1788516108_add_phone_verification_security_7f3a.js`,
   `1788526407_enforce_verified_phone_uniqueness_61b4.js`,
   `1788527376_create_secure_password_reset_otps_c4e9.js`.
   On a new fully excluded installation, normal filename order is those three,
   `1788676088`, then `1788845846`; this is NOT a way to bootstrap a live gate.
6. Activate compatible auth hooks together while closure remains true. Release
   the matching PhoneEntry frontend only after backend validation. The current
   local candidate already contains the hardened auth hooks; first-install packaging
   must prevent these from executing against a pre-auth schema.
7. Ordinary test users do NOT bypass the gate. Without upstream filtering, setting
   `false` also admits public users; a controlled smoke-test reopening is not
   established. Obtain a separate authorization/design decision. Reclose on
   failure and prefer coherent roll-forward. Do not drop coordination schema or
   stale records as rollback. Reopen public traffic only after approved validation.

## Gate-only / pre-auth-schema profile validation

Run the separate bootstrap suite with the already available local binary:

```sh
python3 tests/maintenance/bootstrap.py --binary work/maintenance/bin/pocketbase
```

It creates a new unique run directory, never reuses prior evidence, and does NOT
call the full suite's constructor or instrumentation. The payload hook bytes are
identical to canonical source; there are no test hooks, denial shims, legacy auth
hooks, or alternate maintenance hooks. Native `/api/crons/{id}` invokes the real
two registered gate-profile jobs without modifying their schedules or source.

Exact hook allowlist (all under `pb_hooks/`):

```text
maintenance.js
maintenance.pb.js
ai_chat.pb.js
analytics.pb.js
emergency_users_hardening.pb.js
export.pb.js
lms_whatsapp.pb.js
meta_whatsapp.pb.js
push_broadcast.js
push_broadcast.pb.js
push_reminders.pb.js
whatsapp.pb.js
whatsapp_webhook.pb.js
```

Exact startup migration allowlist (all under `pb_migrations/`):

```text
1788676088_seed_maintenance_mode_setting_bd01.js
1788845846_create_maintenance_inflight_42a7.js
```

`auth_whatsapp_otp.pb.js` and `forgot_password_whatsapp.pb.js` are intentionally
absent until AFTER the three auth migrations. No frontend release accompanies
gate bootstrap. Do not include `work/`, tests, secrets or quarantined migrations
in the deployment payload. The generated `payload-manifest.json` contains only
the 15 allowed relative paths, SHA-256 values and roles; hashes are checked before
and after runtime tests. "Existing guarded hook" is the manifest category for
retained existing hooks, including unchanged read/role/webhook policy hooks.

### Schema construction and lifecycle proof

The test starts a NEW database from the 26 safe repository migrations preceding
`1788516108`, excluding all five quarantined migration prefixes. It never applies
auth migrations and does not reconstruct pre-auth state by deleting their fields.
Synthetic users, a child, due broadcast, notification preferences and a locked
`whatsapp_server_secrets` fixture are created through an initially unhooked local
process. No production data or secret values are imported. A separate source
manifest records the historical migration inputs.

The old process persists exact `true`, then exits and is reaped. OS checks require
the old PID absent and its listener closed. While stopped, the test represents
the supplied already-applied `1788676088` history with a synthetic filename entry
for the existing setting effect, applies only the gate migrations and installs
only the exact payload. The new process must have a distinct PID; `lsof` verifies
that PID owns the loopback listener. It starts once, with `--hooksWatch=false`.

`--automigrate=false` prevents native fixture schema changes from generating extra
migration files. It does NOT disable applying pending migrations on `serve`;
the restricted migration directory is therefore essential. No history sync is run.

Before mutation tests, native-only status must already report valid, maintenance
active, admission closed, zero in-flight, and drained. The suite then checks CRUD,
registration/login/refresh/batch, all nine retained custom mutations, 40 concurrent
blocked requests, four absent auth routes (404), role-independent status denial,
authenticated webhook ingestion, two real background jobs, malformed/missing/
duplicate control and malformed/missing coordination schema. It never sets the
post-bootstrap gate to `false`. Database comparisons exclude only the operator
toggle and coordination/PB metadata; webhook ingestion is explicitly separated.

Pre-auth proofs before and after startup require absent auth migration history,
absent verification fields, absent hardened OTP collections, and absent verified-
phone unique index. HTTP(S) is routed through a loopback deny stub; SMTP uses a
local discard sink. No provider attempt is expected or permitted. Logs are checked
for hook/schema errors and sensitive synthetic fixture matches. This closed-only
profile verifies that the broadcast module is included in the exact payload; the
full suite exercises immediate and scheduled broadcast dispatch while OFF.

This proves the local profile, not production topology. Number of workers,
supervisor/respawn behavior, actual live hook/migration directories, launch command,
ability to hold stopped, external writers and production drift reconciliation
remain Coderick/operator verification items. Never delete persistent in-flight
evidence merely to manufacture a drained result.

## Proof coverage and limits

The suite includes 60 simultaneous HTTP admission attempts plus ten after close,
an SQL-trigger audit of registration/close commit ordering, three concurrent
background jobs, both enrollment callback variants, a two-second provider hold,
built-in persistence hold, failure/early-return cleanup, malformed control,
asynchronous mail, crash/restart, and reopen without restart. All pauses are
explicit local test seams, never production sleeps or bypasses.

Scope is participating hooks/requests using the SAME authoritative SQLite DB.
No claim is made for independent database replicas, old binaries, privileged
external writers, future unguarded routes/jobs, or manually deleted live records.
Native operator writes and authenticated webhook ingestion are deliberate
exceptions; webhook ingestion may still change webhook data during maintenance.
The local gate tracks provider call execution, not a remote provider's queued
delivery after accepting a request. Ambiguous timeout/provider outcomes require
operator reconciliation; this is not a global third-party delivery fence.

## Follow-ups outside this implementation

- `/api/lms/send-reminders` is still unauthenticated while OFF.
- Historical provider-response logging requires a separate review. The local
  fixture scan does not claim to cover every production provider error payload.
- The handler-scope fix was verified in production under maintenance on
  2026-09-10. The newer idempotency, atomic-claim, bounded-retry, cancellation
  race, and strict-segment changes remain locally validated and production-unverified.
- The generated `work/` tree must stay out of source commits/deployment payloads.

## Interpreting results

`results.json` includes the exact assertion list, admission counts, provider
duration samples, restart evidence and final authoritative aggregate state.
The launcher exits nonzero on ANY acceptance failure. Earlier failed/probe runs
remain evidence, not current acceptance. Syntax checks do not substitute for
runtime tests. Never stage/deploy `work/`, including copied test-only routes,
synthetic databases, logs, downloaded runtime/source, and failed evidence.
