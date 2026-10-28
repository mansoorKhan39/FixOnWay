import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_config.dart';
import '../../core/errors/app_exception.dart';

/// An error answered by the server (or a network problem with status 0).
class ApiException extends AppException {
  const ApiException(super.message, this.status);

  final int status;

  bool get isNetwork => status == 0;
}

/// Small JSON-over-HTTP client for the FixOnWay backend. It adds the login
/// token to every call and turns errors into messages the screens can show.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  })  : baseUrl = (baseUrl ?? AppConfig.apiUrl).replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  static const String _tokenKey = 'fixonway_token';

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;
  String? _token;

  bool get hasToken => _token != null;

  /// Reads the saved login token (call once when the app starts).
  Future<void> loadToken() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
    } catch (_) {
      _token = null;
    }
  }

  /// Keeps (or forgets, with null) the login token.
  Future<void> setToken(String? token) async {
    _token = token;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, token);
      }
    } catch (_) {
      // Not saving is fine, the person just has to log in again next time.
    }
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body ?? <String, dynamic>{});

  Future<dynamic> put(String path, Object? body) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, Object? body) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Like [get], but a "not found" answer gives null.
  Future<dynamic> getOrNull(String path, {Map<String, String>? query}) async {
    try {
      return await get(path, query: query);
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    Uri uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final http.Request request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final String? token = _token;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    final http.Response response;
    try {
      final http.StreamedResponse streamed =
          await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'The server is taking too long. Check your internet connection and '
        'try again.',
        0,
      );
    } catch (_) {
      throw const ApiException(
        'Cannot reach the server. Check that the backend is running and your '
        'internet connection works.',
        0,
      );
    }

    final int status = response.statusCode;
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }
    if (status >= 200 && status < 300) return decoded;

    final String message = (decoded is Map && decoded['error'] is String)
        ? decoded['error'] as String
        : 'The server answered with an error ($status).';
    // A rejected token means the saved login is no longer valid.
    if (status == 401 && token != null) await setToken(null);
    throw ApiException(message, status);
  }

  void close() => _client.close();

  // ---- helpers for the repositories -------------------------------------

  /// A JSON object as a typed map.
  static Map<String, dynamic> map(Object? json) =>
      Map<String, dynamic>.from(json! as Map<Object?, Object?>);

  /// A JSON array of objects as typed maps.
  static List<Map<String, dynamic>> maps(Object? json) => <Map<String, dynamic>>[
        for (final Object? item in (json as List<Object?>? ?? <Object?>[]))
          map(item),
      ];
}
