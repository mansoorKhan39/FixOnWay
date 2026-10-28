import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/audit_log.dart';
import '../audit_repository.dart';
import 'codecs.dart';
import 'firebase_support.dart';

class FirestoreAuditRepository implements AuditRepository {
  FirestoreAuditRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection(Col.auditLogs);

  @override
  Future<void> add(AuditLog log) {
    return guardFirebase(() => _logs.add(Codecs.auditToMap(log)));
  }

  @override
  Future<List<AuditLog>> recent({int limit = 20}) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap = await _logs
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.auditFromMap(d.id, d.data()))
          .toList();
    });
  }
}
