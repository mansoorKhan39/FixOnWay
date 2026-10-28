import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/app_notification.dart';
import '../models/complaint.dart';
import '../models/enums/complaint_category.dart';
import '../models/enums/request_status.dart';
import '../models/mechanic_profile.dart';
import '../models/review.dart';
import '../models/service_request.dart';
import '../repositories/request_repository.dart';
import '../repositories/review_repository.dart';

/// UC-19 Rate and review, UC-22 Submit complaint, UC-33 View reviews.
class ReviewService {
  ReviewService(this._requests, this._reviews, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final RequestRepository _requests;
  final ReviewRepository _reviews;
  final DateTime Function() _now;

  Future<ServiceRequest> _ownRequest(String id, String customerId) async {
    final ServiceRequest? r = await _requests.byId(id);
    if (r == null) throw const AppException('Request not found.');
    if (r.customerId != customerId) {
      throw const AppException('This is not your request.');
    }
    return r;
  }

  Future<Review?> reviewOf(String requestId) => _reviews.reviewFor(requestId);

  Future<List<Review>> reviewsOfMechanic(String mechanicId) =>
      _reviews.reviewsOfMechanic(mechanicId);

  /// UC-19: also closes the request and updates the mechanic's rating.
  Future<Review> submitReview({
    required String requestId,
    required String customerId,
    required int rating,
    String comment = '',
  }) async {
    final ServiceRequest r = await _ownRequest(requestId, customerId);
    if (r.status != RequestStatus.paid) {
      throw const AppException('You can rate the mechanic after paying.');
    }
    if (r.mechanicId == null) {
      throw const AppException('This request has no mechanic.');
    }
    if (rating < 1 || rating > 5) {
      throw const AppException('Rating must be between 1 and 5 stars.');
    }
    if (comment.trim().length > AppConstants.maxReviewLength) {
      throw const AppException(
        'Keep the review under ${AppConstants.maxReviewLength} characters.',
      );
    }
    if (await _reviews.reviewFor(requestId) != null) {
      throw const AppException('You already reviewed this job.');
    }

    final DateTime now = _now();
    final Review review = Review(
      requestId: requestId,
      customerId: customerId,
      customerName: r.customerName,
      mechanicId: r.mechanicId!,
      rating: rating,
      comment: comment.trim(),
      createdAt: now,
    );
    await _reviews.saveReview(review);

    final MechanicProfile? m = await _requests.mechanic(r.mechanicId!);
    if (m != null) {
      final double total = m.rating * m.reviewCount + rating;
      final int count = m.reviewCount + 1;
      await _requests.saveMechanic(
        m.copyWith(rating: total / count, reviewCount: count),
      );
    }
    await _requests.update(
      r.copyWith(status: RequestStatus.closed, updatedAt: now),
    );
    await _requests.addNotification(
      AppNotification(
        id: '',
        userId: r.mechanicId!,
        title: 'New review',
        body: '${r.customerName} gave you $rating star(s).',
        createdAt: now,
        requestId: requestId,
      ),
    );
    return review;
  }

  /// Closes a paid request without a review.
  Future<void> skipReview(String requestId, String customerId) async {
    final ServiceRequest r = await _ownRequest(requestId, customerId);
    if (r.status != RequestStatus.paid) {
      throw const AppException('This request cannot be closed yet.');
    }
    await _requests.update(
      r.copyWith(status: RequestStatus.closed, updatedAt: _now()),
    );
  }

  /// UC-22: a complaint on a completed request puts it into "disputed".
  Future<Complaint> submitComplaint({
    required String requestId,
    required String customerId,
    required ComplaintCategory category,
    required String description,
  }) async {
    final ServiceRequest r = await _ownRequest(requestId, customerId);
    final List<Complaint> existing = await _reviews.complaintsOfRequest(requestId);
    if (existing.isNotEmpty) {
      throw const AppException('You already submitted a complaint for this job.');
    }
    const Set<RequestStatus> allowed = <RequestStatus>{
      RequestStatus.completed,
      RequestStatus.paid,
      RequestStatus.closed,
    };
    if (!allowed.contains(r.status)) {
      throw const AppException(
        'You can complain once the job is completed.',
      );
    }
    final String text = description.trim();
    if (text.length < AppConstants.minComplaintLength) {
      throw const AppException(
        'Please describe the problem (at least '
        '${AppConstants.minComplaintLength} characters).',
      );
    }
    if (text.length > AppConstants.maxComplaintLength) {
      throw const AppException(
        'Keep the complaint under ${AppConstants.maxComplaintLength} characters.',
      );
    }

    final DateTime now = _now();
    final Complaint saved = await _reviews.addComplaint(
      Complaint(
        id: '',
        requestId: requestId,
        customerId: customerId,
        customerName: r.customerName,
        mechanicId: r.mechanicId,
        mechanicName: r.mechanicName,
        category: category,
        description: text,
        createdAt: now,
      ),
    );
    if (r.status == RequestStatus.completed) {
      await _requests.update(
        r.copyWith(status: RequestStatus.disputed, updatedAt: now),
      );
    }
    await _requests.addNotification(
      AppNotification(
        id: '',
        userId: customerId,
        title: 'Complaint received',
        body: 'Our team will review it and get back to you.',
        createdAt: now,
        requestId: requestId,
      ),
    );
    return saved;
  }

  Future<List<Complaint>> complaintsOfRequest(String requestId) =>
      _reviews.complaintsOfRequest(requestId);
}
