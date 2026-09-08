// Keep the nontransactional App handle available to pooled cron executors.
// This is not a process-local counter; all admission evidence stays in SQLite.
onBootstrap(function(e) {
  e.app.store().set("maintenance.runtimeApp", e.app);
  return e.next();
});

// Entry gate for built-in collection mutations, including multipart uploads,
// registration, auth/email operations, and batch requests. Run after PB loads
// the auth token (-1020), before endpoint authorization/body parsing (-1000+).
routerUse(new Middleware(function(e) {
  const method = e.request.method;
  if (method === "GET" || method === "HEAD" || method === "OPTIONS") return e.next();
  const path = e.request.url.path;
  if (path !== "/api/batch" && path.indexOf("/api/collections/") !== 0) return e.next();
  if (e.hasSuperuserAuth()) return e.next();
  // Keep native superuser authentication/recovery available. Resolving the
  // actual collection also handles PB's collection-id URLs without role tests.
  const parts = path.split("/");
  if (parts.length === 5 && parts[4] !== "records") {
    try {
      if (e.app.findCachedCollectionByNameOrId(parts[3]).name === "_superusers") return e.next();
    } catch (_) { /* unknown collection is not a bypass */ }
  }
  const maintenance = require(__hooks + "/maintenance.js");
  return maintenance.http(e, function() { return e.next(); }, "builtin");
}, -1015));

// Late checks at the built-in request hooks, before their persistence paths.
onRecordCreateRequest(function(e) { return require(__hooks + "/maintenance.js").builtin(e); });
onRecordUpdateRequest(function(e) { return require(__hooks + "/maintenance.js").builtin(e); });
onRecordDeleteRequest(function(e) { return require(__hooks + "/maintenance.js").builtin(e); });
onBatchRequest(function(e) { return require(__hooks + "/maintenance.js").builtin(e); });

// Password login can persist _authOrigins and send alerts in v0.29.3.
// Refresh is deliberately paused with all application session operations.
onRecordAuthRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordAuthWithPasswordRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordAuthRefreshRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordAuthWithOAuth2Request(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordAuthWithOTPRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordRequestOTPRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordRequestPasswordResetRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordConfirmPasswordResetRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordRequestVerificationRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordConfirmVerificationRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordRequestEmailChangeRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });
onRecordConfirmEmailChangeRequest(function(e) { return require(__hooks + "/maintenance.js").auth(e); });

// PB auth-alert/verification/reset mail may outlive its initiating HTTP request.
// Register independently around actual mail work; never rely on the HTTP lease.
onMailerRecordAuthAlertSend(function(e) { return require(__hooks + "/maintenance.js").mail(e); });
onMailerRecordVerificationSend(function(e) { return require(__hooks + "/maintenance.js").mail(e); });
onMailerRecordPasswordResetSend(function(e) { return require(__hooks + "/maintenance.js").mail(e); });
onMailerRecordEmailChangeSend(function(e) { return require(__hooks + "/maintenance.js").mail(e); });
onMailerRecordOTPSend(function(e) { return require(__hooks + "/maintenance.js").mail(e); });

routerAdd("GET", "/api/maintenance/status", function(e) {
  if (!e.hasSuperuserAuth()) return e.json(403, { message: "Forbidden" });
  e.response.header().set("Cache-Control", "no-store");
  return e.json(200, require(__hooks + "/maintenance.js").status(e.app));
});
