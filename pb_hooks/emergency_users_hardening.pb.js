/**
 * Release 1A — Emergency Role Escalation Protection
 * My Healthy Start
 *
 * Fires on every authenticated REST API PATCH to the users collection.
 * Does NOT fire for $app.save() calls originating from within hooks —
 * the existing OTP verification flow is therefore unaffected.
 * Does NOT block phone, phone_verified, or any other field in Release 1A.
 *
 * Policy:
 *   - Request body does not contain "role"    → pass through, no change.
 *   - Authenticated as application superadmin → pass through.
 *   - Authenticated as native _superusers     → pass through.
 *   - Ordinary user or application admin      → 403 Forbidden.
 *
 * Logging: only the blocked-write event type is logged. No PII, no tokens,
 * no email, no phone, no role value, no request body content is ever logged.
 */

onRecordUpdateRequest((e) => {
  const body = e.requestInfo().body;

  // If "role" is not present in the update body, allow all other field
  // changes through without any interference.
  if (body["role"] === undefined) return e.next();

  // No authenticated session — let the collection updateRule handle rejection.
  if (!e.auth) return e.next();

  // Application superadmin: permitted to manage application-user roles.
  if (e.auth.getString("role") === "superadmin") return e.next();

  // Native PocketBase _superusers: permitted to manage all records.
  // e.auth.collection().name identifies the auth record's collection in
  // PocketBase v0.28.4 JSVM. If this binding is unavailable, the catch block
  // logs the gap without exposing any data and falls through to block —
  // the safe failure mode. Smoke test 7 verifies this path; failure triggers
  // immediate rollback per the stated rollback conditions.
  try {
    if (e.auth.collection().name === "_superusers") return e.next();
  } catch (collErr) {
    $app.logger().error(
      "emergency_users_hardening: collection name check unavailable — blocked",
      "err", String(collErr)
    );
    // Fall through: safe failure blocks the request and triggers rollback via smoke test 7.
  }

  // Ordinary user or application admin — role write is not permitted.
  $app.logger().warn("emergency_users_hardening: blocked unauthorized role write attempt");
  throw new ForbiddenError("Role changes require superadmin authorization.");

}, "users");
