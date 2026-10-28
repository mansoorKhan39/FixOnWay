import 'enums/user_role.dart';
import 'enums/user_status.dart';
import 'enums/verification_status.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.name,
    required this.phone,
    required this.email,
    this.status = UserStatus.active,
    this.verificationStatus,
  });

  /// Builds a user from a database map (Factory pattern).
  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final Object? verification = map['verificationStatus'];
    return AppUser(
      id: id,
      role: UserRole.values.byName(map['role'] as String),
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String,
      status: UserStatus.values.byName((map['status'] as String?) ?? 'active'),
      verificationStatus: verification == null
          ? null
          : VerificationStatus.values.byName(verification as String),
    );
  }

  final String id;
  final UserRole role;
  final String name;
  final String phone;
  final String email;
  final UserStatus status;

  /// Only used for mechanics.
  final VerificationStatus? verificationStatus;

  bool get isBlocked => status == UserStatus.blocked;

  bool get isPendingVerification =>
      role == UserRole.mechanic &&
      verificationStatus != VerificationStatus.verified;

  String get firstName => name.trim().split(' ').first;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'role': role.name,
        'name': name,
        'phone': phone,
        'email': email,
        'status': status.name,
        if (verificationStatus != null)
          'verificationStatus': verificationStatus!.name,
      };
}
