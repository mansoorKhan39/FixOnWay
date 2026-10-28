import '../models/complaint.dart';
import '../models/review.dart';

/// Reviews (UC-19, UC-33) and complaints (UC-22, UC-38).
abstract class ReviewRepository {
  Future<Review?> reviewFor(String requestId);

  Future<void> saveReview(Review review);

  Future<List<Review>> reviewsOfMechanic(String mechanicId);

  Future<Complaint> addComplaint(Complaint complaint);

  Future<List<Complaint>> complaintsOfRequest(String requestId);

  Future<List<Complaint>> allComplaints();

  Future<void> updateComplaint(Complaint complaint);
}
