import '../../models/mechanic_application.dart';
import '../application_repository.dart';
import 'api_client.dart';
import 'codecs.dart';

/// Mechanic verification forms, stored under the mechanic's user id.
class ApiApplicationRepository implements ApplicationRepository {
  ApiApplicationRepository(this._api);

  final ApiClient _api;

  MechanicApplication _application(Map<String, dynamic> m) =>
      Codecs.applicationFromMap(m['id'] as String, m);

  @override
  Future<MechanicApplication?> byUser(String userId) async {
    if (userId.isEmpty) return null;
    final Object? json = await _api.getOrNull('/api/applications/$userId');
    return json == null ? null : _application(ApiClient.map(json));
  }

  @override
  Future<void> save(MechanicApplication application) async {
    await _api.put(
      '/api/applications/${application.userId}',
      Codecs.applicationToMap(application),
    );
  }

  @override
  Future<List<MechanicApplication>> all() async {
    return ApiClient.maps(await _api.get('/api/applications'))
        .map(_application)
        .toList();
  }

  @override
  Future<void> remove(String userId) async {
    await _api.delete('/api/applications/$userId');
  }
}
