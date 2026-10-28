import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/mechanic_application.dart';
import '../application_repository.dart';
import 'codecs.dart';
import 'firebase_support.dart';

/// Mechanic verification forms, stored under the mechanic's user id.
class FirestoreApplicationRepository implements ApplicationRepository {
  FirestoreApplicationRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _applications =>
      _db.collection(Col.applications);

  @override
  Future<MechanicApplication?> byUser(String userId) {
    return guardFirebase(() async {
      if (userId.isEmpty) return null;
      final DocumentSnapshot<Map<String, dynamic>> d =
          await _applications.doc(userId).get();
      final Map<String, dynamic>? data = d.data();
      return data == null ? null : Codecs.applicationFromMap(d.id, data);
    });
  }

  @override
  Future<void> save(MechanicApplication application) {
    return guardFirebase(
      () => _applications
          .doc(application.userId)
          .set(Codecs.applicationToMap(application)),
    );
  }

  @override
  Future<List<MechanicApplication>> all() {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _applications.get();
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.applicationFromMap(d.id, d.data()))
          .toList();
    });
  }

  @override
  Future<void> remove(String userId) {
    return guardFirebase(() => _applications.doc(userId).delete());
  }
}
