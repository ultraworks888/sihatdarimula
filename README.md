# Sihat Dari Mula / My Healthy Start

This is the private source repository for the Sihat Dari Mula mobile-first PWA and its supporting services. Keep this repository private because it contains security-sensitive application and backend source, even though credentials and production data are intentionally excluded.

## Repository layout

- `codebase/` — frontend PWA source.
- `push-server/` — canonical push-notification server implementation and operating documentation.
- `pb_hooks/` — PocketBase runtime hooks and backend logic.
- `pb_migrations/` — PocketBase schema and data migrations intended for controlled execution.
- `cloudflare-worker/` — Cloudflare Worker that forms the WhatsApp/Meta gateway boundary.
- `release1b_round14/` through `release1b_round24/` — historical release and audit evidence. These directories are not ordinary application source and should not be rewritten or consolidated.

## Push-server compatibility

The canonical push-server entrypoint is `push-server/server.js`. The root `server.js` is a thin compatibility entrypoint for hosting services that may still run `node server.js` from the repository root. The root `package.json` is retained temporarily for the same deployment compatibility.

Runtime environment variables must be injected by the hosting environment. Do not commit credentials or local `.env` files.

## Data boundary

`pb_data/` contains stateful PocketBase runtime and database data. It is intentionally excluded from source control and must not be copied, regenerated, or modified as part of normal source changes.

See the component-specific documentation and `AGENTS.md` files before making changes.
