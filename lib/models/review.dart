/// UC-19: a customer's rating of a finished job. One review per request.
class Review {
  const Review({
    required this.requestId,
    required this.customerId,
    required this.customerName,
    required this.mechanicId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String requestId;
  final String customerId;
  final String customerName;
  final String mechanicId;

  /// 1 to 5.
  final int rating;
  final String comment;
  final DateTime createdAt;
}
