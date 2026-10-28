enum UserRole {
  customer,
  mechanic,
  admin;

  String get label => switch (this) {
        UserRole.customer => 'Customer',
        UserRole.mechanic => 'Mechanic',
        UserRole.admin => 'Admin',
      };
}
