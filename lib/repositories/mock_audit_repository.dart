import '../models/audit_log.dart';
import 'audit_repository.dart';
import 'mock_data_store.dart';

class MockAuditRepository implements AuditRepository {
  MockAuditRepository(this._store);

  final MockDataStore _store;

  @override
  Future<void> add(AuditLog log) async {
    final String id = _store.newId('a');
    _store.auditLogs[id] = AuditLog(
      id: id,
      adminId: log.adminId,
      adminName: log.adminName,
      action: log.action,
      targetId: log.targetId,
      createdAt: log.createdAt,
      note: log.note,
    );
  }

  @override
  Future<List<AuditLog>> recent({int limit = 20}) async {
    await _store.simulate();
    final List<AuditLog> list = _store.auditLogs.values.toList();
    list.sort((AuditLog a, AuditLog b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }
}
