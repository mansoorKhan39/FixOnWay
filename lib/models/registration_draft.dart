import 'enums/user_role.dart';

/// Data collected on the sign-up form, kept until the OTP is verified.
class RegistrationDraft {
  const RegistrationDraft({
    required this.role,
    required this.name,
    required this.phone,
    required this.email,
    required this.password,
  });

  final UserRole role;
  final String name;
  final String phone;
  final String email;
  final String password;
}
