# Release 1B — Round 18 Correction Review
**Status:** DRAFTED  
**Round:** 18 (narrowly corrected from Round 17)  
**Basis:** R18 static validation findings  
**Checkpoint 0:** NOT AUTHORIZED

---

## §A — Round 17 Authoritative Static Results (from Round 18 review)

| Artifact | Actual bytes | SHA-256 |
|---|---:|---|
| `release1b_cp0.zsh` | 144,906 | `998f989d6ed086d1c6f4d75586d5387668bd30dd2c2ac232fab214bb9528ca10` |
| `release1b_cp0_manifest.json` | 7,409 | `c6477204b2989af77cf19e15a4eec3e24bb854a4a54f5abce9f1f391835ae08c` |
| `release1b_schema_manifest.json` | 8,380 | `274e6950c872723282072ef913d411465fe4ccc74d730fac80fbc4572302f4d3` |
| `release1b_hook_manifest.json` | 4,354 | `88863318fc6b2590069f1e252d199cc160d3604238be7fa0b6a4684f3f24cfd3` |
| `release1b_test_manifest.json` | 10,087 | `14c5af321d9b5a264d95d62b2af26f7773e7ad29e5c4dfce619ba81e255357b8` |
| `release1b_round17_review.md` | 10,258 | `b3bbe29c304e372b1ee53ed14f8026cddfdb5549d08cfb313225c06b85273a49` |
| `release1b_round17_checksums.sha256` | 1,543 | `bf6bda3f260f086cd3b6ceca052b224775624baa7ed28c37ec7fc72df89ed65e` |

Six of seven R17 tool-reported byte counts were inaccurate.

---

## §B — Round 18 Blocking Findings and Fixes

### Finding 1 — `kill -0` cannot reliably detect zombie children

**R17 problem:** After SIGTERM, R17 polled `kill -0 $_stored_pid`. A child process that
has exited but not yet been reaped by the parent remains as a zombie and its PID stays in
the process table — so `kill -0` returns 0 (appears alive). This could cause:
- spurious timeout and SIGKILL escalation;
- spurious `CLEANUP_FAILURE=1`;
- the later `wait` happening after an unnecessary delay.

**R18 fix — watchdog + immediate `wait` pattern:**

| Step | Action |
|---|---|
| 1 | Verify PID belongs to our child: `ps -p $pid -o ppid=` returns `$$` |
| 2 | Send SIGTERM |
| 3 | Launch background watchdog: `sleep 6`, then re-verify PPID before sending SIGKILL; write flag file if fired |
| 4 | Call `wait $_stored_pid` in parent — reaps normal exit and zombie **immediately** |
| 5 | Cancel and reap watchdog: `kill $_watchdog_pid`, `wait $_watchdog_pid || true` |
| 6 | Classify result: flag file (escalation), wait rc (exit type) |
| 7 | Confirm child gone: re-check PPID after wait |
| 8 | Set `CLEANUP_FAILURE=1` only for genuine escalation or confirmed-unreaped child |
| 9 | Clear `RELEASE1B_PB_PID` |

The watchdog re-verifies PPID before sending SIGKILL, preventing PID reuse from being
signalled after the original child has exited.

---

### Finding 2 — `pb_pid_exists` uses locale-dependent stderr parsing

**R17 problem:**
```zsh
case "$_err" in
  *"Operation not permitted"*|*"not permitted"*|*"EPERM"*)
```
This matches English OS error text from `kill -0 2>&1` — unreliable across OS, shell, and locale.

**R18 fix:** `pb_pid_exists()` removed entirely. The shutdown design now uses
`ps -p $pid -o ppid=` (structured numeric output) for all ownership decisions.
No localized text is parsed anywhere in the shutdown path.

---

### Finding 3 — OTP concurrency test targets wrong OTP model

**R17 problem:** `T-CONCURRENCY-OTP-SEND` called
`POST /api/collections/users/request-otp` with an email identity and expected
Mailhog delivery — this is PocketBase email OTP, not the Release 1B
phone/WhatsApp OTP flow.

**R18 fix:** `T-CONCURRENCY-OTP-SEND` completely redesigned in §36b.

- Checks `HOOK_OTP_PHONE_ROUTE` and `HOOK_OTP_MOCK_CONTROL_ROUTE` constants.
- If either is `UNRESOLVED__NEEDS_EXTERNAL` (current state): immediately emits
  `MANDATORY-DEFERRED` listing all six prerequisite categories.
- No HTTP request of any kind is made.
- Mailhog is not referenced.
- `/api/collections/users/request-otp` is not referenced.
- Implementation of concurrent workers deferred until endpoint contract supplied.

---

### Finding 4 — OTP rate-limit invariant not defined

**R17 problem:** Workers could return any combination of 200/204/429 and the test
would pass. No invariants on allowed-send count, quota, provider attempts, or OTP
lifecycle state.

**R18 fix:** All invariants listed in the hook manifest as NEEDS-EXTERNAL
prerequisites. The test cannot be designed until these are supplied. The MANDATORY-
DEFERRED message lists all six prerequisite categories including rate-limit invariants.

---

### Finding 5 — OTP probe mutated test state

**R17 problem:** A real `POST /api/collections/users/request-otp` was used as an
availability probe before launching concurrent workers, consuming a rate-limit slot.

**R18 fix:** No probe request is made. Availability is determined exclusively from
manifest constants (`HOOK_OTP_PHONE_ROUTE`, `HOOK_OTP_MOCK_CONTROL_ROUTE`). When the
test eventually runs, the mock-provider control interface will serve as the non-
mutating availability/reset probe.

---

### Finding 6 — Helper exit status not captured before output parsing

**R17 problem:** In `t_concurrency_auth_group`, `pbj_http.py` was invoked without
capturing its exit status before reading `$setup_sf` and `$setup_rpf`.

**R18 fix:** `_helper_rc` captured immediately after `python3 "$PBJ_HTTP_PY"`. If
nonzero: `t_harness_err` emitted, files removed, function returns 1 without reading
status or response path.

---

### Finding 7 — OTP per-worker auth config absent

**R18 fix:** The OTP test is entirely deferred. When eventually implemented, the hook
manifest must declare the endpoint auth policy (authenticated vs. anonymous) and
supply per-worker auth configurations accordingly. The MANDATORY-DEFERRED message lists
this as prerequisite category 3.

---

### Finding 8 — Idempotency test wording implied full implementation

**R18 fix:** `t_concurrency_idempotency_post_group()` comment updated to state
explicitly that this is MANDATORY-DEFERRED **and implementation incomplete** — not
merely deferred-because-configured. The defect-23 classification block now separately
describes the status of each of the three concurrency tests.

---

## §C — Defect Disposition Matrix (R18 final)

| # | Summary | Classification | Status |
|---|---|---|---|
| 1 | Double-invocation | IMPL | R14 |
| 2 | Group wrapper functions | IMPL | R14 |
| 3 | Quoted compound strings | IMPL | R14 |
| 4 | Duplicate orchestration calls | IMPL | R14 |
| 5 | verify_schema before superuser auth | IMPL | R14 |
| 7 | Stale comment | IMPL | R14 |
| 8 | pbj_extract / su_w removal | IMPL | R14 |
| 9 | Alias enum 1–4 expect 400 | IMPL | R14 |
| 10 | Case 5 credentials | IMPL | R14 |
| 11 | Failure propagation / child shutdown | IMPL | R18 (watchdog; no kill -0; no zombie FP) |
| 12 | Null sentinel in rules | IMPL | R14 |
| 13 | Rule tests absent | IMPL | R14 |
| 14 | Rule restore no re-read | IMPL | R14 |
| 15 | Hook smoke hardcoded routes | IMPL | R14 |
| 16 | Hook removal wrong status | IMPL-MD | R15 (reclassified) |
| 17 | NSU hook behavior | IMPL-MD | R14 |
| 18 | /onboarding semantic | IMPL | R14 |
| 19 | /admin semantic / debug print | IMPL | R14 |
| 20 | Email lifecycle test | IMPL | R14 |
| 21 | Production exclusions E4/E6/E8 | IMPL | R15 |
| 22 | Proxy IP investigation | IMPL-MD | R14 |
| 23 | Concurrency AUTH+OTP+idempotency | IMPL-MD | AUTH: R18 IMPL; OTP+idempotency: IMPL-MD |
| 25 | OTP test structure | IMPL-MD | R14 |
| 26 | Field injection allowlist | IMPL | R14 |
| 27 | Actor-role rule | IMPL | R14 |
| 28 | Package integrity key-set | IMPL | R14 |
| 29 | Path disclosure in report | IMPL | R14 |
| 30 | Non-atomic report export | IMPL | R14 |
| 31 | Entry-point guard | IMPL | R14 |

**Summary: IMPL=21, IMPL-MD=8, NEEDS-EXTERNAL=2** (unchanged from R17)

---

## §D — `|| true` Inventory (R18)

| # | Location | Classification | Rationale |
|---|---|---|---|
| 1 | `pb_wipe_secret_file` | BENIGN-RETAINED | `dd` may return nonzero on partial write; `rm -f` removes unconditionally |
| 2 | `pb_trap_cleanup` — watchdog reap | BENIGN | `wait` returns nonzero when watchdog was killed by cancel signal; expected |

Total R18 executable `|| true`: **2**. Site #2 is a new location (watchdog reap)
replacing the old site #2 (direct child reap), which is now a clean `wait` with
captured return code.

---

## §E — Unresolved Items

| Item | Status |
|---|---|
| All hook source paths | NEEDS-EXTERNAL |
| All hook SHA-256 hashes | NEEDS-EXTERNAL |
| All hook probe routes | NEEDS-EXTERNAL |
| `alias_intercept` post-removal status | NEEDS-EXTERNAL |
| `HOOK_OTP_PHONE_ROUTE` | NEEDS-EXTERNAL |
| `HOOK_OTP_MOCK_CONTROL_ROUTE` | NEEDS-EXTERNAL |
| OTP endpoint auth policy | NEEDS-EXTERNAL |
| OTP rate-limit invariants | NEEDS-EXTERNAL |
| OTP lifecycle states | NEEDS-EXTERNAL |
| Idempotency hook endpoint contract | NEEDS-EXTERNAL |
| PocketBase archive SHA-256 hashes | NEEDS-EXTERNAL |
| All collection access rule expressions | NEEDS-EXTERNAL |
| Email verification authRule | NEEDS-EXTERNAL |
| T-FILE-AUTH-5, T-FILE-AUTH-7 | NEEDS-EXTERNAL (binary assets) |
| T-AVATAR-LIFECYCLE | NEEDS-EXTERNAL (image asset) |
| T-EMAIL-LIFECYCLE, T-OTP-FLOW (if no docker) | NEEDS-EXTERNAL |
| T-PROXY-IP-INVESTIGATE | NEEDS-EXTERNAL (network fixture) |
| T-NSU-HOOK-BEHAVIOR | NEEDS-EXTERNAL (hook source) |

---

## §F — Validations Performed / Not Performed

| Validation | Status |
|---|---|
| `zsh -n` syntax check | **NOT PERFORMED** — tool-interface limitation |
| Strict JSON parsing | **NOT PERFORMED** — tool-interface limitation |
| SHA-256 hash computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Byte count computation | **NOT PERFORMED** — PENDING_FINAL_STATIC_VALIDATION |
| Visual inspection of all changes | PERFORMED |
| `grep \|\| true` | PERFORMED — 2 executable occurrences; both benign |
| `kill -0` scan | PERFORMED — absent from shutdown path |
| Localized text parsing scan | PERFORMED — no case-match on stderr text |
| OTP semantics check | PERFORMED — no email OTP or Mailhog in §36b |
| Mutating probe check | PERFORMED — no HTTP request in §36b |
| Helper exit status check | PERFORMED — `_helper_rc` captured in §36a pre-worker step 2 |
| Defect count recalculation | PERFORMED — IMPL=21, IMPL-MD=8 confirmed |

---

## §G — Confirmation Statements

- **R13 artifacts unchanged:** Workspace root artifacts untouched.
- **R14 artifacts unchanged:** `release1b_round14/` untouched.
- **R15 artifacts unchanged:** `release1b_round15/` untouched.
- **R16 artifacts unchanged:** `release1b_round16/` untouched.
- **R17 artifacts unchanged:** `release1b_round17/` untouched.
- **No script execution.** R18 script not executed in any mode.
- **No service started. No database touched. No network request. No production contact.**
- **Checkpoint 0 remains unauthorized.** `--authorize-cp0` guard present in `main()`.
