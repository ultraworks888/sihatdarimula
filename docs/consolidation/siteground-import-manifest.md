# SiteGround Import Manifest

- Import source: Coderick `codebase.zip`
- Destination repository root: `/Users/dariuschan/Documents/Codex/SDM`
- Import date: 2026-09-03

## Import exclusions

The controlled import excluded:

- `pb_data/`
- `.env` files
- runtime and generated artifacts
- `.git/`

The import contains no production data. No secret values or credentials are recorded in this manifest.

## Quarantined migrations

- `0000000000_smtp_settings.js`
- `1782898775_seed_superadmin_user_4fd7.js`
- `1785841371_seed_onesignal_settings_d2ce.js`
- `1786721111_create_whatsapp_server_secrets_eabe.js`
- `1784882632_configure_smtp_and_verification_url_702c.js`

The first four migrations listed above were excluded during selective extraction. `1784882632_configure_smtp_and_verification_url_702c.js` was subsequently removed from the destination working tree after a probable hardcoded SMTP credential was detected.

No quarantined migration is approved for restoration without a separate security review.
