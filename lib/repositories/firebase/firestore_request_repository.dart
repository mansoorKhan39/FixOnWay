import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_notification.dart';
import '../../models/estimate.dart';
import '../../models/lat_lng.dart';
import '../../models/live_location.dart';
import '../../models/mechanic_profile.dart';
import '../../models/service_request.dart';
import '../request_repository.dart';
import 'codecs.dart';
import 'firebase_support.dart';

/// Requests, estimates, mechanic profiles and notifications in Firestore.
///
/// Queries use one filter at most and sort in the app, so no composite
/// indexes are needed.
class FirestoreRequestRepository implements RequestRepository {
  FirestoreRequestRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection(Col.requests);
  CollectionReference<Map<String, dynamic>> get _estimates =>
      _db.collection(Col.estimates);
  CollectionReference<Map<String, dynamic>> get _mechanics =>
      _db.collection(Col.mechanics);
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection(Col.notifications);

  List<ServiceRequest> _sortedRequests(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final List<ServiceRequest> list = snap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            Codecs.requestFromMap(d.id, d.data()))
        .toList();
    list.sort(
      (ServiceRequest a, ServiceRequest b) => b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<ServiceRequest> create(ServiceRequest request) {
    return guardFirebase(() async {
      final DocumentReference<Map<String, dynamic>> ref = _requests.doc();
      final Map<String, dynamic> map = Codecs.requestToMap(request);
      await ref.set(map);
      return Codecs.requestFromMap(ref.id, map);
    });
  }

  @override
  Future<void> update(ServiceRequest request) {
    return guardFirebase(
      () => _requests.doc(request.id).set(Codecs.requestToMap(request)),
    );
  }

  @override
  Future<ServiceRequest?> byId(String id) {
    return guardFirebase(() async {
      if (id.isEmpty) return null;
      final DocumentSnapshot<Map<String, dynamic>> d =
          await _requests.doc(id).get();
      final Map<String, dynamic>? data = d.data();
      return data == null ? null : Codecs.requestFromMap(d.id, data);
    });
  }

  @override
  Future<List<ServiceRequest>> byCustomer(String customerId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _requests.where('customerId', isEqualTo: customerId).get();
      return _sortedRequests(snap);
    });
  }

  @override
  Future<List<ServiceRequest>> all() {
    return guardFirebase(() async => _sortedRequests(await _requests.get()));
  }

  @override
  Future<List<Estimate>> estimatesFor(String requestId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _estimates.where('requestId', isEqualTo: requestId).get();
      final List<Estimate> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.estimateFromMap(d.id, d.data()))
          .toList();
      list.sort((Estimate a, Estimate b) => a.amount.compareTo(b.amount));
      return list;
    });
  }

  @override
  Future<Estimate> addEstimate(Estimate estimate) {
    return guardFirebase(() async {
      final DocumentReference<Map<String, dynamic>> ref = _estimates.doc();
      final Map<String, dynamic> map = Codecs.estimateToMap(estimate);
      await ref.set(map);
      return Codecs.estimateFromMap(ref.id, map);
    });
  }

  @override
  Future<void> updateEstimate(Estimate estimate) {
    return guardFirebase(
      () => _estimates.doc(estimate.id).set(Codecs.estimateToMap(estimate)),
    );
  }

  @override
  Future<List<MechanicProfile>> mechanics() {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap = await _mechanics.get();
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.mechanicFromMap(d.id, d.data()))
          .toList();
    });
  }

  @override
  Future<MechanicProfile?> mechanic(String userId) {
    return guardFirebase(() async {
      if (userId.isEmpty) return null;
      final DocumentSnapshot<Map<String, dynamic>> d =
          await _mechanics.doc(userId).get();
      final Map<String, dynamic>? data = d.data();
      return data == null ? null : Codecs.mechanicFromMap(d.id, data);
    });
  }

  @override
  Future<void> saveMechanic(MechanicProfile profile) {
    return guardFirebase(
      () => _mechanics.doc(profile.userId).set(Codecs.mechanicToMap(profile)),
    );
  }

  @override
  Future<List<AppNotification>> notificationsFor(String userId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _notifications.where('userId', isEqualTo: userId).get();
      final List<AppNotification> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.notificationFromMap(d.id, d.data()))
          .toList();
      list.sort(
        (AppNotification a, AppNotification b) =>
            b.createdAt.compareTo(a.createdAt),
      );
      return list;
    });
  }

  @override
  Future<void> addNotification(AppNotification notification) {
    return guardFirebase(
      () => _notifications.add(Codecs.notificationToMap(notification)),
    );
  }

  @override
  Future<void> markAllNotificationsRead(String userId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _notifications.where('userId', isEqualTo: userId).get();
      final WriteBatch batch = _db.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        if (d.data()['read'] != true) {
          batch.update(d.reference, <String, dynamic>{'read': true});
        }
      }
      await batch.commit();
    });
  }

  @override
  Future<void> saveLiveLocation(
    String requestId,
    LatLng position,
    DateTime at,
  ) {
    return guardFirebase(
      () => _db.collection(Col.liveLocations).doc(requestId).set(
            Codecs.liveLocationToMap(LiveLocation(position: position, updatedAt: at)),
          ),
    );
  }

  @override
  Future<LiveLocation?> liveLocation(String requestId) {
    return guardFirebase(() async {
      if (requestId.isEmpty) return null;
      final DocumentSnapshot<Map<String, dynamic>> d =
          await _db.collection(Col.liveLocations).doc(requestId).get();
      final Map<String, dynamic>? data = d.data();
      return data == null ? null : Codecs.liveLocationFromMap(data);
    });
  }
}
