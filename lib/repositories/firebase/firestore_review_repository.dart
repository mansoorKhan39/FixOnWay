import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/complaint.dart';
import '../../models/review.dart';
import '../review_repository.dart';
import 'codecs.dart';
import 'firebase_support.dart';

/// Reviews (one per request, stored under the request id) and complaints.
class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _db.collection(Col.reviews);
  CollectionReference<Map<String, dynamic>> get _complaints =>
      _db.collection(Col.complaints);

  @override
  Future<Review?> reviewFor(String requestId) {
    return guardFirebase(() async {
      if (requestId.isEmpty) return null;
      final DocumentSnapshot<Map<String, dynamic>> d =
          await _reviews.doc(requestId).get();
      final Map<String, dynamic>? data = d.data();
      return data == null ? null : Codecs.reviewFromMap(data);
    });
  }

  @override
  Future<void> saveReview(Review review) {
    return guardFirebase(
      () => _reviews.doc(review.requestId).set(Codecs.reviewToMap(review)),
    );
  }

  @override
  Future<List<Review>> reviewsOfMechanic(String mechanicId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _reviews.where('mechanicId', isEqualTo: mechanicId).get();
      final List<Review> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.reviewFromMap(d.data()))
          .toList();
      list.sort((Review a, Review b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<Complaint> addComplaint(Complaint complaint) {
    return guardFirebase(() async {
      final DocumentReference<Map<String, dynamic>> ref = _complaints.doc();
      final Map<String, dynamic> map = Codecs.complaintToMap(complaint);
      await ref.set(map);
      return Codecs.complaintFromMap(ref.id, map);
    });
  }

  @override
  Future<List<Complaint>> complaintsOfRequest(String requestId) {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await _complaints.where('requestId', isEqualTo: requestId).get();
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.complaintFromMap(d.id, d.data()))
          .toList();
    });
  }

  @override
  Future<List<Complaint>> allComplaints() {
    return guardFirebase(() async {
      final QuerySnapshot<Map<String, dynamic>> snap = await _complaints.get();
      final List<Complaint> list = snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              Codecs.complaintFromMap(d.id, d.data()))
          .toList();
      list.sort((Complaint a, Complaint b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Future<void> updateComplaint(Complaint complaint) {
    return guardFirebase(
      () => _complaints.doc(complaint.id).set(Codecs.complaintToMap(complaint)),
    );
  }
}
