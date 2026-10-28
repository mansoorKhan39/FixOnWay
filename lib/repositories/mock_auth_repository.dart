import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/app_user.dart';
import '../models/enums/user_role.dart';
import '../models/enums/user_status.dart';
import '../models/enums/verification_status.dart';
import 'auth_repository.dart';

class _Account {
  _Account(this.user, this.password);

  AppUser user;
  String password;
}

class _OtpEntry {
  _OtpEntry({
    required this.code,
    required this.sentAt,
    required this.expiresAt,
  });

  final String code;
  final DateTime sentAt;
  final DateTime expiresAt;
  int wrongAttempts = 0;
}

/// In-memory authentication used for development and tests.
///
/// Demo accounts (password in brackets):
///  - customer ali.raza@example.pk / 0300 1234567 (Pass@1234)
///  - mechanic usman@example.pk / 0321 7654321 (Pass@1234)
///  - admin sara.khan@fixonway.pk / 0333 1112233 (Admin@1234)
///  - blocked user blocked@example.pk (Pass@1234)
/// Every OTP is [AppConstants.demoOtp].
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    DateTime Function()? now,
    Duration simulatedDelay = const Duration(milliseconds: 400),
  })  : _now = now ?? DateTime.now,
        _delay = simulatedDelay {
    _seed();
  }

  final DateTime Function() _now;
  final Duration _delay;

  final Map<String, _Account> _accounts = <String, _Account>{};
  final Map<String, _OtpEntry> _otps = <String, _OtpEntry>{};
  final Set<String> _verifiedPhones = <String>{};
  final Map<String, int> _failedLogins = <String, int>{};
  final Map<String, DateTime> _lockedUntil = <String, DateTime>{};
  int _nextId = 100;
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser?> restoreSession() async => _current;

  void _seed() {
    _accounts['u1'] = _Account(
      const AppUser(
        id: 'u1',
        role: UserRole.customer,
        name: 'Ali Raza',
        phone: '+923001234567',
        email: 'ali.raza@example.pk',
      ),
      'Pass@1234',
    );
    _accounts['u2'] = _Account(
      const AppUser(
        id: 'u2',
        role: UserRole.mechanic,
        name: 'Usman Ghani',
        phone: '+923217654321',
        email: 'usman@example.pk',
        verificationStatus: VerificationStatus.verified,
      ),
      'Pass@1234',
    );
    _accounts['u3'] = _Account(
      const AppUser(
        id: 'u3',
        role: UserRole.admin,
        name: 'Sara Khan',
        phone: '+923331112233',
        email: 'sara.khan@fixonway.pk',
      ),
      'Admin@1234',
    );
    void seedMechanic(String id, String name, String phone, String email) {
      _accounts[id] = _Account(
        AppUser(
          id: id,
          role: UserRole.mechanic,
          name: name,
          phone: phone,
          email: email,
          verificationStatus: VerificationStatus.verified,
        ),
        'Pass@1234',
      );
    }

    seedMechanic('m2', 'Ahmed Khan', '+923001110002', 'ahmed@example.pk');
    seedMechanic('m3', 'Bilal Hussain', '+923001110003', 'bilal@example.pk');
    seedMechanic('m4', 'Hamza Ali', '+923001110004', 'hamza@example.pk');
    seedMechanic('m5', 'Kashif Mehmood', '+923001110005', 'kashif@example.pk');
    _accounts['u5'] = _Account(
      const AppUser(
        id: 'u5',
        role: UserRole.mechanic,
        name: 'Zahid Mehmood',
        phone: '+923451112299',
        email: 'zahid@example.pk',
        verificationStatus: VerificationStatus.pending,
      ),
      'Pass@1234',
    );
    _accounts['u6'] = _Account(
      const AppUser(
        id: 'u6',
        role: UserRole.customer,
        name: 'Hira Sheikh',
        phone: '+923331239876',
        email: 'hira@example.pk',
      ),
      'Pass@1234',
    );
    _accounts['u4'] = _Account(
      const AppUser(
        id: 'u4',
        role: UserRole.customer,
        name: 'Blocked User',
        phone: '+923451234567',
        email: 'blocked@example.pk',
        status: UserStatus.blocked,
      ),
      'Pass@1234',
    );
  }

  Future<void> _simulate() => Future<void>.delayed(_delay);

  bool _hasPhone(String phone) =>
      _accounts.values.any((_Account a) => a.user.phone == phone);

  bool _hasEmail(String email) => _accounts.values
      .any((_Account a) => a.user.email.toLowerCase() == email.toLowerCase());

  _Account? _findByIdentifier(String identifier) {
    if (identifier.contains('@')) {
      final String email = identifier.toLowerCase();
      for (final _Account a in _accounts.values) {
        if (a.user.email.toLowerCase() == email) return a;
      }
      return null;
    }
    final String? phone = Validators.normalizePhone(identifier);
    if (phone == null) return null;
    for (final _Account a in _accounts.values) {
      if (a.user.phone == phone) return a;
    }
    return null;
  }

  @override
  Future<bool> phoneExists(String phone) async {
    await _simulate();
    return _hasPhone(phone);
  }

  @override
  Future<bool> emailExists(String email) async {
    await _simulate();
    return _hasEmail(email);
  }

  @override
  Future<void> sendOtp(String phone) async {
    await _simulate();
    final DateTime now = _now();
    final _OtpEntry? existing = _otps[phone];
    if (existing != null) {
      final Duration since = now.difference(existing.sentAt);
      if (since < AppConstants.otpResendWait) {
        final int wait = (AppConstants.otpResendWait - since).inSeconds + 1;
        throw AppException(
          'Please wait $wait seconds before requesting a new code.',
        );
      }
    }
    _otps[phone] = _OtpEntry(
      code: AppConstants.demoOtp,
      sentAt: now,
      expiresAt: now.add(AppConstants.otpValidity),
    );
  }

  @override
  Future<void> verifyOtp(String phone, String code) async {
    await _simulate();
    final _OtpEntry? entry = _otps[phone];
    if (entry == null) {
      throw const AppException('Please request a new code.');
    }
    if (_now().isAfter(entry.expiresAt)) {
      _otps.remove(phone);
      throw const AppException('This code has expired. Request a new one.');
    }
    if (code != entry.code) {
      entry.wrongAttempts++;
      if (entry.wrongAttempts >= AppConstants.maxOtpAttempts) {
        _otps.remove(phone);
        throw const AppException(
          'Too many wrong attempts. Please request a new code.',
        );
      }
      final int left = AppConstants.maxOtpAttempts - entry.wrongAttempts;
      throw AppException('Incorrect code. $left attempt(s) left.');
    }
    _otps.remove(phone);
    _verifiedPhones.add(phone);
  }

  @override
  Future<AppUser> register({
    required UserRole role,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    await _simulate();
    if (role == UserRole.admin) {
      throw const AppException('Admin accounts cannot be created in the app.');
    }
    if (!_verifiedPhones.contains(phone)) {
      throw const AppException('Phone number is not verified.');
    }
    if (_hasPhone(phone) || _hasEmail(email)) {
      throw const AppException('An account with these details already exists.');
    }
    final String id = 'u${_nextId++}';
    final AppUser user = AppUser(
      id: id,
      role: role,
      name: name,
      phone: phone,
      email: email,
      verificationStatus:
          role == UserRole.mechanic ? VerificationStatus.pending : null,
    );
    _accounts[id] = _Account(user, password);
    _verifiedPhones.remove(phone);
    _current = user;
    return user;
  }

  @override
  Future<AppUser> login({
    required String identifier,
    required String password,
  }) async {
    await _simulate();
    final DateTime now = _now();
    final String key = identifier.toLowerCase();

    final DateTime? lockedUntil = _lockedUntil[key];
    if (lockedUntil != null) {
      if (now.isBefore(lockedUntil)) {
        final int minutes = lockedUntil.difference(now).inMinutes + 1;
        throw AppException(
          'Too many failed attempts. Try again in $minutes minute(s).',
        );
      }
      _lockedUntil.remove(key);
      _failedLogins.remove(key);
    }

    final _Account? account = _findByIdentifier(identifier);
    if (account == null || account.password != password) {
      final int failed = (_failedLogins[key] ?? 0) + 1;
      if (failed >= AppConstants.maxLoginAttempts) {
        _failedLogins.remove(key);
        _lockedUntil[key] = now.add(AppConstants.loginLockDuration);
        throw AppException(
          'Too many failed attempts. Your login is locked for '
          '${AppConstants.loginLockDuration.inMinutes} minutes.',
        );
      }
      _failedLogins[key] = failed;
      throw const AppException('Invalid email or password.');
    }

    _failedLogins.remove(key);
    if (account.user.isBlocked) {
      throw const AppException('Your account is suspended.');
    }
    _current = account.user;
    return account.user;
  }

  @override
  Future<String> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    await _simulate();
    if (!_verifiedPhones.contains(phone)) {
      throw const AppException('Phone number is not verified.');
    }
    _Account? account;
    for (final _Account a in _accounts.values) {
      if (a.user.phone == phone) account = a;
    }
    if (account == null) {
      throw const AppException('No account found for this number.');
    }
    if (account.password == newPassword) {
      throw const AppException(
        'New password must be different from the old one.',
      );
    }
    account.password = newPassword;
    _verifiedPhones.remove(phone);
    return 'You can now log in with your new password.';
  }

  @override
  Future<void> logout() async {
    _current = null;
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String name,
    required String email,
  }) async {
    await _simulate();
    final _Account? account = _accounts[userId];
    if (account == null) throw const AppException('Account not found.');
    final String cleanEmail = email.trim().toLowerCase();
    final bool taken = _accounts.values.any(
      (_Account a) =>
          a.user.id != userId && a.user.email.toLowerCase() == cleanEmail,
    );
    if (taken) {
      throw const AppException('This email is used by another account.');
    }
    final AppUser old = account.user;
    final AppUser updated = AppUser(
      id: old.id,
      role: old.role,
      name: name.trim(),
      phone: old.phone,
      email: cleanEmail,
      status: old.status,
      verificationStatus: old.verificationStatus,
    );
    account.user = updated;
    if (_current?.id == userId) _current = updated;
    return updated;
  }

  @override
  Future<AppUser> setVerificationStatus({
    required String userId,
    required VerificationStatus status,
  }) async {
    await _simulate();
    final _Account? account = _accounts[userId];
    if (account == null) throw const AppException('Account not found.');
    final AppUser old = account.user;
    final AppUser updated = AppUser(
      id: old.id,
      role: old.role,
      name: old.name,
      phone: old.phone,
      email: old.email,
      status: old.status,
      verificationStatus: status,
    );
    account.user = updated;
    if (_current?.id == userId) _current = updated;
    return updated;
  }

  @override
  Future<List<AppUser>> allUsers() async {
    await _simulate();
    return _accounts.values.map((_Account a) => a.user).toList();
  }

  @override
  Future<AppUser> setUserStatus({
    required String userId,
    required UserStatus status,
  }) async {
    await _simulate();
    final _Account? account = _accounts[userId];
    if (account == null) throw const AppException('Account not found.');
    final AppUser old = account.user;
    final AppUser updated = AppUser(
      id: old.id,
      role: old.role,
      name: old.name,
      phone: old.phone,
      email: old.email,
      status: status,
      verificationStatus: old.verificationStatus,
    );
    account.user = updated;
    if (_current?.id == userId && status == UserStatus.blocked) {
      _current = null;
    } else if (_current?.id == userId) {
      _current = updated;
    }
    return updated;
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _simulate();
    final _Account? account = _accounts[userId];
    if (account == null) throw const AppException('Account not found.');
    if (account.password != currentPassword) {
      throw const AppException('Your current password is incorrect.');
    }
    if (newPassword.length < AppConstants.minPasswordLength) {
      throw const AppException(
        'Password must be at least ${AppConstants.minPasswordLength} characters.',
      );
    }
    if (newPassword == currentPassword) {
      throw const AppException(
        'New password must be different from the old one.',
      );
    }
    account.password = newPassword;
  }
}
