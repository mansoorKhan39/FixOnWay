import '../models/audit_log.dart';

abstract class AuditRepository {
  Future<void> add(AuditLog log);

  /// Newest first.
  Future<List<AuditLog>> recent({int limit = 20});
}
