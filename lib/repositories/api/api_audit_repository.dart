import '../../models/audit_log.dart';
import '../audit_repository.dart';
import 'api_client.dart';
import 'codecs.dart';

class ApiAuditRepository implements AuditRepository {
  ApiAuditRepository(this._api);

  final ApiClient _api;

  @override
  Future<void> add(AuditLog log) async {
    await _api.post('/api/audit', Codecs.auditToMap(log));
  }

  @override
  Future<List<AuditLog>> recent({int limit = 20}) async {
    final Object? json = await _api.get(
      '/api/audit',
      query: <String, String>{'limit': '$limit'},
    );
    return <AuditLog>[
      for (final Map<String, dynamic> m in ApiClient.maps(json))
        Codecs.auditFromMap(m['id'] as String, m),
    ];
  }
}
