# Release 1B — Narrow Static Validation Authorization Request

**Prepared by:** Coderick AI
**Date:** 2026-08-24
**Depends on:** Six Round 13 workspace artifacts (see `release1b_cp0_manifest.json`)
**Purpose:** Obtain operator authorization for non-mutating local validation before Round 14 corrections are written

---

## 1. Motivation

Round 14 corrections cannot be written responsibly without first knowing:

- exact byte sizes and SHA-256 values for the six delivered files, so the manifest can carry authoritative expected values rather than `NOT_COMPUTABLE_UNDER_NO_COMMAND_RESTRICTION`;
- whether `release1b_cp0.zsh` is syntactically valid enough for automated function-inventory and prohibited-construct analysis to produce reliable results;
- which functions are duplicated, undefined, or referenced but absent;
- which test IDs appear more than once in the manifests;
- which `|| true` uses are currently untracked.

These questions cannot be answered by reading the files in the chat interface alone. They require non-mutating local commands against the files that already exist in the workspace.

---

## 2. Proposed Scope — What Would Be Run

### 2.1 File integrity

| Command | Target | Produces |
|---------|--------|----------|
| `wc -c <file>` | Each of the 6 files | Byte count |
| `shasum -a 256 <file>` | Each of the 6 files | SHA-256 hex string |

Purpose: populate the `byte_size` and `sha256` fields in `release1b_cp0_manifest.json` with authoritative values before Round 14 is finalized.

### 2.2 JSON validity

| Command | Target | Produces |
|---------|--------|----------|
| `python3 -m json.tool <file> > /dev/null` | All four `.json` files | Parse success or first-error location |

Purpose: confirm all four manifests are strict-JSON-valid before Round 14 editing.

### 2.3 Zsh syntax check

| Command | Target | Produces |
|---------|--------|----------|
| `zsh -n release1b_cp0.zsh` | `release1b_cp0.zsh` | Syntax errors only; does not execute any function or command in the script |

Purpose: identify parse-level defects before writing 3 000+ lines of corrections. `zsh -n` reads and parses without executing; no function body runs; no PocketBase binary is invoked; no file other than the script is touched.

### 2.4 Function inventory (read-only Python)

A Python script (written inline, not saved, not executed as part of the harness) reads `release1b_cp0.zsh` as a text file and extracts:

- all lines matching `^<name>()` or `^function <name>` — defined functions;
- all `<name> [args]` call sites that appear in function bodies — referenced names;
- the difference: referenced-but-undefined names and defined-but-never-called names.

Output: a table to the chat only. No file is written, no command other than the Python interpreter reading the script file is run.

### 2.5 Duplicate function detection

Same Python pass: collect all defined function names and report any that appear more than once.

### 2.6 Duplicate test-ID detection

Python reads `release1b_test_manifest.json` as text and reports any `"id"` value that appears more than once.

### 2.7 Script-vs-manifest function comparison

Python compares the set of function names found in §2.4 against the inventory listed in §2 of `release1b_cp0.zsh` and the test IDs listed in `release1b_test_manifest.json`. Reports:
- functions in script but absent from inventory comment;
- inventory entries absent from script.

### 2.8 Prohibited-construct scan

Python reads `release1b_cp0.zsh` line by line and reports:
- any use of `eval`;
- any use of bare `read` without `-r -s` (unsafe shell read);
- every `|| true` occurrence with its line number and the calling context (the preceding line for label);
- every occurrence of `|| CLEANUP_FAILURE=1` to confirm they are paired with the expected failure paths.

Output: annotated line list. No modification.

---

## 3. Explicit Prohibitions — What Would Not Be Run

The following are **not** authorized by this request and must remain prohibited unless separately authorized:

| Prohibited action | Reason |
|---|---|
| `zsh release1b_cp0.zsh` (any mode) | Would execute the harness |
| `zsh release1b_cp0.zsh --package-check` | Would execute package-check logic |
| `zsh release1b_cp0.zsh --harness-check` | Would start services and execute stage 0 |
| `zsh release1b_cp0.zsh --preflight` | Would start services |
| `zsh release1b_cp0.zsh --run` | Full harness run — explicitly unauthorized |
| Starting PocketBase | Any mode |
| Starting Docker or Mailhog | Any mode |
| Creating a local database | Any mode |
| Making any network request | Including to GitHub, checksums URLs, or local ports |
| Contacting production | Any environment |
| Modifying any of the six reviewed source files | The six files must remain exactly as delivered for Round 14 input |
| Creating test records | Any database |
| Deploying hooks, migrations, or rules | Any environment |
| Sending WhatsApp messages or emails | Any channel |
| Downloading PocketBase binary | Network prohibited |
| Copying production data or credentials | Any direction |

---

## 4. Output of Validation Run

If authorized, the static validation would produce, within the chat response only:

1. A table: file, byte count, SHA-256 — for all six files.
2. JSON validity result per file.
3. `zsh -n` output verbatim (parse errors or "no errors").
4. Defined-function list (sorted, line numbers).
5. Duplicate-function list (if any).
6. Referenced-but-undefined names (if any).
7. Duplicate test IDs in manifests (if any).
8. Script-vs-manifest gaps.
9. Prohibited-construct occurrences with line numbers.

No file in the workspace would be modified. No command outside the list in §2 would run.

---

## 5. What the Results Feed Into

After this validation, and only after, Round 14 corrections will be written. Specifically:

- Byte sizes and SHA-256 values will populate the `round13_artifacts` section of the manifest with authoritative values (noting that Round 14 edits will change the script, so a second hash pass will be needed after Round 14 is finalized).
- `zsh -n` output will determine whether the function-inventory analysis is reliable enough to catch the §2.4–§2.8 findings.
- The 31 defects identified in the Round 13 review will be addressed in Round 14 as a corrected package with its own fresh manifest.

Round 14 will **not** be produced until this static validation is either authorized and completed, or explicitly waived by the operator with an acknowledgement that the hash and syntax inputs will remain unknown until execution authorization is granted.

---

## 6. Authorization Format Requested

To authorize this scope, the operator should state:

> Authorize non-mutating static validation as described in `release1b_static_validation_auth_request.md`. This authorizes §2.1 through §2.8 only. All prohibitions in §3 remain in force.

Any modification to this scope requires a separate authorization statement.

---

## 7. Confirmation: No Production Contact in This Document

This document was produced by:
- reading the six workspace files;
- no commands were executed;
- no services were started;
- no network requests were made;
- no production environment was contacted;
- no database was created;
- no test records were created;
- no files other than this document were written.
