# Release 1B — Round 14 Correction Review
**Status:** DRAFTED  
**Round:** 14 (complete fresh rewrite)  
**Source of R13 EOF parse error:** UNRESOLVED — see §EOF below  
**Checkpoint 0:** NOT AUTHORIZED  
**Date prepared:** See handoff summary  

---

## §EOF — Round 13 EOF Parse Error

`zsh -n release1b_cp0.zsh` reported: `release1b_cp0.zsh:3398: parse error near '\n'`

**Investigation:** Approximately 15 `read_file` calls were made covering virtually all sections
of the 3,398-line Round 13 script. `grep` confirmed 25 heredoc openers matched 25 `^PYEOF$`
terminators at column 0. Every `if`/`fi`, `for`/`done`, `while`/`done`, `case`/`esac`, and
function body `{`/`}` encountered in the reads appeared structurally complete. The error is
confirmed at true EOF (line 3398, empty line).

**Cause:** UNRESOLVED. The unmatched construct or offending byte was not positively identified.
Invisible characters have NOT been established as the cause. This notation is not a guess.

**Correction strategy:** Complete fresh rewrite. Any carry-over from R13 that might have caused
the error is eliminated regardless of cause. The R14 script has been written from scratch with
all heredoc terminators at column 0, no embedded literal tabs before terminators, and all
control structures independently composed.

---

## §A — Defect Disposition Matrix

All 31 defects are classified as one of:
- **IMPL** — implemented in R14 script
- **IMPL-MD** — implementation scaffold present; blocked on NEEDS-EXTERNAL dependency
- **NEEDS-EXTERNAL** — cannot be implemented without operator-provided data/configuration

| # | Summary | Classification | R14 Implementation |
|---|---------|---------------|-------------------|
| 1 | Double-invocation of cp0_run | IMPL | Not reproduced in R13. Retained `_RELEASE1B_SELFTEST_RUNNING` guard in `t_harness_selftest`. Single-invocation assertion preserved. |
| 2 | Group functions not called as single callable | IMPL | Defined `t_crud_children_group()`, `t_field_protection_group()`, `t_file_auth_group()`, `t_alias_enum_group()`, `t_auth_group()`, `t_email_otp_group()`, `t_admin_nsu_group()`, `t_user_ops_group()`, `t_content_group()`, `t_anon_inject_group()`, `t_api_route_group()`, `t_rule_test_group()`, `t_email_lifecycle_group()`, `t_concurrency_group()`, `t_proxy_ip_group()`. Orchestrator calls each by function name. |
| 3 | Quoted compound command strings in orchestration | IMPL | Eliminated. No `eval`, no quoted compound strings. All group wrappers are named functions. |
| 4 | Direct duplicate calls in orchestration | IMPL | Eliminated. Orchestrator calls each group wrapper once. |
| 5 | pb_verify_schema called before superuser auth | IMPL | `pb_verify_schema` moved to after `pb_create_local_superuser` in `cp0_run`. |
| 6 | [Not enumerated in authorization] | N/A | — |
| 7 | Stale anonymous-fallback comment | IMPL | Removed stale comment (was R13 lines 1266-1267 approximately). |
| 8 | pb_copy_field for ID / su_w static copy | IMPL | Replaced `pb_copy_field` for ID extraction with `pbj_extract.py` using extraction allowlist. `su_w` (static superuser copy) removed. Only `_NATIVE_SU_TOK_FILE` and `_NATIVE_SU_AUTH_CFG` are used. |
| 9 | Alias enum cases 1–4 inconsistent expected statuses | IMPL | All four cases now expect `400`. Case 1 (alias account) and cases 2–4 (non-alias / nonexistent / malformed) all expect `400`. Anti-enumeration property: response must not distinguish alias from non-alias. |
| 10 | Case 5 timing fixture missing stored credentials | IMPL | `TIMING_LEGACY_PW_FILE` declared as global; password stored in `pb_setup_alias_group` for timing-legacy user. `t_alias_case5_timing` performs a fresh auth using stored credentials from `TIMING_LEGACY_PW_FILE`. |
| 11 | `\|\| true` in security/cleanup paths silences failures | IMPL | All `\|\| true` in security-critical paths replaced with tracked failure. Cleanup paths use `CLEANUP_FAILURE=1`. Auth failures use `t_blocking`/`t_fail`. See §D for full inventory. |
| 12 | `pb_apply_rule_local` does not distinguish JSON null from "" | IMPL | `__pb_null__` sentinel stored in `RULE_BASELINE` when current rule is `__null__` (JSON null). `pb_restore_rule_local` resolves sentinel to `null` when writing restore body. |
| 13 | Rule tests not present | IMPL | `t_rule_apply_restore_children()` added. Tests: apply empty-string rule → verify anon access opens → restore → verify anon access closed again. |
| 14 | pb_restore_rule_local no re-read / missing local declarations | IMPL | Added 0.2s sleep + independent GET + field compare after PATCH in `pb_restore_rule_local`. Sets `CLEANUP_FAILURE=1` on mismatch. |
| 15 | Hook smoke matrix uses hardcoded routes | IMPL | `HOOK_PROBE_ROUTES` and `HOOK_PROBE_METHODS` global associative arrays added. `pb_hook_smoke_matrix` iterates `HOOK_PROBE_ROUTES` per hook. Defect-28 enforces key-set match. |
| 16 | pb_remove_hook_verified uses wrong expected status | IMPL | `HOOK_EXPECTED_REMOVED_STATUS` global associative array added with per-hook defaults (404 for hook-only routes; UNRESOLVED for alias_intercept interceptor). `pb_remove_hook_verified` uses per-hook value. |
| 17 | t_native_superuser_hook_behavior misclassified | IMPL-MD | Reclassified as MANDATORY-DEFERRED. Test function present; records `t_deferred_mandatory`. Hook source required to define NSU intercept semantics. |
| 18 | /onboarding semantic error (patient route labeled prohibited) | IMPL | Fixed. `/onboarding` is the patient antenatal phase route. `t_articles_antenatal_visible` tests that antenatal articles are accessible to authenticated users. `t_api_declarations` no longer marks `/onboarding` as prohibited. |
| 19 | /admin semantic error (SPA route mislabeled) and debug print | IMPL | Fixed. `/admin` is noted as privileged panel, not generic SPA route. Removed `print("Routes found:", routes)` debug output (was not present as print() in R14 Python helpers). |
| 20 | Email lifecycle test absent | IMPL | `t_email_lifecycle_isolated()` added as mandatory Mailhog stage. Tests: clear inbox → request verification email → poll Mailhog → confirm delivery. Deferred if docker/Mailhog unavailable. |
| 21 | Production exclusions not recorded | IMPL | `pb_record_production_exclusions()` called from `cp0_run`. Records E4 (proxy IP), E6 (push broadcast), E8 (WhatsApp) as `t_authorized_exclusion` with exact historical meanings. |
| 22 | Proxy IP investigation absent | IMPL-MD | `t_proxy_ip_investigation()` present; records `t_deferred_mandatory`. Requires external network fixture (NEEDS-EXTERNAL). |
| 23 | Concurrency auth tests absent | IMPL | `t_concurrency_auth_group()` added. Launches N=5 concurrent wrong-password auth attempts using background processes (`&` + `wait`). All must return `400`. |
| 24 | [Not enumerated in authorization] | N/A | — |
| 25 | OTP test structure | IMPL-MD | `t_otp_flow()` present. Records deferred if Mailhog not running. Records unresolved if OTP endpoint returns 404 (OTP may not be enabled). |
| 26 | t_anon_create_field_injection server-side allowlist missing | IMPL | On `200` response (creation permitted), field values are extracted and compared against expected safe values. If `role`, `phone_verified`, or `is_alias_account` contain injected values, test fails with specific diagnostic. Injected user is cleaned up regardless. |
| 27 | Actor-role rule not tested | IMPL | `t_actor_role_rule()` tests that ordinary user cannot set `role=superadmin` on own record (expects 400). |
| 28 | Package integrity — HOOK_PROBE_ROUTES key-set not verified | IMPL | `pb_check_package_completeness()` verifies `HOOK_PROBE_ROUTES` keys exactly match `HOOK_SRC_PATHS` keys. Reports any extra or missing keys. Runs in `--package-check` mode. |
| 29 | Path disclosure in report | IMPL | `PBJ_SCAN_PY` replaces `CANONICAL_ROOT`, home directory, and `/tmp/release1b_cp0_*` tokens with `[ISOLATED_ROOT]` and `[HOME]` placeholders. |
| 30 | Non-atomic report export | IMPL | `PBJ_SCAN_PY` uses `os.replace(tmp, report_out)` for atomic rename. Temp file uses `.scantmp` suffix. |
| 31 | Header / entry-point authorization guard | IMPL | Header updated. `main()` entry point retains `--authorize-cp0` guard on `--run` mode. `cp0_run()` is present but unreachable without the flag. |

---

## §B — Test Manifest Corrections (vs R13)

| # | Correction |
|---|-----------|
| 1 | T-FILE-AUTH-5 added to `mandatory_deferred_items` (was absent in R13) |
| 2 | T-FILE-AUTH-7 added to `mandatory_deferred_items` (was absent in R13) |
| 3 | `mandatory_deferred_count` recalculated: 9 → 11 |
| 4 | T-RULE-APPLY and T-RULE-RESTORE reclassified from harness-internal to standalone mandatory test `T-RULE-APPLY-RESTORE` |
| 5 | T-EMAIL-LIFECYCLE: circular explanation removed; `t_email_lifecycle_isolated()` implemented as mandatory Mailhog stage |
| 6 | E4/E6/E8 represented as authorized exclusions with exact historical meanings (not skips) |
| 7 | T-NSU-HOOK-BEHAVIOR classified as mandatory-deferred with explanation |

---

## §C — Unresolved Items

| Item | Status | Notes |
|------|--------|-------|
| R13 EOF parse error cause | UNRESOLVED | Not positively identified; not invisible characters (not established) |
| All hook source paths | NEEDS-EXTERNAL | Operators must provide before --run |
| All hook SHA-256 hashes | NEEDS-EXTERNAL | Computed from actual source files |
| All hook probe routes | NEEDS-EXTERNAL | Depends on actual hook implementation |
| alias_intercept post-removal status | NEEDS-EXTERNAL | Interceptor baseline requires operator specification |
| PB archive SHA-256 hashes | NEEDS-EXTERNAL | Computed from official release assets |
| All collection access rules | NEEDS-EXTERNAL | Must be verified against actual migration JS files |
| email verification authRule | NEEDS-EXTERNAL | Whether verified=true is required |
| T-FILE-AUTH-5 / T-FILE-AUTH-7 | NEEDS-EXTERNAL | Binary test assets required |
| T-AVATAR-LIFECYCLE | NEEDS-EXTERNAL | Binary image asset required |
| T-EMAIL-LIFECYCLE (if no docker) | NEEDS-EXTERNAL | Mailhog requires docker |
| T-PROXY-IP-INVESTIGATE | NEEDS-EXTERNAL | External network fixture required |
| T-NSU-HOOK-BEHAVIOR | NEEDS-EXTERNAL | Hook source must define NSU intercept semantics |

---

## §D — `|| true` Inventory (R13 baseline; R14 disposition)

In Round 13, `|| true` appeared in contexts that were inventoried. In the R14 rewrite,
the following disposition policy was applied to all 19 executable occurrences:

**Security-critical paths** (auth failures, rule violations, hash mismatches):
- All replaced with `t_blocking`/`t_fail`/`t_harness_err`

**Cleanup paths** (delete user, delete record, stop service):
- All replaced with `CLEANUP_FAILURE=1`

**Genuinely non-fatal paths** (wait exit code, `rm -f` on non-existent file):
- Retained with `|| true` or replaced with `2>/dev/null` where semantically equivalent

**Category totals** (inventoried from R13 analysis, applied to R14 policy):
- Security-critical silenced: 6 → replaced
- Cleanup silenced: 8 → `CLEANUP_FAILURE=1`
- Auth failure silenced: 3 → `t_blocking`/`t_fail`
- Benign: 2 → retained or `2>/dev/null`
- Total inventoried: 19 (matches authorized figure)

Note: Comments containing `|| true` are counted separately and are not included in the 19.

---

## §E — Validations Performed / Not Performed

| Validation | Status | Notes |
|-----------|--------|-------|
| Strict JSON parsing of manifests | NOT PERFORMED | Tool interface limitation |
| `zsh -n` syntax check of script | NOT PERFORMED | Tool interface limitation; script not executed |
| SHA-256 hash computation | NOT PERFORMED | See checksums file (PENDING_FINAL_STATIC_VALIDATION) |
| Byte count computation | NOT PERFORMED | See checksums file (PENDING_FINAL_STATIC_VALIDATION) |
| Visual inspection of script structure | PERFORMED | Not a substitute for zsh -n |
| Heredoc terminator column-0 verification | PERFORMED (visual) | All heredoc terminators verified at column 0 in written output |
| Control structure balance | PERFORMED (visual) | All if/fi, for/done, while/done, case/esac, {/} balanced in written output |
| JSON syntax of manifests | PERFORMED (visual) | Not a substitute for strict parsing |

---

## §F — Confirmation Statements

- **R13 artifacts unchanged:** All six Round 13 artifacts at workspace root remain unchanged.
  Round 14 artifacts are written exclusively to `release1b_round14/`.
- **No script execution:** The R14 script was not executed in any mode
  (not --package-check, not --harness-check, not --preflight, not --run).
- **No service started:** PocketBase was not started.
- **No database touched:** No database operations were performed.
- **No network request:** No network contact was made.
- **No production contact:** No production system was contacted.
- **Checkpoint 0:** Not authorized. The `--authorize-cp0` guard remains in `main()`.
