import 'enums/estimate_status.dart';

/// A mechanic's price offer for a request (UC-28 / UC-13).
class Estimate {
  const Estimate({
    required this.id,
    required this.requestId,
    required this.mechanicId,
    required this.mechanicName,
    required this.amount,
    required this.etaMinutes,
    required this.createdAt,
    required this.expiresAt,
    this.note = '',
    this.status = EstimateStatus.offered,
  });

  final String id;
  final String requestId;
  final String mechanicId;
  final String mechanicName;

  /// Price in PKR.
  final int amount;
  final int etaMinutes;
  final String note;
  final DateTime createdAt;
  final DateTime expiresAt;
  final EstimateStatus status;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  Estimate withStatus(EstimateStatus newStatus) {
    return Estimate(
      id: id,
      requestId: requestId,
      mechanicId: mechanicId,
      mechanicName: mechanicName,
      amount: amount,
      etaMinutes: etaMinutes,
      note: note,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: newStatus,
    );
  }
}
