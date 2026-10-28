import '../models/app_user.dart';
import '../models/enums/user_role.dart';
import '../models/enums/user_status.dart';
import '../models/enums/verification_status.dart';

/// Talks to the authentication backend (Repository pattern).
///
/// [MockAuthRepository] is used while developing; the API version (ApiAuthRepository) can
/// replace it later without touching the services or screens.
abstract class AuthRepository {
  AppUser? get currentUser;

  /// Brings back a session that was still signed in when the app started
  /// (null when nobody was, or the account is blocked).
  Future<AppUser?> restoreSession();

  Future<bool> phoneExists(String phone);

  Future<bool> emailExists(String email);

  /// Sends a one-time code to [phone].
  Future<void> sendOtp(String phone);

  /// Throws an [AppException] when the code is wrong, expired or used up.
  Future<void> verifyOtp(String phone, String code);

  /// Creates the account. The phone must have been verified first.
  Future<AppUser> register({
    required UserRole role,
    required String name,
    required String phone,
    required String email,
    required String password,
  });

  /// [identifier] is a phone number or an email address.
  Future<AppUser> login({
    required String identifier,
    required String password,
  });

  /// Resets the password. The phone must have been verified first. Returns
  /// the message to show the user (the mock changes the password at once,
  /// the API does the same).
  Future<String> resetPassword({
    required String phone,
    required String newPassword,
  });

  Future<void> logout();

  /// UC-05: changes the name and email of the signed-in user.
  Future<AppUser> updateProfile({
    required String userId,
    required String name,
    required String email,
  });

  /// UC-34: admin approves or rejects a mechanic.
  Future<AppUser> setVerificationStatus({
    required String userId,
    required VerificationStatus status,
  });

  /// UC-36: every account (admin use only).
  Future<List<AppUser>> allUsers();

  /// UC-35: block or unblock an account.
  Future<AppUser> setUserStatus({
    required String userId,
    required UserStatus status,
  });

  /// UC-42: the signed-in user changes their own password.
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });
}
