/// UC-35 / UC-34 / UC-38: a record of an admin action.
class AuditLog {
  const AuditLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.targetId,
    required this.createdAt,
    this.note = '',
  });

  final String id;
  final String adminId;
  final String adminName;

  /// e.g. "Approved mechanic", "Blocked user".
  final String action;
  final String targetId;
  final DateTime createdAt;
  final String note;
}
