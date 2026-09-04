migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  users.fields.add(new BoolField({
    name: "phone_verified",
  }));
  users.fields.add(new DateField({
    name: "phone_verified_at",
  }));
  app.save(users);

  const verifications = new Collection({
    name: "phone_verification_otps",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
  });

  verifications.fields.add(new RelationField({
    name: "user",
    collectionId: users.id,
    required: true,
    maxSelect: 1,
    cascadeDelete: true,
    hidden: true,
  }));
  verifications.fields.add(new TextField({
    name: "phone",
    required: true,
    max: 20,
    hidden: true,
  }));
  verifications.fields.add(new TextField({
    name: "otp_hash",
    required: true,
    max: 64,
    hidden: true,
  }));
  verifications.fields.add(new TextField({
    name: "otp_salt",
    required: true,
    max: 64,
    hidden: true,
  }));
  verifications.fields.add(new DateField({
    name: "expires_at",
    required: true,
    hidden: true,
  }));
  verifications.fields.add(new NumberField({
    name: "failed_attempts",
    min: 0,
    max: 5,
    onlyInt: true,
    hidden: true,
  }));
  verifications.fields.add(new DateField({
    name: "last_attempt_at",
    hidden: true,
  }));
  verifications.fields.add(new SelectField({
    name: "status",
    required: true,
    values: ["pending", "active", "failed", "invalidated", "expired", "locked", "used"],
    maxSelect: 1,
    hidden: true,
  }));
  verifications.fields.add(new BoolField({
    name: "is_used",
    hidden: true,
  }));
  verifications.fields.add(new AutodateField({
    name: "created",
    onCreate: true,
    onUpdate: false,
  }));
  verifications.addIndex(
    "idx_phone_verification_owner",
    false,
    "user, phone, created",
    ""
  );
  verifications.addIndex(
    "idx_phone_verification_status",
    false,
    "status, is_used",
    ""
  );
  app.save(verifications);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("phone_verification_otps"));

  const users = app.findCollectionByNameOrId("users");
  users.fields.removeByName("phone_verified_at");
  users.fields.removeByName("phone_verified");
  app.save(users);
});
