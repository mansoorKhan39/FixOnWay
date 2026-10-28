import '../../models/complaint.dart';
import '../../models/review.dart';
import '../review_repository.dart';
import 'api_client.dart';
import 'codecs.dart';

/// Reviews (one per request, stored under the request id) and complaints.
class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository(this._api);

  final ApiClient _api;

  Complaint _complaint(Map<String, dynamic> m) =>
      Codecs.complaintFromMap(m['id'] as String, m);

  @override
  Future<Review?> reviewFor(String requestId) async {
    if (requestId.isEmpty) return null;
    final Object? json = await _api.getOrNull('/api/reviews/$requestId');
    return json == null ? null : Codecs.reviewFromMap(ApiClient.map(json));
  }

  @override
  Future<void> saveReview(Review review) async {
    await _api.put('/api/reviews/${review.requestId}', Codecs.reviewToMap(review));
  }

  @override
  Future<List<Review>> reviewsOfMechanic(String mechanicId) async {
    final Object? json = await _api.get(
      '/api/reviews',
      query: <String, String>{'mechanicId': mechanicId},
    );
    final List<Review> list = <Review>[
      for (final Map<String, dynamic> m in ApiClient.maps(json))
        Codecs.reviewFromMap(m),
    ];
    list.sort((Review a, Review b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<Complaint> addComplaint(Complaint complaint) async {
    return _complaint(
      ApiClient.map(
        await _api.post('/api/complaints', Codecs.complaintToMap(complaint)),
      ),
    );
  }

  @override
  Future<List<Complaint>> complaintsOfRequest(String requestId) async {
    final Object? json = await _api.get(
      '/api/complaints',
      query: <String, String>{'requestId': requestId},
    );
    return ApiClient.maps(json).map(_complaint).toList();
  }

  @override
  Future<List<Complaint>> allComplaints() async {
    final List<Complaint> list =
        ApiClient.maps(await _api.get('/api/complaints')).map(_complaint).toList();
    list.sort((Complaint a, Complaint b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> updateComplaint(Complaint complaint) async {
    await _api.put(
      '/api/complaints/${complaint.id}',
      Codecs.complaintToMap(complaint),
    );
  }
}
