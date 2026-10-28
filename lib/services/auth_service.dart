import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/app_user.dart';
import '../models/registration_draft.dart';
import '../repositories/auth_repository.dart';

/// Business rules for UC-01 to UC-04 and UC-07.
class AuthService {
  AuthService(this._repository);

  final AuthRepository _repository;

  AppUser? get currentUser => _repository.currentUser;

  Future<AppUser?> restoreSession() => _repository.restoreSession();

  String _normalizePhone(String input) {
    final String? phone = Validators.normalizePhone(input);
    if (phone == null) {
      throw const AppException('Enter a valid Pakistani mobile number.');
    }
    return phone;
  }

  void _checkPassword(String password) {
    if (password.length < AppConstants.minPasswordLength) {
      throw const AppException(
        'Password must be at least ${AppConstants.minPasswordLength} characters.',
      );
    }
  }

  /// UC-01 (steps 1-4): checks the data, makes sure the account is new and
  /// sends an OTP. Returns the normalized phone number.
  Future<String> startRegistration(RegistrationDraft draft) async {
    final String phone = _normalizePhone(draft.phone);
    final String email = draft.email.trim().toLowerCase();
    _checkPassword(draft.password);
    final (bool phoneTaken, bool emailTaken) = await (
      _repository.phoneExists(phone),
      _repository.emailExists(email),
    ).wait;
    if (phoneTaken) {
      throw const AppException(
        'An account with this phone number already exists.',
      );
    }
    if (emailTaken) {
      throw const AppException('An account with this email already exists.');
    }
    await _repository.sendOtp(phone);
    return phone;
  }

  /// UC-01 (steps 5-6): verifies the OTP and creates the account.
  Future<AppUser> completeRegistration(
    RegistrationDraft draft,
    String code,
  ) async {
    final String phone = _normalizePhone(draft.phone);
    await _repository.verifyOtp(phone, code.trim());
    return _repository.register(
      role: draft.role,
      name: draft.name.trim(),
      phone: phone,
      email: draft.email.trim().toLowerCase(),
      password: draft.password,
    );
  }

  /// UC-02.
  Future<AppUser> login(String identifier, String password) {
    if (identifier.trim().isEmpty || password.isEmpty) {
      throw const AppException('Enter your phone or email and your password.');
    }
    return _repository.login(
      identifier: identifier.trim(),
      password: password,
    );
  }

  /// UC-04 (step 1): sends an OTP to a registered number.
  Future<String> startPasswordReset(String phoneInput) async {
    final String phone = _normalizePhone(phoneInput);
    if (!await _repository.phoneExists(phone)) {
      throw const AppException('No account found for this number.');
    }
    await _repository.sendOtp(phone);
    return phone;
  }

  /// UC-03.
  Future<void> verifyOtp(String phone, String code) =>
      _repository.verifyOtp(phone, code.trim());

  /// UC-04 (last step). The OTP must have been verified already.
  /// Returns the message to show once the reset is done.
  Future<String> completePasswordReset(String phone, String newPassword) async {
    _checkPassword(newPassword);
    return _repository.resetPassword(phone: phone, newPassword: newPassword);
  }

  Future<void> resendOtp(String phone) => _repository.sendOtp(phone);

  /// UC-07.
  Future<void> logout() => _repository.logout();

  /// UC-05.
  Future<AppUser> updateProfile({
    required String userId,
    required String name,
    required String email,
  }) {
    final String? error = Validators.name(name) ?? Validators.email(email);
    if (error != null) throw AppException(error);
    return _repository.updateProfile(userId: userId, name: name, email: email);
  }

  /// UC-42.
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) {
    if (currentPassword.isEmpty) {
      throw const AppException('Enter your current password.');
    }
    _checkPassword(newPassword);
    return _repository.changePassword(
      userId: userId,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}
