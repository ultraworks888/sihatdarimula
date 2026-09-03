# AGENTS.md — Sihat Dari Mula Cloudflare WhatsApp Worker

> More-specific operating rules for the `cloudflare-worker/` subtree.
>
> These instructions supplement the repository-root `AGENTS.md`.
> For files under `cloudflare-worker/`, follow both files. If there is a conflict, this file governs Worker-specific behavior while the root security and deployment constraints still apply.

---

## 1. Scope

This subtree contains the Cloudflare Worker that acts as the WhatsApp / Meta webhook security gateway for Sihat Dari Mula.

Expected trust chain:

```text
Meta / WhatsApp
      |
      v
Cloudflare Worker
      |
      v
PocketBase /api/whatsapp/webhook
```

The Worker is a security boundary, not a general application backend.

Do not move unrelated PWA, PocketBase, push-server, or release-harness logic into this subtree.

---

## 2. Known Worker identity and files

Known Worker name:

```text
mhs-whatsapp-gateway
```

Historically relevant files have included:

```text
worker.js
wrangler.toml
test-worker.sh
README.md
```

Inspect the current directory before editing. Do not assume these are the only files or that names have not changed.

---

## 3. Secret names

Known secret names only:

```text
META_APP_SECRET
WA_WEBHOOK_VERIFY_TOKEN
WA_INTERNAL_FORWARD_SECRET
```

Never:
- print their values;
- commit their values;
- add their values to source, README files, fixtures, logs, screenshots, or test output;
- duplicate them into ordinary environment files;
- infer or reconstruct them.

Do not run commands that dump all Worker secrets or the full environment merely for debugging.

---

## 4. GET webhook verification

For Meta webhook verification requests:

- validate the supplied verification token against the configured secret;
- return the challenge only when verification is valid;
- use the expected HTTP status behavior for invalid verification;
- do not reveal the configured verification token;
- do not add a bypass route for testing.

Tests should cover at least:
- correct token;
- incorrect token;
- missing token/challenge parameters as applicable.

---

## 5. POST signature verification

For webhook POST requests:

- verify `X-Hub-Signature-256`;
- compute verification over the **raw request body bytes**;
- use the Meta app secret;
- do not parse/re-serialize the body before HMAC verification;
- reject or safely ignore unverified payloads according to the intended gateway contract;
- do not forward unverified payloads to PocketBase;
- do not add "development only" signature bypasses to production code.

Any refactor that changes body reading, cloning, parsing, streaming, or encoding must be treated as security-sensitive.

Tests must include:
- valid signature;
- invalid signature;
- malformed/missing signature;
- representative webhook body.

---

## 6. Worker -> PocketBase trust boundary

Known PocketBase target route:

```text
/api/whatsapp/webhook
```

Forwarded requests must authenticate the Worker-to-PocketBase hop using the internal forwarding secret.

Rules:
- do not forward the Meta app secret;
- do not expose the internal forwarding secret to clients;
- do not remove internal-forward authentication merely because signature validation already occurred at the Worker;
- do not trust arbitrary requests to PocketBase as though they came through the Worker;
- preserve content/body integrity when forwarding.

If the PocketBase route or auth header mechanism differs from historical assumptions, inspect current code and report the actual contract before editing.

---

## 7. Historical acknowledgement behavior

During an earlier phase, the Worker returned HTTP `200` to Meta even when forwarding to PocketBase failed, to avoid Meta retries.

Treat this as **historical behavior, not automatically the final production policy**.

Before changing acknowledgement/retry behavior:
1. inspect current Worker code;
2. inspect PocketBase webhook handling;
3. identify retry/idempotency implications;
4. identify duplicate-event risk;
5. obtain approval for behavior changes.

Do not "improve" retry behavior casually.

---

## 8. Logging rules

Allowed logs:
- request type;
- verification success/failure;
- forwarding success/failure;
- upstream HTTP status;
- non-sensitive correlation identifiers if already designed for that purpose.

Never log:
- secret values;
- OTP values;
- authorization headers;
- full sensitive user payloads unless explicitly required and reviewed;
- raw webhook bodies by default;
- phone numbers unless necessary and appropriately minimized.

Prefer structured, minimal operational logs.

---

## 9. Network boundaries

The Worker should only contact endpoints required for its defined gateway role.

Do not add third-party calls, analytics, telemetry, or new external services without explicit approval.

Do not change the production PocketBase destination or hostname as part of unrelated work.

---

## 10. Wrangler rules

Use Wrangler only from this Worker subtree or its proper local Worker project context.

Safe routine operations may include local/static checks and non-deploying diagnostics.

Do **not** run any production deployment command without explicit approval.

Prohibited without explicit approval include:

```text
wrangler deploy
wrangler secret put ...
wrangler secret delete ...
wrangler versions deploy ...
```

or equivalent commands that change production configuration/secrets/deployment state.

Do not assume that "tests passed" authorizes deployment.

---

## 11. Validation gates

For any Worker change, run the relevant checks that actually exist in this subtree.

Minimum acceptance areas:

### Gate W1 — syntax/build
- Worker source parses/builds;
- dependency/install state is understood;
- no unrelated dependency upgrade.

### Gate W2 — GET verification
- correct token succeeds;
- wrong token fails;
- challenge behavior is correct.

### Gate W3 — POST HMAC
- valid signature accepted;
- invalid signature rejected/ignored;
- malformed/missing signature handled safely;
- verification uses raw body bytes.

### Gate W4 — PocketBase forwarding
- verified payload forwarded correctly;
- internal forwarding authentication present;
- PocketBase success handled;
- PocketBase failure behavior matches the current intended acknowledgement policy.

### Gate W5 — logging
- no secret leakage;
- no OTP leakage;
- no new sensitive raw payload logging.

### Gate W6 — diff
If Git is available:

```bash
git diff --check
git diff -- cloudflare-worker/
```

Inspect for:
- security bypasses;
- accidental secret values;
- debug code;
- unrelated formatting churn;
- modified deployment identifiers;
- changed routes/hosts;
- changed retry semantics.

### Gate W7 — deployment
Deployment status must remain:

```text
NOT DEPLOYED
```

unless the project owner explicitly approved the exact deployment action and it was actually performed.

---

## 12. Coderick simple-change prompt

For a small Worker change:

```text
Read the repository-root AGENTS.md and cloudflare-worker/AGENTS.md first.

Make only this requested Worker change:
<change>

Do not change webhook trust boundaries, secret handling, HMAC verification, PocketBase authentication, production routes, or acknowledgement/retry semantics unless the task explicitly requires it.

Run the smallest relevant Worker checks.
Show the diff.
Do not deploy, change secrets, commit, or push.
```

---

## 13. Codex substantial-change prompt

```text
Read the repository-root AGENTS.md and cloudflare-worker/AGENTS.md first.

Inspect the current Worker implementation before editing.

Report:
1. current GET verification flow;
2. current POST HMAC verification flow;
3. current Worker-to-PocketBase authentication flow;
4. current acknowledgement/failure behavior;
5. files affected;
6. security risks;
7. smallest safe implementation plan.

Do not modify files yet.
Stop for approval.
```

After approval:

```text
Implement only the approved Worker plan.
Keep the diff narrow.
Run all relevant Worker validation gates.
Do not change secrets.
Do not deploy.
Finish with the root AGENTS.md completion-report format.
```

---

## 14. Final Worker rule

Never trade away webhook authenticity, secret isolation, or trust-boundary integrity for convenience.

For this subtree:

**signature correctness > secret safety > forwarding integrity > retry behavior > operational convenience**
