# Release 1B — Checkpoint 0 Plan, Round 13

**Preparation statement:** No commands were executed. No services were started. No syntax check was performed. No production contact occurred. No files were modified except these six plan artifacts written to the workspace. All content is draft documentation revision only.

**Status of this package:** *Draft for static review only. Checkpoint 0 cannot be authorized until B-CHECKSUM, B-SCHEMA, B-HOOKS, and B-FRONTEND are resolved and the resulting final package is re-hashed.*

**Delivery constraint:** Files are written to the Coderick workspace. They cannot be delivered as download attachments from this interface. SHA-256 hash computation requires executing `shasum`, which is prohibited under the current no-command authorization. The manifest therefore carries `NOT_COMPUTABLE_UNDER_NO_COMMAND_RESTRICTION` for the six Round 13 artifacts. This is a statement of constraint, not a delegation to the operator. Operator must compute these values independently to verify integrity; the authoritative expected values cannot be supplied until command execution is separately authorized.

Four blockers prevent CP0 authorization. They are listed below and enforced at runtime by `pb_check_package_completeness` before any service is started.

---

## Preauthorization Blockers

| ID | Item | State | Required action |
|----|------|--------|-----------------|
| B-CHECKSUM | PocketBase v0.29.3 SHA-256 (darwin\_arm64 and darwin\_amd64) | **BLOCKED** — cannot retrieve without network access during plan preparation | Operator retrieves from `checksums.txt` at `https://github.com/pocketbase/pocketbase/releases/download/v0.29.3/checksums.txt`; records values and retrieval date in manifest; replaces UNRESOLVED constants in `release1b_cp0.zsh` §3 |
| B-SCHEMA | Sanitized schema migration package | **BLOCKED** — production migrations not available in this session | Operator supplies reviewed migration directory; computes per-file SHA-256 manifest; records path and manifest hash |
| B-HOOKS | Local hook source files | **BLOCKED** — production hook source not available in this session | Operator supplies each hook as a reviewed file with individual SHA-256; records in `release1b_hook_manifest.json` |
| B-FRONTEND | Frontend source snapshot | **BLOCKED** — repository snapshot not available in this session | Operator supplies read-only snapshot with commit hash; secret-scanned; records in manifest |

Round 13 **cannot be authorized for execution** while these blockers exist.

---

## Error Handling Model

**Option B selected** — no `ERR_EXIT`. Rationale:

- The harness must run cleanup on any failure; `ERR_EXIT` complicates cleanup functions that use probe commands expected to fail.
- Expected-failure tests are numerous; wrapping every one in `if…fi` under ERR_EXIT is identical to Option B but adds false assurance.
- Cleanup actions, Docker probes, and PocketBase health checks all use failure as a signal; `|| true` wrappers become necessary and difficult to audit.
- Under Option B every security-relevant command's return code is checked explicitly and failures propagate via `return 1`; this is auditable.

No `ERR_EXIT` or `setopt ERR_EXIT` appears in the script. All commands that must not fail have explicit checks. All commands that are expected to fail are inside `if…fi` or capture `$?` explicitly.

---

## Package Contents

| Artifact | File | Status |
|----------|------|--------|
| Authoritative driver | `release1b_cp0.zsh` | Drafted — see §3 of this document |
| Artifact manifest | `release1b_cp0_manifest.json` | Drafted |
| Schema manifest | `release1b_schema_manifest.json` | Drafted — no migration files supplied |
| Hook manifest | `release1b_hook_manifest.json` | Drafted — no hook files supplied |
| Test manifest | `release1b_test_manifest.json` | Drafted |

---

## Correction Matrix

| # | Round 13 item | Resolution |
|---|---------------|------------|
| 1 | Script truncated | Complete script written as `release1b_cp0.zsh` via workspace write tool; no fenced code block in chat |
| 2 | Artifact manifest missing exact hashes | `release1b_cp0_manifest.json` provided; SHA-256 of `release1b_cp0.zsh` must be computed by operator after receipt (`shasum -a 256 release1b_cp0.zsh`); externally-sourced artifacts listed as BLOCKED |
| 3 | Claimed completeness while incomplete | Status language corrected: "Partial draft; incomplete due to blockers; not suitable for authorization" |
| 4 | ERR_EXIT comment contradicts setopt | Option B selected; ERR_EXIT removed; all claims corrected; rationale documented above |
| 5 | URL self-test `:` delimiter broken | Replaced with parallel typed arrays `URL_SELFTEST_URLS` / `URL_SELFTEST_LABELS` / `URL_SELFTEST_EXPECTED`; URLs printed only as case labels |
| 6 | Preauthorization check too late | Package completeness (`pb_check_package_completeness`) is a documentation-only review step; harness self-test (`--harness-check`) runs without services; full run checks package before starting services |
| 7 | Checksums missing | B-CHECKSUM; cannot retrieve without network access; UNRESOLVED constants in §3 with explicit halt |
| 8 | Schema package missing | B-SCHEMA; `release1b_schema_manifest.json` describes required design; no migration files supplied |
| 9 | Migration directory not established | Script uses `--migrationsDir "${RELEASE1B_PB_MIGRATIONS_DIR}"` (adjacent to pb\_data, not inside it); PocketBase v0.29.x applies unapplied migrations at serve startup automatically; applied migrations verified via schema check |
| 10 | Schema copy failures suppressed | `pb_apply_schema_migrations` enumerates expected filenames from manifest; verifies each file hash before copy; no `\|\| true`; any mismatch halts |
| 11 | Runtime re-tarring unstable | Replaced with per-file SHA-256 manifest; each file verified individually before copy |
| 12 | Superuser creation mechanism assumed | `pocketbase superuser create email password` CLI used; password passed as arg (acceptable: disposable local credential, process listing brief, isolated environment); falls back to admin API if CLI absent; limitation documented |
| 13 | Hook package missing | B-HOOKS; `release1b_hook_manifest.json` describes required hooks; no source files supplied |
| 14 | Hooks not classified | Every hook in manifest carries class: Baseline / Capability probe / Candidate hardening / Provider mock / Test instrumentation |
| 15 | Frontend snapshot missing | B-FRONTEND; `t_static_route_inventory` implemented with UNRESOLVED branch when blocker present |
| 16 | File auth tests 5–8 deferred | T-FILE-AUTH-6 and T-FILE-AUTH-8 implemented (IMPL-U, executable when fixture supplied). T-FILE-AUTH-5 and T-FILE-AUTH-7 classified MD (Mandatory Deferred): lifecycle entirely blocked by B-HOOKS and B-SCHEMA respectively; no executable lifecycle exists. IMPL-U was inaccurate for these two; corrected in Round 13. |
| 17 | OTP endpoint contract wrong | Two separate test groups: `t_otp_legacy_link_group` (authenticated) and `t_otp_anonymous_disabled` (verify unimplemented flow is inaccessible) |
| 18 | TEST-NOT-A-PHONE wrong for provider endpoint | Direct field test: `TEST-NOT-A-PHONE`; OTP format test: `TEST-NOT-A-PHONE`; OTP provider lifecycle: local mock number, `MOCK_PHONE_LOCAL`, passed only to mock provider adapter; real number separately authorized |
| 19 | Hook matrix omits app\_superadmin | Matrix now covers five actors: `anon`, `ordinary`, `app_admin`, `app_superadmin`, `native_superuser` |
| 20 | Native superuser hook behavior not tested | `t_native_superuser_hook_behavior` tests native superuser on role update, phone update, file access, child denial, alias intercept; added to §33 orchestration |
| 21 | Hook removal not independently verified | `pb_remove_hook_verified` removes file, restarts, verifies health, repeats probe, requires expected 404, then PASS |
| 22 | Canary response includes run identifier | Canary returns `{"active":true}` only; no run suffix in response |
| 23 | Cleanup suppresses failures | `CLEANUP_FAILURE` flag; any failed step sets flag; root not deleted if flag set; `\|\| true` only where failure is explicitly captured into flag |
| 24 | Cleanup prints container ID | Error message prints label only; container ID written to permission-restricted evidence file |
| 25 | Root deletion validation incomplete | `pb_validate_destructive_target` verifies: marker regularity, marker contents, owner, canonical root, canonical parent, basename prefix, dangerous-path exclusion, PocketBase stopped, Mailhog removed, report retained, CLEANUP\_FAILURE clear |
| 26 | URL test prints raw URLs | Prints case label only; never prints caller-supplied URL |
| 27 | pb\_sanitize\_path insufficient | Raw command stderr suppressed and captured to evidence files; only mapped error codes to terminal; report scanned before export |
| 28 | Correction matrix had malformed rows | This table has one intact row per item |
| 29 | Function inventory missing | Inventory provided in §2 of `release1b_cp0.zsh`; caller map in `release1b_test_manifest.json` |
| 30 | Orchestration and exit logic missing | Complete `cp0_run` and `main` at bottom of script |
| 31 | DEFERRED=0 exit condition | Categories: Authorized Exclusion (AE, does not fail), Future Release (FR, does not fail), Mandatory Deferred (MD, blocks exit), Unresolved (UR, blocks exit); exit checks FAIL+BLOCKING+HARNESS\_ERR+UNRESOLVED+SKIP+MANDATORY\_DEFERRED+CLEANUP\_FAILURE=0 |
| 32 | Script too large for chat | Six separate files written to workspace; script is `release1b_cp0.zsh` not a chat fenced block |
| 33 | Confirmation | No commands executed; no syntax check; no production contact |

---

## Test Classification Legend

| Code | Meaning | Blocks CP0 exit |
|------|---------|-----------------|
| AE | Authorized Exclusion — explicitly outside this checkpoint | No |
| FR | Future Release — not in CP0 scope | No |
| MD | Mandatory Deferred — must complete for CP0; reason recorded | Yes |
| UR | Unresolved — required evidence or design incomplete | Yes |
| IMPL | Implemented — executable test present | — |
| BLOCK | Blocking finding — security implication; dependent tests skip | Yes |

---

## Known Mandatory Deferrals (MD) in This Draft

| Test ID | Reason |
|---------|--------|
| T-CONSENT-GATE-* | Consent hooks B-HOOKS; consent_records schema B-SCHEMA |
| T-OTP-LEGACY-DELIVERY | Requires mock provider; B-HOOKS |
| T-OTP-RATE-LIMIT | Requires mock provider and fault injection |
| T-OTP-ROLLBACK | Requires fault injection |
| T-PROVIDER-MOCK-* | Requires mock provider hook; B-HOOKS |
| T-CONCURRENCY | Requires parallel request harness |
| T-PROXY-HEADER | Requires TCP log analysis; outside isolated environment |
| T-STATIC-ROUTES | Requires B-FRONTEND |

---

## Confirmation

Round 13 preparation:
- executed no commands;
- performed no syntax check;
- made no production contact;
- copied no production data or credentials;
- created no test records;
- deployed no hooks, migrations, or frontend changes;
- sent no messages or emails;
- made no contact with PocketBase, Docker, Mailhog, or any external service.
