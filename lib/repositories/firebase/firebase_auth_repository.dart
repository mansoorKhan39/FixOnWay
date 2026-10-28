import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../models/app_user.dart';
import '../../models/enums/user_role.dart';
import '../../models/enums/user_status.dart';
import '../../models/enums/verification_status.dart';
import '../auth_repository.dart';
import 'firebase_support.dart';

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

/// Real accounts with Firebase Authentication (email + password) and the
/// profile stored in the Firestore `users` collection (document id = uid).
///
/// Phone OTP is still simulated (the code is always
/// [AppConstants.demoOtp]) because Firebase phone sign-in needs a paid plan.
/// A phone number can be used to log in: it is looked up in Firestore to
/// find the account's e-mail address first.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    DateTime Function()? now,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _now = now ?? DateTime.now;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final DateTime Function() _now;

  final Map<String, _OtpEntry> _otps = <String, _OtpEntry>{};
  final Set<String> _verifiedPhones = <String>{};
  final Map<String, int> _failedLogins = <String, int>{};
  final Map<String, DateTime> _lockedUntil = <String, DateTime>{};
  AppUser? _current;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(Col.users);

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser?> restoreSession() {
    return guardFirebase(() async {
      // On the web the saved login is read asynchronously, so wait for the
      // first auth state instead of looking at currentUser straight away.
      final User? fbUser = await _auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 6), onTimeout: () => _auth.currentUser);
      if (fbUser == null) return null;
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _users.doc(fbUser.uid).get();
      if (!doc.exists || doc.data() == null) {
        await _auth.signOut();
        return null;
      }
      final AppUser user = _toUser(doc);
      if (user.isBlocked) {
        await _auth.signOut();
        return null;
      }
      _current = user;
      return user;
    });
  }

  // ---- helpers --------------------------------------------------------

  AppUser _toUser(DocumentSnapshot<Map<String, dynamic>> d) =>
      AppUser.fromMap(d.id, d.data()!);

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _firstWhere(
    String field,
    String value,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _users.where(field, isEqualTo: value).limit(1).get();
    return snap.docs.isEmpty ? null : snap.docs.first;
  }

  /// Finds the profile for an e-mail address or a phone number.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findByIdentifier(
    String identifier,
  ) async {
    if (identifier.contains('@')) {
      final String email = identifier.trim().toLowerCase();
      final (
        QueryDocumentSnapshot<Map<String, dynamic>>? byEmail,
        QueryDocumentSnapshot<Map<String, dynamic>>? byAuth,
      ) = await (_firstWhere('email', email), _firstWhere('authEmail', email)).wait;
      return byEmail ?? byAuth;
    }
    final String? phone = Validators.normalizePhone(identifier);
    if (phone == null) return null;
    return _firstWhere('phone', phone);
  }

  String _loginEmail(Map<String, dynamic> data) =>
      ((data['authEmail'] ?? data['email']) as String).toLowerCase();

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'Cannot reach the server. Check your internet connection.';
      case 'user-disabled':
        return 'Your account is suspended.';
      case 'email-already-in-use':
        return 'An account with these details already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least '
            '${AppConstants.minPasswordLength} characters.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is switched off in Firebase. Turn it '
            'on in Authentication > Sign-in method.';
      case 'requires-recent-login':
        return 'Please log in again and retry.';
      default:
        return 'Authentication failed (${e.code}).';
    }
  }

  // ---- lookups --------------------------------------------------------

  @override
  Future<bool> phoneExists(String phone) {
    return guardFirebase(() async => await _firstWhere('phone', phone) != null);
  }

  @override
  Future<bool> emailExists(String email) {
    return guardFirebase(() async {
      final String e = email.trim().toLowerCase();
      final (
        QueryDocumentSnapshot<Map<String, dynamic>>? a,
        QueryDocumentSnapshot<Map<String, dynamic>>? b,
      ) = await (_firstWhere('email', e), _firstWhere('authEmail', e)).wait;
      return a != null || b != null;
    });
  }

  // ---- OTP (simulated) ------------------------------------------------

  @override
  Future<void> sendOtp(String phone) async {
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

  // ---- register / login -----------------------------------------------

  @override
  Future<AppUser> register({
    required UserRole role,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) {
    return guardFirebase(() async {
      if (role == UserRole.admin) {
        throw const AppException('Admin accounts cannot be created in the app.');
      }
      if (!_verifiedPhones.contains(phone)) {
        throw const AppException('Phone number is not verified.');
      }
      final String cleanEmail = email.trim().toLowerCase();
      // phone/e-mail were already checked in AuthService.startRegistration;
      // Firebase Auth itself refuses a repeated e-mail.

      final UserCredential cred;
      try {
        cred = await _auth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        throw AppException(_authMessage(e));
      }
      final User fbUser = cred.user!;

      final AppUser user = AppUser(
        id: fbUser.uid,
        role: role,
        name: name.trim(),
        phone: phone,
        email: cleanEmail,
        verificationStatus:
            role == UserRole.mechanic ? VerificationStatus.pending : null,
      );
      try {
        await _users.doc(user.id).set(<String, dynamic>{
          ...user.toMap(),
          'authEmail': cleanEmail,
          'createdAt': _now().millisecondsSinceEpoch,
        });
      } catch (_) {
        // Do not leave a login without a profile behind.
        await fbUser.delete();
        rethrow;
      }
      _verifiedPhones.remove(phone);
      _current = user;
      return user;
    });
  }

  Never _failLogin(String key, DateTime now) {
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

  @override
  Future<AppUser> login({
    required String identifier,
    required String password,
  }) {
    return _loginNow(identifier: identifier, password: password).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const AppException(
        'The server is taking too long. Check your internet connection and try again.',
      ),
    );
  }

  Future<AppUser> _loginNow({
    required String identifier,
    required String password,
  }) {
    return guardFirebase(() async {
      final DateTime now = _now();
      final String key = identifier.trim().toLowerCase();

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

      final QueryDocumentSnapshot<Map<String, dynamic>>? doc =
          await _findByIdentifier(identifier);
      if (doc == null) _failLogin(key, now);

      try {
        await _auth.signInWithEmailAndPassword(
          email: _loginEmail(doc.data()),
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential' ||
            e.code == 'wrong-password' ||
            e.code == 'user-not-found' ||
            e.code == 'invalid-email') {
          _failLogin(key, now);
        }
        throw AppException(_authMessage(e));
      }

      _failedLogins.remove(key);
      final AppUser user = AppUser.fromMap(doc.id, doc.data());
      if (user.isBlocked) {
        await _auth.signOut();
        throw const AppException('Your account is suspended.');
      }
      _current = user;
      return user;
    });
  }

  @override
  Future<String> resetPassword({
    required String phone,
    required String newPassword,
  }) {
    return guardFirebase(() async {
      if (!_verifiedPhones.contains(phone)) {
        throw const AppException('Phone number is not verified.');
      }
      final QueryDocumentSnapshot<Map<String, dynamic>>? doc =
          await _firstWhere('phone', phone);
      if (doc == null) {
        throw const AppException('No account found for this number.');
      }
      final String email = _loginEmail(doc.data());
      try {
        await _auth.sendPasswordResetEmail(email: email);
      } on FirebaseAuthException catch (e) {
        throw AppException(_authMessage(e));
      }
      _verifiedPhones.remove(phone);
      return 'A password reset link was sent to ${_mask(email)}. Open it to '
          'choose your new password, then log in.';
    });
  }

  String _mask(String email) {
    final int at = email.indexOf('@');
    if (at <= 1) return email;
    return '${email[0]}***${email.substring(at)}';
  }

  @override
  Future<void> logout() async {
    _current = null;
    await _auth.signOut();
  }

  // ---- profile --------------------------------------------------------

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String name,
    required String email,
  }) {
    return guardFirebase(() async {
      final String cleanEmail = email.trim().toLowerCase();
      final QuerySnapshot<Map<String, dynamic>> taken =
          await _users.where('email', isEqualTo: cleanEmail).get();
      final bool used = taken.docs.any(
        (QueryDocumentSnapshot<Map<String, dynamic>> d) => d.id != userId,
      );
      if (used) {
        throw const AppException('This email is used by another account.');
      }
      await _users.doc(userId).update(<String, dynamic>{
        'name': name.trim(),
        'email': cleanEmail,
      });
      final AppUser updated = _toUser(await _users.doc(userId).get());
      if (_current?.id == userId) _current = updated;
      return updated;
    });
  }

  @override
  Future<AppUser> setVerificationStatus({
    required String userId,
    required VerificationStatus status,
  }) {
    return guardFirebase(() async {
      await _users.doc(userId).update(<String, dynamic>{
        'verificationStatus': status.name,
      });
      final AppUser updated = _toUser(await _users.doc(userId).get());
      if (_current?.id == userId) _current = updated;
      return updated;
    });
  }

  @override
  Future<List<AppUser>> allUsers() {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap = await _users.get();
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              AppUser.fromMap(d.id, d.data()))
          .toList();
    });
  }

  @override
  Future<AppUser> setUserStatus({
    required String userId,
    required UserStatus status,
  }) {
    return guardFirebase(() async {
      await _users.doc(userId).update(<String, dynamic>{
        'status': status.name,
      });
      return _toUser(await _users.doc(userId).get());
    });
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) {
    return guardFirebase(() async {
      final User? fbUser = _auth.currentUser;
      if (fbUser == null || fbUser.uid != userId) {
        throw const AppException('Please log in again.');
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
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _users.doc(userId).get();
      final Map<String, dynamic>? data = doc.data();
      if (data == null) throw const AppException('Account not found.');
      try {
        await fbUser.reauthenticateWithCredential(
          EmailAuthProvider.credential(
            email: _loginEmail(data),
            password: currentPassword,
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential' ||
            e.code == 'wrong-password' ||
            e.code == 'user-mismatch') {
          throw const AppException('Your current password is incorrect.');
        }
        throw AppException(_authMessage(e));
      }
      try {
        await fbUser.updatePassword(newPassword);
      } on FirebaseAuthException catch (e) {
        throw AppException(_authMessage(e));
      }
    });
  }
}
