/**
 * WhatsApp Inbound Webhook — My Healthy Start
 * Phase B: PocketBase receiving side
 *
 * POST /api/whatsapp/webhook
 *
 * ─── WHO CALLS THIS ──────────────────────────────────────────────────────────
 * This endpoint is called exclusively by the Cloudflare Worker
 * (mhs-whatsapp-gateway.sihatdarimula.workers.dev) AFTER Meta's
 * X-Hub-Signature-256 has been verified over the original raw bytes.
 * It must NOT be called directly by Meta or any client.
 *
 * ─── AUTHENTICATION ──────────────────────────────────────────────────────────
 * Every request must carry three headers:
 *   X-WhatsApp-Timestamp:   <unix seconds as plain decimal integer string>
 *   X-WhatsApp-Body-Digest: <lowercase hex SHA-256 of the original raw Meta bytes>
 *   X-WhatsApp-Signature:   <lowercase hex HMAC-SHA256(timestamp + "." + digest, secret)>
 *
 * The HMAC key is read from the whatsapp_server_secrets collection
 * (key = "wa_internal_forward_secret"), which has all API rules set to null.
 * $app.findFirstRecordByFilter() bypasses collection rules — the hook can
 * read the secret without any API authentication.
 * The secret is never logged, never returned in any response, and never
 * stored in source code or Vite/React configuration.
 *
 * ─── BODY DIGEST LIMITATION ─────────────────────────────────────────────────
 * PocketBase JSVM does not expose raw HTTP request body bytes.
 * X-WhatsApp-Body-Digest is a Worker-certified SHA-256 digest of the original
 * Meta bytes, computed by the Cloudflare Worker before forwarding.
 * PocketBase cannot independently recompute SHA-256 over the body it received.
 * Therefore this header authenticates the digest commitment made by the Worker;
 * it is NOT an end-to-end body integrity verification between Meta and PocketBase.
 * A compromised Cloudflare Worker could substitute a different body while sending
 * a valid signature — this is consistent with the project threat model, in which
 * the Worker is a trusted component.
 *
 * ─── TIMESTAMP / REPLAY HANDLING ─────────────────────────────────────────────
 * Timestamps outside ±300 seconds (5 minutes) of server time are rejected.
 * The Cloudflare Worker generates a fresh timestamp on every forwarding attempt.
 * No replay cache is maintained; the window provides practical protection against
 * replayed captured requests. A formal replay cache can be added in a future phase
 * if required.
 *
 * ─── PHASE B SCOPE ───────────────────────────────────────────────────────────
 * - Records inbound messages (entry[].changes[].value.messages[])
 * - Records status updates   (entry[].changes[].value.statuses[])
 * - Records unsupported events with best-effort dedup_key
 * - Deduplication: application-level check + database UNIQUE index (race-safe)
 * - matched_user is NOT populated in Phase B
 * - No user matching, no replies, no business logic, no conversational actions
 *
 * ─── PRODUCTION RELIABILITY NOTE (unresolved until Phase C) ──────────────────
 * The Phase A Cloudflare Worker currently returns HTTP 200 to Meta even when
 * PocketBase responds with a non-2xx status. This means events forwarded during
 * PocketBase downtime or errors are NOT retried by Meta and may be lost.
 * Phase C must change the Worker to return HTTP 5xx to Meta on PocketBase
 * forwarding failures so Meta's retry mechanism can recover missed events.
 * Phase B deduplication must be validated first before enabling Worker retries.
 *
 * ─── TRUST BOUNDARY ─────────────────────────────────────────────────────────
 * PocketBase superusers and anyone with direct filesystem access to pb_data/data.db
 * are inside the trust boundary and can read the stored HMAC key via the admin UI
 * or direct database inspection. Application admin-role users cannot access the
 * whatsapp_server_secrets collection via the REST API (all rules are null).
 * This is identical to the trust boundary for all other project secrets.
 */

routerAdd("POST", "/api/whatsapp/webhook", (e) => {

  // ── Constants ─────────────────────────────────────────────────────────────
  const COLLECTION          = "whatsapp_webhook_events";
  const SECRETS_COLL        = "whatsapp_server_secrets";
  const SECRET_KEY          = "wa_internal_forward_secret";
  const TIMESTAMP_WINDOW_SEC = 300;   // ±5 minutes
  const ts                  = new Date().toISOString();

  // ── Helper: mask phone number for safe logging ────────────────────────────
  // Format: first 4 chars + **** (matches existing OTP hook convention)
  function maskPhone(phone) {
    const s = String(phone || "");
    if (s.length <= 4) return "****";
    return s.slice(0, 4) + "****";
  }

  // ── Helper: dedup_key for inbound messages ────────────────────────────────
  function messageDedupKey(msgId) {
    return msgId ? "msg:" + String(msgId) : "";
  }

  // ── Helper: dedup_key for status updates ─────────────────────────────────
  // Combines the Meta message ID with Meta's delivery status string so that
  // each status transition (sent → delivered → read) has its own unique key.
  function statusDedupKey(msgId, deliveryStatus) {
    if (!msgId) return "";
    return "st:" + String(msgId) + ":" + String(deliveryStatus || "");
  }

  // ── Helper: best-effort dedup_key for unsupported events ─────────────────
  // Attempts to find a stable Meta identifier in the following priority order:
  //   1. A message ID in value.messages[0] (if somehow present)
  //   2. A status ID + status in value.statuses[0]
  //   3. entry_id + change field (stable for the same account-level event on retry)
  //   4. "" if no stable identifier exists (these events are stored but not deduped)
  function unsupportedDedupKey(change, entryId) {
    const value    = change.value || {};
    const messages = value.messages;
    const statuses = value.statuses;

    if (Array.isArray(messages) && messages.length > 0 && messages[0].id) {
      return "msg:" + String(messages[0].id);
    }
    if (Array.isArray(statuses) && statuses.length > 0 && statuses[0].id) {
      return "st:" + String(statuses[0].id) + ":" + String(statuses[0].status || "");
    }
    if (entryId && change.field) {
      // entry_id (WhatsApp Business Account ID) + field name is stable across
      // Meta retries of the same account-level event.
      return "unsup:" + String(entryId) + ":" + String(change.field);
    }
    return "";
  }

  // ── Helper: application-level duplicate check ─────────────────────────────
  // Returns true if a record with this dedup_key already exists.
  // An empty dedup_key always returns false (unsupported events with no stable ID
  // are never considered duplicates at application level).
  // The database UNIQUE index is the race-safe enforcement layer for non-empty keys.
  function isDuplicate(dedupKey) {
    if (!dedupKey) return false;
    try {
      $app.findFirstRecordByFilter(
        COLLECTION,
        "dedup_key = {:k}",
        { k: dedupKey }
      );
      return true;  // record found — this is a duplicate delivery
    } catch (_) {
      return false; // not found — proceed to insert
    }
  }

  // ── Helper: save a webhook event record ──────────────────────────────────
  // Only sets fields with non-empty values to avoid invalid select values.
  function saveEvent(fields) {
    const coll = $app.findCollectionByNameOrId(COLLECTION);
    const rec  = new Record(coll);

    rec.set("event_type", fields.event_type);
    if (fields.direction)     rec.set("direction",     fields.direction);
    if (fields.from_phone)    rec.set("from_phone",    fields.from_phone);
    if (fields.wa_message_id) rec.set("wa_message_id", fields.wa_message_id);
    if (fields.dedup_key)     rec.set("dedup_key",     fields.dedup_key);
    if (fields.status)        rec.set("status",        fields.status);
    if (fields.payload)       rec.set("payload",       fields.payload);
    if (fields.error_detail)  rec.set("error_detail",  fields.error_detail);

    $app.save(rec);
    return rec;
  }

  // ── Outer error boundary ──────────────────────────────────────────────────
  try {

    // ── Step 1: Read all three authentication headers — BEFORE parsing body ─
    // e.request.header is the Go http.Header object available on the raw request.
    // Reading headers here avoids any body parsing for unauthenticated callers.
    const tsHeader     = String((e.request.header && e.request.header.get("X-WhatsApp-Timestamp"))   || "");
    const digestHeader = String((e.request.header && e.request.header.get("X-WhatsApp-Body-Digest")) || "");
    const sigHeader    = String((e.request.header && e.request.header.get("X-WhatsApp-Signature"))   || "");

    // ── Step 2: Load HMAC key from locked collection — BEFORE parsing body ──
    // $app.findFirstRecordByFilter() is server-side; bypasses all collection
    // API rules. The secret value is never logged or returned in any response.
    let storedSecret = "";
    try {
      storedSecret = $app.findFirstRecordByFilter(
        SECRETS_COLL,
        "key = {:k}",
        { k: SECRET_KEY }
      ).getString("value");
    } catch (_) {}

    // ── Step 3: Reject if secret absent or empty ─────────────────────────────
    if (!storedSecret) {
      $app.logger().error(
        "whatsapp webhook: wa_internal_forward_secret not found in whatsapp_server_secrets — endpoint cannot authenticate",
        "ts", ts
      );
      return e.json(500, { error: "server_misconfigured" });
    }

    // ── Step 4: Validate timestamp format ────────────────────────────────────
    // Must be a non-empty plain decimal integer string with no decimal point.
    // parseInt() then re-stringify must round-trip exactly, rejecting floats,
    // hex strings (0x...), leading zeros, empty strings, and non-numeric input.
    // Value must also be positive.
    const tsNum = parseInt(tsHeader, 10);
    if (!tsHeader || isNaN(tsNum) || String(tsNum) !== tsHeader || tsNum <= 0) {
      $app.logger().warn(
        "whatsapp webhook: missing or malformed X-WhatsApp-Timestamp header",
        "ts", ts
      );
      return e.json(401, { error: "unauthorized" });
    }

    // ── Step 5: Reject timestamps outside ±300 second window ─────────────────
    // Both Cloudflare Workers and SiteGround servers use NTP synchronisation.
    // A sustained drift of >5 minutes would indicate a broader infrastructure
    // problem rather than a normal operating condition.
    // age_sec is logged for diagnosing clock skew; timestamp value is not logged.
    const nowSec = Math.floor(Date.now() / 1000);
    const ageSec = Math.abs(nowSec - tsNum);
    if (ageSec > TIMESTAMP_WINDOW_SEC) {
      $app.logger().warn(
        "whatsapp webhook: timestamp outside ±5 minute window — possible replay or clock skew",
        "ts",      ts,
        "age_sec", String(ageSec)
      );
      return e.json(401, { error: "unauthorized" });
    }

    // ── Step 6: Reject if digest or signature headers are absent ─────────────
    if (!digestHeader || !sigHeader) {
      $app.logger().warn(
        "whatsapp webhook: missing X-WhatsApp-Body-Digest or X-WhatsApp-Signature header",
        "ts",         ts,
        "has_digest", String(!!digestHeader),
        "has_sig",    String(!!sigHeader)
      );
      return e.json(401, { error: "unauthorized" });
    }

    // ── Step 7: Recompute expected HMAC-SHA256 signature ─────────────────────
    // $security.hs256(message, key) → lowercase hex string
    //   Go:  crypto/hmac + SHA-256, hex-encoded via fmt.Sprintf("%x", ...)
    //   CF:  crypto.subtle.sign("HMAC", key, data) + Uint8Array → hex
    // Both produce identical lowercase hex for the same key and message.
    //
    // signatureInput = timestamp + "." + bodyDigest
    // The "." separator prevents boundary ambiguity between the two fields.
    //
    // Neither the stored secret, the received signature, nor the computed
    // expected signature is logged at any point in this function.
    const signatureInput = tsHeader + "." + digestHeader;
    const expectedSig    = $security.hs256(signatureInput, storedSecret);

    // ── Step 8: Constant-time comparison ─────────────────────────────────────
    // $security.equal() calls Go's subtle.ConstantTimeCompare, preventing
    // timing-based attacks that could leak information about the secret.
    if (!$security.equal(sigHeader, expectedSig)) {
      $app.logger().warn(
        "whatsapp webhook: HMAC-SHA256 signature invalid — request not from Cloudflare Worker",
        "ts",         ts,
        "has_ts",     String(!!tsHeader),
        "has_digest", String(!!digestHeader),
        "has_sig",    String(!!sigHeader)
      );
      return e.json(401, { error: "unauthorized" });
    }

    // ── Step 9: Parse request — caller is now authenticated ──────────────────
    // e.requestInfo() is only called after all authentication checks pass.
    // An unauthenticated caller never causes the body to be parsed.
    const info = e.requestInfo();

    // ── Step 10: Validate payload structure ───────────────────────────────────
    const body = info.body;

    if (!body || typeof body !== "object" || Array.isArray(body)) {
      $app.logger().warn(
        "whatsapp webhook: body is null, not an object, or unparseable",
        "ts", ts
      );
      return e.json(400, { error: "invalid_json" });
    }

    if (body.object !== "whatsapp_business_account") {
      $app.logger().warn(
        "whatsapp webhook: unexpected object type in payload",
        "ts",     ts,
        "object", String(body.object || "(missing)")
      );
      return e.json(400, { error: "unexpected_structure" });
    }

    const entries = body.entry;
    if (!Array.isArray(entries) || entries.length === 0) {
      $app.logger().warn("whatsapp webhook: entry array missing or empty", "ts", ts);
      return e.json(400, { error: "empty_entry" });
    }

    // ── Step 11: Process each entry → change → individual event ──────────────
    let processed = 0;
    let duplicates = 0;
    let ignored    = 0;

    for (const entry of entries) {
      const entryId = String(entry.id || "");
      const changes = Array.isArray(entry.changes) ? entry.changes : [];

      for (const change of changes) {
        const value    = change.value || {};
        const messages = Array.isArray(value.messages) ? value.messages : [];
        const statuses = Array.isArray(value.statuses) ? value.statuses : [];

        // ── Inbound messages ──────────────────────────────────────────────
        for (const msg of messages) {
          const msgId     = String(msg.id   || "");
          const fromPhone = String(msg.from  || "");
          const msgType   = String(msg.type  || "unknown");
          const dedupKey  = messageDedupKey(msgId);

          if (isDuplicate(dedupKey)) {
            $app.logger().info(
              "whatsapp webhook: duplicate inbound message — skipped",
              "ts",            ts,
              "msg_id_prefix", msgId.slice(0, 12),
              "msg_type",      msgType
            );
            duplicates++;
            continue;
          }

          try {
            saveEvent({
              event_type:    "message",
              direction:     "inbound",
              from_phone:    fromPhone,
              wa_message_id: msgId,
              dedup_key:     dedupKey,
              status:        "received",
              payload: {
                entry_id: entryId,
                message:  msg,
                metadata: value.metadata || {},
              },
            });
            $app.logger().info(
              "whatsapp webhook: inbound message recorded",
              "ts",       ts,
              "msg_type", msgType,
              "from",     maskPhone(fromPhone)
            );
            processed++;
          } catch (err) {
            const errStr = String(err);
            if (errStr.includes("UNIQUE constraint failed")) {
              // Concurrent duplicate — the database UNIQUE index blocked the second insert.
              // This is the expected race-safe outcome.
              $app.logger().info(
                "whatsapp webhook: concurrent duplicate inbound message blocked by UNIQUE index",
                "ts", ts
              );
              duplicates++;
            } else {
              $app.logger().error(
                "whatsapp webhook: failed to save inbound message",
                "ts",    ts,
                "error", errStr
              );
              // Continue processing remaining messages; do not abort the entire request.
            }
          }
        }

        // ── Status updates ────────────────────────────────────────────────
        // statuses[].id    = the original outbound message's wamid
        // statuses[].status = Meta delivery status: sent/delivered/read/failed
        for (const st of statuses) {
          const msgId          = String(st.id           || "");
          const deliveryStatus = String(st.status        || "");
          const recipientId    = String(st.recipient_id  || "");
          const dedupKey       = statusDedupKey(msgId, deliveryStatus);

          if (isDuplicate(dedupKey)) {
            $app.logger().info(
              "whatsapp webhook: duplicate status update — skipped",
              "ts",              ts,
              "msg_id_prefix",   msgId.slice(0, 12),
              "delivery_status", deliveryStatus
            );
            duplicates++;
            continue;
          }

          try {
            saveEvent({
              event_type:    "status_update",
              direction:     "status",
              from_phone:    recipientId,
              wa_message_id: msgId,
              dedup_key:     dedupKey,
              status:        "received",
              payload: {
                entry_id: entryId,
                status:   st,
                metadata: value.metadata || {},
              },
            });
            $app.logger().info(
              "whatsapp webhook: status update recorded",
              "ts",              ts,
              "delivery_status", deliveryStatus
            );
            processed++;
          } catch (err) {
            const errStr = String(err);
            if (errStr.includes("UNIQUE constraint failed")) {
              $app.logger().info(
                "whatsapp webhook: concurrent duplicate status update blocked by UNIQUE index",
                "ts", ts
              );
              duplicates++;
            } else {
              $app.logger().error(
                "whatsapp webhook: failed to save status update",
                "ts",    ts,
                "error", errStr
              );
            }
          }
        }

        // ── Unsupported events ────────────────────────────────────────────
        // A change whose value contains neither messages[] nor statuses[].
        // Recorded with event_type = unsupported and status = ignored.
        // Best-effort dedup_key prevents duplicate storage on Meta retry.
        if (messages.length === 0 && statuses.length === 0) {
          const field    = String(change.field || "");
          const dedupKey = unsupportedDedupKey(change, entryId);

          if (dedupKey && isDuplicate(dedupKey)) {
            $app.logger().info(
              "whatsapp webhook: duplicate unsupported event — skipped",
              "ts",        ts,
              "field",     field,
              "dedup_key", dedupKey
            );
            duplicates++;
            continue;
          }

          try {
            saveEvent({
              event_type: "unsupported",
              dedup_key:  dedupKey,
              status:     "ignored",
              payload: {
                entry_id: entryId,
                field:    field,
                value:    value,
              },
            });
            $app.logger().info(
              "whatsapp webhook: unsupported event recorded",
              "ts",            ts,
              "field",         field,
              "has_dedup_key", String(!!dedupKey)
            );
            ignored++;
          } catch (err) {
            const errStr = String(err);
            if (errStr.includes("UNIQUE constraint failed")) {
              $app.logger().info(
                "whatsapp webhook: concurrent duplicate unsupported event blocked by UNIQUE index",
                "ts", ts
              );
              duplicates++;
            } else {
              $app.logger().error(
                "whatsapp webhook: failed to save unsupported event",
                "ts",    ts,
                "field", field,
                "error", errStr
              );
            }
          }
        }

      } // end change loop
    } // end entry loop

    $app.logger().info(
      "whatsapp webhook: processing complete",
      "ts",         ts,
      "processed",  processed,
      "duplicates", duplicates,
      "ignored",    ignored
    );

    return e.json(200, {
      ok:         true,
      processed:  processed,
      duplicates: duplicates,
      ignored:    ignored,
    });

  } catch (err) {
    // Outer boundary: catches anything not caught by the per-event try/catch blocks.
    // This should not happen in normal operation.
    $app.logger().error(
      "whatsapp webhook: unexpected internal error",
      "ts",    ts,
      "error", String(err),
      "stack", (err && err.stack) ? String(err.stack) : ""
    );
    return e.json(500, { error: "internal_error" });
  }

});
