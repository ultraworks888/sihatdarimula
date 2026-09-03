// Allow admin/superadmin to list, view, and update the ai_settings record
// so the frontend admin page can write the Gemini key directly via the SDK.
// createRule and deleteRule stay null (server-side only).
migrate((app) => {
  const col = app.findCollectionByNameOrId("ai_settings");
  col.listRule   = "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'";
  col.viewRule   = "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'";
  col.updateRule = "@request.auth.role = 'admin' || @request.auth.role = 'superadmin'";
  col.createRule = null;
  col.deleteRule = null;
  app.save(col);
}, (app) => {
  const col = app.findCollectionByNameOrId("ai_settings");
  col.listRule   = null;
  col.viewRule   = null;
  col.updateRule = null;
  app.save(col);
});
