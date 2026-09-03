/**
 * My Healthy Start — WhatsApp Webhook Verification Gateway
 * Cloudflare Worker · Phase A
 *
 * SECURITY GATEWAY ONLY.
 * This Worker contains NO business logic, NO user matching, NO application logic,
 * NO WhatsApp conversational logic, and NO duplication of PocketBase functionality.
 *
 * Responsibilities:
 *   GET  — Respond to Meta's webhook verification challenge (hub.challenge / hub.verify_token)
 *   POST — Verify X-Hub-Signature-256 over ORIGINAL raw bytes, then forward to PocketBase
 *
 * Secrets (NEVER in source — set via `wrangler secret put`):
 *   META_APP_SECRET            — Meta app secret, used to verify X-Hub-Signature-256
 *   WA_WEBHOOK_VERIFY_TOKEN    — The token Meta sends in GET verification requests
 *   WA_INTERNAL_FORWARD_SECRET — HMAC-SHA256 signing key for authenticating forwarded requests to PocketBase
 *
 * Non-secret vars (in wrangler.toml [vars]):
 *   POCKETBASE_WEBHOOK_URL     — The PocketBase endpoint that receives verified events
 */

export default {
  async fetch(request, env) {
    const timestamp = new Date().toISOString();
    const method = request.method;

    if (method === 'GET') {
      return handleVerification(request, env, timestamp);
    }

    if (method === 'POST') {
      return handleWebhook(request, env, timestamp);
    }

    return new Response('Method Not Allowed', { status: 405 });
  },
};


// ─────────────────────────────────────────────────────────────────────────────
// GET — Meta webhook verification challenge
// ─────────────────────────────────────────────────────────────────────────────
// Meta sends:
//   GET /webhook?hub.mode=subscribe&hub.verify_token=<token>&hub.challenge=<challenge>
// We must return the raw hub.challenge string with HTTP 200 if the token matches.

async function handleVerification(request, env, timestamp) {
  const url       = new URL(request.url);
  const mode      = url.searchParams.get('hub.mode');
  const token     = url.searchParams.get('hub.verify_token');
  const challenge = url.searchParams.get('hub.challenge');

  // All three parameters are required
  if (!mode || !token || !challenge) {
    console.log(`[${timestamp}] GET rejected: missing hub parameters (mode=${mode}, token_present=${!!token}, challenge_present=${!!challenge})`);
    return new Response('Bad Request', { status: 400 });
  }

  // Only 'subscribe' mode is valid for webhook registration
  if (mode !== 'subscribe') {
    console.log(`[${timestamp}] GET rejected: unexpected hub.mode="${mode}"`);
    return new Response('Forbidden', { status: 403 });
  }

  // Verify the token is configured
  const expectedToken = env.WA_WEBHOOK_VERIFY_TOKEN;
  if (!expectedToken) {
    console.error(`[${timestamp}] GET rejected: WA_WEBHOOK_VERIFY_TOKEN secret is not set`);
    return new Response('Internal Server Error', { status: 500 });
  }

  // Timing-safe comparison — never log the received or expected token value
  const tokenMatches = await timingSafeEqual(token, expectedToken);
  if (!tokenMatches) {
    console.log(`[${timestamp}] GET rejected: verify_token mismatch`);
    return new Response('Forbidden', { status: 403 });
  }

  // Token verified — echo the challenge exactly as received
  console.log(`[${timestamp}] GET accepted: webhook verification successful`);
  return new Response(challenge, {
    status: 200,
    headers: { 'Content-Type': 'text/plain' },
  });
}


// ─────────────────────────────────────────────────────────────────────────────
// POST — Signature verification and forwarding
// ─────────────────────────────────────────────────────────────────────────────
// Step order is strict and intentional:
//   1. Read raw body bytes (BEFORE any parsing)
//   2. Read X-Hub-Signature-256 header
//   3. Verify HMAC-SHA256 over the ORIGINAL bytes
//   4. Only after verification passes: forward to PocketBase

async function handleWebhook(request, env, timestamp) {

  // ── Step 1: Read the raw body FIRST, before any parsing ──────────────────
  // request.arrayBuffer() gives the exact bytes as received from Meta.
  // These are the bytes that Meta signed. Any re-encoding would break the HMAC.
  let rawBody;
  try {
    rawBody = await request.arrayBuffer();
  } catch (err) {
    console.error(`[${timestamp}] POST rejected: failed to read request body — ${err.message}`);
    return new Response('Bad Request', { status: 400 });
  }

  if (rawBody.byteLength === 0) {
    console.log(`[${timestamp}] POST rejected: empty body`);
    return new Response('Bad Request', { status: 400 });
  }

  // ── Step 2: Read the signature header ────────────────────────────────────
  // Done after securing raw bytes — header reads do not affect body bytes
  const signatureHeader = request.headers.get('x-hub-signature-256');

  if (!signatureHeader) {
    console.log(`[${timestamp}] POST rejected: missing X-Hub-Signature-256 header`);
    return new Response('Forbidden', { status: 403 });
  }

  if (!signatureHeader.startsWith('sha256=')) {
    console.log(`[${timestamp}] POST rejected: malformed X-Hub-Signature-256 (does not start with "sha256=")`);
    return new Response('Forbidden', { status: 403 });
  }

  // ── Step 3: Verify HMAC-SHA256 over the ORIGINAL raw bytes ───────────────
  const appSecret = env.META_APP_SECRET;
  if (!appSecret) {
    console.error(`[${timestamp}] POST rejected: META_APP_SECRET secret is not set`);
    return new Response('Internal Server Error', { status: 500 });
  }

  let signatureValid;
  try {
    signatureValid = await verifyHmacSha256(rawBody, signatureHeader, appSecret);
  } catch (err) {
    console.error(`[${timestamp}] POST rejected: signature verification threw an error — ${err.message}`);
    return new Response('Internal Server Error', { status: 500 });
  }

  if (!signatureValid) {
    console.log(`[${timestamp}] POST rejected: X-Hub-Signature-256 verification failed — body length ${rawBody.byteLength} bytes`);
    return new Response('Forbidden', { status: 403 });
  }

  // ── Step 4: Signature verified — compute forwarding auth and forward ────────
  // The ORIGINAL rawBody ArrayBuffer is forwarded unchanged.
  // Three HMAC-SHA256 authentication headers replace the old shared-secret header:
  //   X-WhatsApp-Timestamp   — current Unix seconds (decimal integer string)
  //   X-WhatsApp-Body-Digest — hex SHA-256 of the original raw bytes (same ArrayBuffer
  //                            used for Meta verification above — no re-encoding)
  //   X-WhatsApp-Signature   — hex HMAC-SHA256(timestamp + "." + bodyDigest, secret)
  console.log(`[${timestamp}] POST accepted: X-Hub-Signature-256 verified — body ${rawBody.byteLength} bytes — forwarding to PocketBase`);

  const pbUrl = env.POCKETBASE_WEBHOOK_URL;
  if (!pbUrl) {
    console.error(`[${timestamp}] Forward failed: POCKETBASE_WEBHOOK_URL is not configured`);
    return new Response('Internal Server Error', { status: 500 });
  }

  const internalSecret = env.WA_INTERNAL_FORWARD_SECRET;
  if (!internalSecret) {
    console.error(`[${timestamp}] Forward failed: WA_INTERNAL_FORWARD_SECRET is not configured`);
    return new Response('Internal Server Error', { status: 500 });
  }

  // Compute the three forwarding authentication headers.
  // rawBody is the SAME ArrayBuffer used for Meta HMAC verification above.
  // No intermediate string conversion takes place before SHA-256 hashing.
  let forwardingAuth;
  try {
    forwardingAuth = await computeForwardingAuth(rawBody, internalSecret);
  } catch (err) {
    console.error(`[${timestamp}] Forward failed: could not compute forwarding signature — ${err.message}`);
    return new Response('Internal Server Error', { status: 500 });
  }

  // ── Forward to PocketBase ─────────────────────────────────────────────────
  let pbResponse;
  try {
    pbResponse = await fetch(pbUrl, {
      method: 'POST',
      headers: {
        'Content-Type':               'application/json',
        'X-WhatsApp-Timestamp':       forwardingAuth.timestamp,
        'X-WhatsApp-Body-Digest':     forwardingAuth.bodyDigest,
        'X-WhatsApp-Signature':       forwardingAuth.signature,
      },
      // rawBody is the ORIGINAL ArrayBuffer — bytes are not altered in transit
      body: rawBody,
    });
  } catch (err) {
    // Network error, DNS failure, or timeout
    // Return 200 to Meta intentionally:
    //   - Returning 5xx would trigger Meta's automatic retry logic
    //   - Retries without deduplication (Phase B) would cause duplicate processing
    //   - The event is logged; recovery must be handled manually in Phase B
    console.error(`[${timestamp}] Forward failed: PocketBase unreachable — ${err.message}`);
    console.log(`[${timestamp}] Returning 200 to Meta to suppress automatic retry (event not yet processable in Phase A)`);
    return new Response('OK', { status: 200 });
  }

  if (!pbResponse.ok) {
    // PocketBase returned a non-2xx status (404 expected in Phase A before endpoint exists)
    // Return 200 to Meta for same reason as above
    const diagnosticBody = await pbResponse.clone().text();
    console.error(`[${timestamp}] Forward failed: PocketBase responded HTTP ${pbResponse.status}`);
    console.error(
      '[PocketBase diagnostic]',
      'status',        pbResponse.status,
      'status_text',   pbResponse.statusText,
      'content_type',  pbResponse.headers.get('content-type') || '',
      'server',        pbResponse.headers.get('server')       || '',
      'cf_ray',        pbResponse.headers.get('cf-ray')       || '',
      'location',      pbResponse.headers.get('location')     || '',
      'body_preview',  diagnosticBody.slice(0, 500),
    );
    console.log(`[${timestamp}] Returning 200 to Meta to suppress automatic retry`);
    return new Response('OK', { status: 200 });
  }

  // The PocketBase hook always returns exactly 200 on success.
  // HTTP 202 is 2xx so pbResponse.ok is true, but it is not the expected response —
  // it indicates an intermediate layer (SiteGround proxy, nginx, etc.) intercepted the
  // request before it reached the hook. Capture full downstream headers and body so the
  // source of the non-200 2xx can be identified. Worker behaviour toward Meta is unchanged.
  if (pbResponse.status !== 200) {
    const diagnosticBody = await pbResponse.clone().text();
    console.warn(`[${timestamp}] Forward: PocketBase responded HTTP ${pbResponse.status} (expected 200 — possible proxy intercept)`);
    console.warn(
      '[PocketBase diagnostic]',
      'status',        pbResponse.status,
      'status_text',   pbResponse.statusText,
      'content_type',  pbResponse.headers.get('content-type') || '',
      'server',        pbResponse.headers.get('server')       || '',
      'cf_ray',        pbResponse.headers.get('cf-ray')       || '',
      'location',      pbResponse.headers.get('location')     || '',
      'body_preview',  diagnosticBody.slice(0, 500),
    );
  } else {
    console.log(`[${timestamp}] Forward success: PocketBase responded HTTP ${pbResponse.status}`);
  }
  return new Response('OK', { status: 200 });
}


// ─────────────────────────────────────────────────────────────────────────────
// Cryptographic helpers
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Verify an HMAC-SHA256 signature using the WebCrypto API.
 *
 * Uses crypto.subtle.verify() which is timing-safe by WebCrypto specification.
 * The HMAC is computed over the ORIGINAL raw bytes (ArrayBuffer) received from Meta.
 * No re-encoding, no JSON parsing, no string conversion before this point.
 *
 * @param {ArrayBuffer} rawBody         - The unmodified request body bytes
 * @param {string}      signatureHeader - The X-Hub-Signature-256 value (e.g. "sha256=abc123")
 * @param {string}      secret          - The META_APP_SECRET
 * @returns {Promise<boolean>}
 */
async function verifyHmacSha256(rawBody, signatureHeader, secret) {
  const encoder = new TextEncoder();

  // Import the app secret as an HMAC-SHA256 key
  // 'verify' usage — cannot be extracted, cannot be used for signing
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,       // not extractable
    ['verify'],
  );

  // Extract the hex signature from "sha256=<64 hex chars>"
  const hexSignature = signatureHeader.slice(7); // strips "sha256="
  const expectedBytes = hexToBytes(hexSignature);
  if (!expectedBytes) {
    // Hex decoding failed — malformed signature
    return false;
  }

  // crypto.subtle.verify() performs a constant-time comparison internally.
  // It computes HMAC-SHA256(key, rawBody) and compares to expectedBytes in one atomic step.
  // This is the correct, timing-safe way to verify a webhook signature.
  return await crypto.subtle.verify(
    'HMAC',
    key,
    expectedBytes, // bytes Meta claims are the correct HMAC
    rawBody,       // the original bytes we received from Meta
  );
}

/**
 * Decode a hex string to a Uint8Array.
 * Returns null if input is not valid lowercase hex.
 *
 * @param {string} hex
 * @returns {Uint8Array|null}
 */
function hexToBytes(hex) {
  if (typeof hex !== 'string' || hex.length % 2 !== 0) return null;
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    const byte = parseInt(hex.slice(i, i + 2), 16);
    if (isNaN(byte)) return null;
    bytes[i / 2] = byte;
  }
  return bytes;
}

/**
 * Compute the three HMAC-SHA256 authentication headers for PocketBase forwarding.
 *
 * IMPORTANT: rawBody is the same ArrayBuffer obtained via request.arrayBuffer()
 * earlier in handleWebhook. It has already been used for Meta X-Hub-Signature-256
 * verification. It is reused here directly — there is no string conversion,
 * no TextDecoder, no JSON.parse, and no re-encoding before SHA-256 hashing.
 * The body digest represents exactly the bytes received from Meta.
 *
 * Algorithm:
 *   bodyDigest     = hex(SHA-256(rawBody))          ← directly over the ArrayBuffer
 *   signatureInput = nowSeconds + "." + bodyDigest
 *   signature      = hex(HMAC-SHA256(WA_INTERNAL_FORWARD_SECRET, signatureInput))
 *
 * PocketBase verifies using $security.hs256(signatureInput, storedSecret), which
 * calls Go's crypto/hmac + SHA-256 and produces an identical lowercase hex string
 * for the same key and message.
 *
 * TextEncoder is used only for the ASCII signatureInput string and the secret
 * key material — both are safe from encoding ambiguity.
 *
 * @param {ArrayBuffer} rawBody        - The original Meta request bytes (unmodified)
 * @param {string}      internalSecret - WA_INTERNAL_FORWARD_SECRET value
 * @returns {Promise<{timestamp: string, bodyDigest: string, signature: string}>}
 */
async function computeForwardingAuth(rawBody, internalSecret) {
  const encoder    = new TextEncoder();
  const nowSeconds = String(Math.floor(Date.now() / 1000));

  // SHA-256 directly over the original ArrayBuffer — no intermediate conversion.
  const digestBuffer = await crypto.subtle.digest('SHA-256', rawBody);
  const bodyDigest   = bytesToHex(new Uint8Array(digestBuffer));

  // HMAC-SHA256 over "timestamp.bodyDigest".
  // The "." separator prevents field boundary ambiguity.
  const signatureInput = nowSeconds + '.' + bodyDigest;
  const hmacKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(internalSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sigBuffer = await crypto.subtle.sign('HMAC', hmacKey, encoder.encode(signatureInput));
  const signature = bytesToHex(new Uint8Array(sigBuffer));

  return { timestamp: nowSeconds, bodyDigest, signature };
}

/**
 * Convert a Uint8Array to a lowercase hex string.
 * Used for both SHA-256 body digest and HMAC-SHA256 signature output.
 *
 * @param {Uint8Array} bytes
 * @returns {string}
 */
function bytesToHex(bytes) {
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
}


/**
 * Timing-safe string comparison using HMAC as a fixed-length equaliser.
 *
 * Both strings are signed with a freshly generated ephemeral key.
 * The two 32-byte HMAC-SHA256 outputs are compared bit-by-bit using
 * XOR accumulation — this never short-circuits on a mismatch.
 *
 * Using an ephemeral key means the HMAC values are unpredictable to
 * an attacker even if they know one of the input strings.
 *
 * @param {string} a
 * @param {string} b
 * @returns {Promise<boolean>}
 */
async function timingSafeEqual(a, b) {
  const encoder = new TextEncoder();

  // Generate a random single-use key — discarded after this call
  const epKey = await crypto.subtle.generateKey(
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  // Sign both strings with the same ephemeral key
  const [sigA, sigB] = await Promise.all([
    crypto.subtle.sign('HMAC', epKey, encoder.encode(a)),
    crypto.subtle.sign('HMAC', epKey, encoder.encode(b)),
  ]);

  // Both outputs are always 32 bytes (SHA-256 output size)
  // Compare all 32 bytes with XOR accumulation — never short-circuits
  const va = new Uint8Array(sigA);
  const vb = new Uint8Array(sigB);
  let diff = 0;
  for (let i = 0; i < va.length; i++) {
    diff |= va[i] ^ vb[i];
  }
  return diff === 0;
}
