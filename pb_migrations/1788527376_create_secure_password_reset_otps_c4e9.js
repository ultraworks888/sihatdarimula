migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const resets = new Collection({
    name: "password_reset_otps",
    type: "base",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
  });

  resets.fields.add(new RelationField({
    name: "user",
    collectionId: users.id,
    required: true,
    maxSelect: 1,
    cascadeDelete: true,
    hidden: true,
  }));
  resets.fields.add(new TextField({
    name: "phone",
    required: true,
    max: 20,
    hidden: true,
  }));
  resets.fields.add(new TextField({
    name: "otp_hash",
    required: true,
    max: 64,
    hidden: true,
  }));
  resets.fields.add(new TextField({
    name: "otp_salt",
    required: true,
    max: 64,
    hidden: true,
  }));
  resets.fields.add(new DateField({
    name: "expires_at",
    required: true,
    hidden: true,
  }));
  resets.fields.add(new NumberField({
    name: "failed_attempts",
    min: 0,
    max: 5,
    onlyInt: true,
    hidden: true,
  }));
  resets.fields.add(new DateField({
    name: "last_attempt_at",
    hidden: true,
  }));
  resets.fields.add(new SelectField({
    name: "status",
    required: true,
    values: ["pending", "active", "failed", "invalidated", "expired", "locked", "used"],
    maxSelect: 1,
    hidden: true,
  }));
  resets.fields.add(new BoolField({
    name: "is_used",
    hidden: true,
  }));
  resets.fields.add(new AutodateField({
    name: "created",
    onCreate: true,
    onUpdate: false,
  }));
  resets.addIndex(
    "idx_password_reset_phone",
    false,
    "phone, created",
    ""
  );
  resets.addIndex(
    "idx_password_reset_user",
    false,
    "user, created",
    ""
  );
  resets.addIndex(
    "idx_password_reset_status",
    false,
    "status, is_used",
    ""
  );
  app.save(resets);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("password_reset_otps"));
});
