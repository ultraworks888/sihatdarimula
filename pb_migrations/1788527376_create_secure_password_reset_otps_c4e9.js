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
    indexes: [
      "CREATE INDEX idx_password_reset_phone ON password_reset_otps (phone, created)",
      "CREATE INDEX idx_password_reset_user ON password_reset_otps (user, created)",
      "CREATE INDEX idx_password_reset_status ON password_reset_otps (status, is_used)",
    ],
    fields: [
      new RelationField({
        name: "user",
        collectionId: users.id,
        required: true,
        maxSelect: 1,
        cascadeDelete: true,
        hidden: true,
      }),
      new TextField({
        name: "phone",
        required: true,
        max: 20,
        hidden: true,
      }),
      new TextField({
        name: "otp_hash",
        required: true,
        max: 64,
        hidden: true,
      }),
      new TextField({
        name: "otp_salt",
        required: true,
        max: 64,
        hidden: true,
      }),
      new DateField({
        name: "expires_at",
        required: true,
        hidden: true,
      }),
      new NumberField({
        name: "failed_attempts",
        min: 0,
        max: 5,
        onlyInt: true,
        hidden: true,
      }),
      new DateField({
        name: "last_attempt_at",
        hidden: true,
      }),
      new SelectField({
        name: "status",
        required: true,
        values: ["pending", "active", "failed", "invalidated", "expired", "locked", "used"],
        maxSelect: 1,
        hidden: true,
      }),
      new BoolField({
        name: "is_used",
        hidden: true,
      }),
      new AutodateField({
        name: "created",
        onCreate: true,
        onUpdate: false,
      }),
    ],
  });
  app.save(resets);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("password_reset_otps"));
});
