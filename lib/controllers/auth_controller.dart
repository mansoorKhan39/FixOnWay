import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/app_user.dart';
import '../models/registration_draft.dart';
import '../services/auth_service.dart';

/// Holds the login state for the UI (Observer pattern via [ChangeNotifier]).
class AuthController extends ChangeNotifier {
  AuthController(this._service);

  final AuthService _service;

  AppUser? _user;
  bool _isLoading = false;
  String? _errorMessage;
  RegistrationDraft? _draft;
  String? _otpPhone;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// The (normalized) phone number the current OTP was sent to.
  String? get otpPhone => _otpPhone;

  /// What to tell the user after a password reset finished.
  String get resetMessage =>
      _resetMessage ?? 'You can now log in with your new password.';
  String? _resetMessage;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    // Often called from initState, so notify after the current build.
    Future<void>.microtask(notifyListeners);
  }

  /// Runs [action], tracks the loading state and keeps any error message.
  Future<bool> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Called by the splash screen: keeps the person logged in between
  /// visits. Never shows an error, a failure simply means "log in again".
  Future<AppUser?> restoreSession() async {
    try {
      _user = await _service.restoreSession();
    } catch (_) {
      _user = null;
    }
    notifyListeners();
    return _user;
  }

  Future<bool> login(String identifier, String password) {
    return _run(() async {
      _user = await _service.login(identifier, password);
    });
  }

  /// Sign-up without a code step: checks the data and creates the account.
  Future<bool> register(RegistrationDraft draft) {
    return _run(() async {
      await _service.startRegistration(draft);
      _user = await _service.completeRegistration(draft, AppConstants.demoOtp);
      _draft = null;
      _otpPhone = null;
    });
  }

  /// Forgot password without a code step: finds the account and goes straight
  /// to choosing a new password.
  Future<bool> startPasswordResetDirect(String phoneInput) {
    return _run(() async {
      _draft = null;
      final String phone = await _service.startPasswordReset(phoneInput);
      await _service.verifyOtp(phone, AppConstants.demoOtp);
      _otpPhone = phone;
    });
  }

  Future<bool> startRegistration(RegistrationDraft draft) {
    return _run(() async {
      _otpPhone = await _service.startRegistration(draft);
      _draft = draft;
    });
  }

  Future<bool> completeRegistration(String code) {
    return _run(() async {
      final RegistrationDraft? draft = _draft;
      if (draft == null) {
        throw const AppException(
          'Your sign-up session has expired. Please start again.',
        );
      }
      _user = await _service.completeRegistration(draft, code);
      _draft = null;
      _otpPhone = null;
    });
  }

  Future<bool> startPasswordReset(String phoneInput) {
    return _run(() async {
      _draft = null;
      _otpPhone = await _service.startPasswordReset(phoneInput);
    });
  }

  /// Verifies the OTP of the password-reset flow.
  Future<bool> confirmResetOtp(String code) {
    return _run(() async {
      final String? phone = _otpPhone;
      if (phone == null) {
        throw const AppException('Please start the reset again.');
      }
      await _service.verifyOtp(phone, code);
    });
  }

  Future<bool> completePasswordReset(String newPassword) {
    return _run(() async {
      final String? phone = _otpPhone;
      if (phone == null) {
        throw const AppException('Please start the reset again.');
      }
      _resetMessage = await _service.completePasswordReset(phone, newPassword);
      _otpPhone = null;
    });
  }

  Future<bool> resendOtp() {
    return _run(() async {
      final String? phone = _otpPhone;
      if (phone == null) {
        throw const AppException('Please start again.');
      }
      await _service.resendOtp(phone);
    });
  }

  Future<bool> updateProfile({required String name, required String email}) {
    return _run(() async {
      final AppUser? current = _user;
      if (current == null) throw const AppException('Please log in again.');
      _user = await _service.updateProfile(
        userId: current.id,
        name: name,
        email: email,
      );
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _run(() async {
      final AppUser? current = _user;
      if (current == null) throw const AppException('Please log in again.');
      await _service.changePassword(
        userId: current.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    });
  }

  /// Re-reads the signed-in user (e.g. after an admin changed it).
  void refreshUser() {
    _user = _service.currentUser;
    notifyListeners();
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _draft = null;
    _otpPhone = null;
    _errorMessage = null;
    notifyListeners();
  }
}
