import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/app_user.dart';
import 'package:fixonway/models/enums/request_status.dart';
import 'package:fixonway/models/enums/user_role.dart';
import 'package:fixonway/repositories/api/api_auth_repository.dart';
import 'package:fixonway/repositories/api/api_chat_repository.dart';
import 'package:fixonway/repositories/api/api_client.dart';
import 'package:fixonway/repositories/api/api_request_repository.dart';
import 'package:fixonway/repositories/api/api_vehicle_repository.dart';
import 'package:fixonway/models/chat_message.dart';
import 'package:fixonway/models/service_request.dart';
import 'package:fixonway/models/vehicle.dart';
import 'package:fixonway/models/enums/vehicle_type.dart';

/// A tiny fake server: [handler] sees every request and answers with
/// (status, json).
ApiClient fakeApi(
  (int, Object?) Function(http.Request request) handler, {
  List<http.Request>? log,
}) {
  final MockClient client = MockClient((http.Request request) async {
    log?.add(request);
    final (int status, Object? body) = handler(request);
    return http.Response(
      body == null ? '' : jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );
  });
  return ApiClient(baseUrl: 'http://test/', client: client);
}

const Map<String, dynamic> aliJson = <String, dynamic>{
  'id': 'u1',
  'role': 'customer',
  'name': 'Ali Raza',
  'phone': '+923001234567',
  'email': 'ali.raza@example.pk',
  'status': 'active',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('ApiClient', () {
    test('sends the token and decodes JSON', () async {
      final List<http.Request> log = <http.Request>[];
      final ApiClient api = fakeApi(
        (http.Request r) => (200, <String, dynamic>{'ok': true}),
        log: log,
      );
      await api.setToken('abc');
      final Object? answer = await api.get('/api/health');
      expect(ApiClient.map(answer)['ok'], true);
      expect(log.single.headers['Authorization'], 'Bearer abc');
      expect(log.single.url.toString(), 'http://test/api/health');
    });

    test('the server error text becomes the message', () async {
      final ApiClient api = fakeApi(
        (http.Request r) => (409, <String, dynamic>{'error': 'Already used.'}),
      );
      expect(
        () => api.post('/api/auth/register', <String, dynamic>{}),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.message, 'message', 'Already used.')
              .having((ApiException e) => e.status, 'status', 409),
        ),
      );
    });

    test('a 401 forgets the saved token', () async {
      final ApiClient api = fakeApi(
        (http.Request r) => (401, <String, dynamic>{'error': 'Please log in.'}),
      );
      await api.setToken('old');
      await expectLater(api.get('/api/requests'), throwsA(isA<ApiException>()));
      expect(api.hasToken, isFalse);
    });

    test('getOrNull gives null for 404 only', () async {
      final ApiClient missing =
          fakeApi((http.Request r) => (404, <String, dynamic>{'error': 'Not found.'}));
      expect(await missing.getOrNull('/api/requests/x'), isNull);
      final ApiClient broken =
          fakeApi((http.Request r) => (500, <String, dynamic>{'error': 'Oops'}));
      await expectLater(broken.getOrNull('/api/requests/x'), throwsA(isA<ApiException>()));
    });

    test('a network failure has a friendly message', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((http.Request r) async => throw Exception('down')),
      );
      await expectLater(
        api.get('/api/health'),
        throwsA(isA<ApiException>().having((ApiException e) => e.isNetwork, 'network', true)),
      );
    });

    test('uploadFile sends the bytes, the name and the kind', () async {
      final List<http.Request> log = <http.Request>[];
      final ApiClient api = fakeApi(
        (http.Request r) => (201, <String, dynamic>{'id': 'f1', 'name': 'a.png', 'size': 3}),
        log: log,
      );
      await api.setToken('tok');
      final String id = await api.uploadFile(<int>[1, 2, 3], 'cnic front.PNG', kind: 'document');
      expect(id, 'f1');
      final http.Request sent = log.single;
      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/files');
      expect(sent.url.queryParameters['kind'], 'document');
      expect(sent.bodyBytes, <int>[1, 2, 3]);
      expect(sent.headers['Content-Type'], 'image/png');
      expect(Uri.decodeComponent(sent.headers['X-File-Name']!), 'cnic front.PNG');
      expect(sent.headers['Authorization'], 'Bearer tok');
    });

    test('fileUrl adds the token only when asked', () async {
      final ApiClient api = fakeApi((http.Request r) => (200, null));
      await api.setToken('tok');
      expect(api.fileUrl('f1'), 'http://test/api/files/f1');
      expect(api.fileUrl('f1', withToken: true), 'http://test/api/files/f1?token=tok');
    });

    test('the token is saved and loaded again', () async {
      final ApiClient first = fakeApi((http.Request r) => (200, null));
      await first.setToken('keep-me');
      final ApiClient second = fakeApi((http.Request r) => (200, null));
      expect(second.hasToken, isFalse);
      await second.loadToken();
      expect(second.hasToken, isTrue);
    });
  });

  group('ApiAuthRepository', () {
    test('login stores the token and returns the user', () async {
      final List<http.Request> log = <http.Request>[];
      final ApiClient api = fakeApi(
        (http.Request r) => (200, <String, dynamic>{'token': 't1', 'user': aliJson}),
        log: log,
      );
      final ApiAuthRepository repo = ApiAuthRepository(api);
      final AppUser user =
          await repo.login(identifier: 'ali.raza@example.pk', password: 'Pass@1234');
      expect(user.role, UserRole.customer);
      expect(repo.currentUser?.id, 'u1');
      expect(api.hasToken, isTrue);
      expect(jsonDecode(log.single.body)['identifier'], 'ali.raza@example.pk');
    });

    test('a wrong password shows the server message', () async {
      final ApiAuthRepository repo = ApiAuthRepository(
        fakeApi((http.Request r) => (401, <String, dynamic>{'error': 'Invalid email or password.'})),
      );
      await expectLater(
        repo.login(identifier: 'x@y.pk', password: 'nope'),
        throwsA(isA<AppException>()
            .having((AppException e) => e.message, 'message', 'Invalid email or password.')),
      );
    });

    test('restoreSession uses the saved token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'fixonway_token': 'saved'});
      final List<http.Request> log = <http.Request>[];
      final ApiAuthRepository repo = ApiAuthRepository(
        fakeApi((http.Request r) => (200, <String, dynamic>{'user': aliJson}), log: log),
      );
      final AppUser? user = await repo.restoreSession();
      expect(user?.email, 'ali.raza@example.pk');
      expect(log.single.headers['Authorization'], 'Bearer saved');
    });

    test('restoreSession without a token asks nothing', () async {
      final List<http.Request> log = <http.Request>[];
      final ApiAuthRepository repo =
          ApiAuthRepository(fakeApi((http.Request r) => (200, null), log: log));
      expect(await repo.restoreSession(), isNull);
      expect(log, isEmpty);
    });

    test('an unreachable server keeps the token', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'fixonway_token': 'saved'});
      final ApiClient api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((http.Request r) async => throw Exception('down')),
      );
      final ApiAuthRepository repo = ApiAuthRepository(api);
      expect(await repo.restoreSession(), isNull);
      expect(api.hasToken, isTrue);
    });

    test('a blocked user is not restored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'fixonway_token': 'saved'});
      final ApiClient api = fakeApi(
        (http.Request r) =>
            (200, <String, dynamic>{'user': <String, dynamic>{...aliJson, 'status': 'blocked'}}),
      );
      final ApiAuthRepository repo = ApiAuthRepository(api);
      expect(await repo.restoreSession(), isNull);
      expect(api.hasToken, isFalse);
    });

    test('logout forgets the token', () async {
      final ApiClient api = fakeApi(
        (http.Request r) => (200, <String, dynamic>{'token': 't1', 'user': aliJson}),
      );
      final ApiAuthRepository repo = ApiAuthRepository(api);
      await repo.login(identifier: 'a@b.pk', password: 'x');
      await repo.logout();
      expect(repo.currentUser, isNull);
      expect(api.hasToken, isFalse);
    });
  });

  group('other repositories', () {
    final Map<String, dynamic> requestJson = <String, dynamic>{
      'id': 'r1',
      'customerId': 'u1',
      'customerName': 'Ali',
      'vehicleId': 'v1',
      'vehicleTitle': 'Suzuki Cultus',
      'vehicleType': 'car',
      'problem': 'flatTire',
      'description': '',
      'location': <String, dynamic>{'lat': 33.7, 'lng': 73.05},
      'address': 'F-10',
      'photos': <Object>[],
      'status': 'estimated',
      'createdAt': 1760000000000,
      'updatedAt': 1760000000000,
      'mechanicId': null,
      'rejectedBy': <Object>[],
    };

    test('requests are read, sorted and null when missing', () async {
      final ApiRequestRepository repo = ApiRequestRepository(
        fakeApi((http.Request r) {
          if (r.url.path == '/api/requests/r1') return (200, requestJson);
          if (r.url.path == '/api/requests/none') return (404, <String, dynamic>{'error': 'Not found.'});
          return (
            200,
            <Object>[
              <String, dynamic>{...requestJson, 'id': 'old', 'createdAt': 1},
              requestJson,
            ],
          );
        }),
      );
      final ServiceRequest? one = await repo.byId('r1');
      expect(one?.status, RequestStatus.estimated);
      expect(await repo.byId('none'), isNull);
      final List<ServiceRequest> list = await repo.byCustomer('u1');
      expect(list.map((ServiceRequest r) => r.id), <String>['r1', 'old']);
    });

    test('vehicles: save creates with POST and updates with PUT', () async {
      final List<http.Request> log = <http.Request>[];
      final ApiVehicleRepository repo = ApiVehicleRepository(
        fakeApi(
          (http.Request r) => (
            200,
            <String, dynamic>{
              'id': 'v9', 'ownerId': 'u1', 'type': 'car', 'make': 'Suzuki', 'model': 'Cultus', 'plate': 'A-1',
            },
          ),
          log: log,
        ),
      );
      const Vehicle fresh = Vehicle(
        id: '', ownerId: 'u1', type: VehicleType.car, make: 'Suzuki', model: 'Cultus', plate: 'A-1',
      );
      final Vehicle saved = await repo.save(fresh);
      expect(saved.id, 'v9');
      expect(log.last.method, 'POST');
      await repo.save(saved);
      expect(log.last.method, 'PUT');
      expect(log.last.url.path, '/api/vehicles/v9');
    });

    test('chat watch sends the list, then only changes', () async {
      int calls = 0;
      final ApiChatRepository repo = ApiChatRepository(
        fakeApi((http.Request r) {
          calls++;
          final List<Map<String, dynamic>> list = <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'm1', 'requestId': 'r1', 'senderId': 'u1', 'senderName': 'Ali',
              'text': 'hi', 'sentAt': 1760000000000,
            },
            if (calls >= 3)
              <String, dynamic>{
                'id': 'm2', 'requestId': 'r1', 'senderId': 'u2', 'senderName': 'Usman',
                'text': 'coming', 'sentAt': 1760000001000,
              },
          ];
          return (200, list);
        }),
        pollEvery: const Duration(milliseconds: 20),
      );
      final List<List<ChatMessage>> seen = <List<ChatMessage>>[];
      final sub = repo.watch('r1').listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      expect(seen.length, 2);
      expect(seen.first.length, 1);
      expect(seen.last.length, 2);
    });
  });
}
