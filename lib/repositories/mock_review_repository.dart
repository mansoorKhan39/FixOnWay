import '../models/complaint.dart';
import '../models/review.dart';
import 'mock_data_store.dart';
import 'review_repository.dart';

class MockReviewRepository implements ReviewRepository {
  MockReviewRepository(this._store);

  final MockDataStore _store;

  @override
  Future<Review?> reviewFor(String requestId) async {
    await _store.simulate();
    return _store.reviews[requestId];
  }

  @override
  Future<void> saveReview(Review review) async {
    await _store.simulate();
    _store.reviews[review.requestId] = review;
  }

  @override
  Future<List<Review>> reviewsOfMechanic(String mechanicId) async {
    await _store.simulate();
    final List<Review> list = _store.reviews.values
        .where((Review r) => r.mechanicId == mechanicId)
        .toList();
    list.sort((Review a, Review b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Complaint> addComplaint(Complaint complaint) async {
    await _store.simulate();
    final String id = _store.newId('k');
    final Complaint saved = Complaint(
      id: id,
      requestId: complaint.requestId,
      customerId: complaint.customerId,
      customerName: complaint.customerName,
      mechanicId: complaint.mechanicId,
      mechanicName: complaint.mechanicName,
      category: complaint.category,
      description: complaint.description,
      createdAt: complaint.createdAt,
      status: complaint.status,
      resolution: complaint.resolution,
    );
    _store.complaints[id] = saved;
    return saved;
  }

  @override
  Future<List<Complaint>> complaintsOfRequest(String requestId) async {
    await _store.simulate();
    return _store.complaints.values
        .where((Complaint c) => c.requestId == requestId)
        .toList();
  }

  @override
  Future<List<Complaint>> allComplaints() async {
    await _store.simulate();
    final List<Complaint> list = _store.complaints.values.toList();
    list.sort((Complaint a, Complaint b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> updateComplaint(Complaint complaint) async {
    await _store.simulate();
    _store.complaints[complaint.id] = complaint;
  }
}
