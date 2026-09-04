migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  users.addIndex(
    "idx_users_verified_phone_unique",
    true,
    "phone",
    "phone_verified = true AND phone != ''"
  );
  app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId("users");
  users.removeIndex("idx_users_verified_phone_unique");
  app.save(users);
});
