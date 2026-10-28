import '../../core/errors/app_exception.dart';
import '../../models/app_user.dart';
import '../../models/enums/user_role.dart';
import '../../models/enums/user_status.dart';
import '../../models/enums/verification_status.dart';
import '../auth_repository.dart';
import 'api_client.dart';

/// Accounts on the Node.js + MongoDB backend.
///
/// The phone code step was removed from the app, so [sendOtp] and
/// [verifyOtp] do nothing here. Passwords are hashed on the server and the
/// login token is kept by [ApiClient].
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  AppUser _user(Object? json) {
    final Map<String, dynamic> m = ApiClient.map(json);
    return AppUser.fromMap(m['id'] as String, m);
  }

  AppUser _fromAuthAnswer(Object? answer) {
    final Map<String, dynamic> a = ApiClient.map(answer);
    return _user(a['user']);
  }

  @override
  Future<AppUser?> restoreSession() async {
    await _api.loadToken();
    if (!_api.hasToken) return null;
    try {
      final AppUser user = _fromAuthAnswer(await _api.get('/api/auth/me'));
      if (user.isBlocked) {
        await _api.setToken(null);
        return null;
      }
      _current = user;
      return user;
    } on ApiException catch (e) {
      // Only an answer from the server (expired or refused token) ends the
      // login. When the server cannot be reached the token is kept.
      if (e.status == 401 || e.status == 403) await _api.setToken(null);
      return null;
    }
  }

  @override
  Future<bool> phoneExists(String phone) async {
    final Map<String, dynamic> a =
        ApiClient.map(await _api.post('/api/auth/exists', <String, dynamic>{'phone': phone}));
    return a['phoneExists'] == true;
  }

  @override
  Future<bool> emailExists(String email) async {
    final Map<String, dynamic> a =
        ApiClient.map(await _api.post('/api/auth/exists', <String, dynamic>{'email': email}));
    return a['emailExists'] == true;
  }

  @override
  Future<void> sendOtp(String phone) async {}

  @override
  Future<void> verifyOtp(String phone, String code) async {}

  @override
  Future<AppUser> register({
    required UserRole role,
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final Map<String, dynamic> a = ApiClient.map(
      await _api.post('/api/auth/register', <String, dynamic>{
        'role': role.name,
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
      }),
    );
    await _api.setToken(a['token'] as String);
    _current = _user(a['user']);
    return _current!;
  }

  @override
  Future<AppUser> login({
    required String identifier,
    required String password,
  }) async {
    final Map<String, dynamic> a = ApiClient.map(
      await _api.post('/api/auth/login', <String, dynamic>{
        'identifier': identifier,
        'password': password,
      }),
    );
    await _api.setToken(a['token'] as String);
    _current = _user(a['user']);
    return _current!;
  }

  @override
  Future<String> resetPassword({
    required String phone,
    required String newPassword,
  }) async {
    final Map<String, dynamic> a = ApiClient.map(
      await _api.post('/api/auth/reset-password', <String, dynamic>{
        'phone': phone,
        'newPassword': newPassword,
      }),
    );
    return (a['message'] as String?) ??
        'Your password was changed. Log in with the new password.';
  }

  @override
  Future<void> logout() async {
    _current = null;
    await _api.setToken(null);
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String name,
    required String email,
  }) async {
    final AppUser updated = _fromAuthAnswer(
      await _api.put('/api/auth/profile', <String, dynamic>{
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
      }),
    );
    if (_current?.id == userId) _current = updated;
    return updated;
  }

  @override
  Future<AppUser> setVerificationStatus({
    required String userId,
    required VerificationStatus status,
  }) async {
    final AppUser updated = _fromAuthAnswer(
      await _api.patch('/api/users/$userId/verification', <String, dynamic>{
        'status': status.name,
      }),
    );
    if (_current?.id == userId) _current = updated;
    return updated;
  }

  @override
  Future<List<AppUser>> allUsers() async {
    final Object? json = await _api.get('/api/users');
    return <AppUser>[
      for (final Map<String, dynamic> m in ApiClient.maps(json))
        AppUser.fromMap(m['id'] as String, m),
    ];
  }

  @override
  Future<AppUser> setUserStatus({
    required String userId,
    required UserStatus status,
  }) async {
    return _fromAuthAnswer(
      await _api.patch('/api/users/$userId/status', <String, dynamic>{
        'status': status.name,
      }),
    );
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_current == null || _current!.id != userId) {
      throw const AppException('Please log in again.');
    }
    await _api.post('/api/auth/change-password', <String, dynamic>{
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }
}
