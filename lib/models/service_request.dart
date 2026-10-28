import 'enums/payment_method.dart';
import 'enums/problem_type.dart';
import 'enums/request_status.dart';
import 'enums/vehicle_type.dart';
import 'lat_lng.dart';
import 'photo_attachment.dart';

/// A customer's help request (UC-08).
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.vehicleId,
    required this.vehicleTitle,
    required this.vehicleType,
    required this.problem,
    required this.description,
    required this.location,
    required this.address,
    required this.photos,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.mechanicId,
    this.mechanicName,
    this.acceptedEstimateId,
    this.agreedAmount,
    this.cancelReason,
    this.etaMinutes,
    this.mechanicStart,
    this.startedAt,
    this.completedAt,
    this.paymentMethod,
    this.paidAt,
    this.rejectedBy = const <String>{},
  });

  final String id;
  final String customerId;
  final String customerName;
  final String vehicleId;
  final String vehicleTitle;
  final VehicleType vehicleType;
  final ProblemType problem;
  final String description;
  final LatLng location;
  final String address;
  final List<PhotoAttachment> photos;
  final RequestStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? mechanicId;
  final String? mechanicName;
  final String? acceptedEstimateId;
  final int? agreedAmount;
  final String? cancelReason;

  /// Promised arrival time from the accepted estimate.
  final int? etaMinutes;

  /// Where the mechanic was when the trip started (UC-15).
  final LatLng? mechanicStart;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Set once the customer chose how to pay (UC-18).
  final PaymentMethod? paymentMethod;
  final DateTime? paidAt;

  /// Mechanics who rejected this request (UC-27).
  final Set<String> rejectedBy;

  /// Cash chosen but the mechanic has not confirmed it yet (UC-40).
  bool get awaitingCashConfirmation =>
      status == RequestStatus.completed &&
      paymentMethod == PaymentMethod.cash;

  /// Still in progress (not closed, cancelled or expired).
  bool get isActive => !status.isFinished;

  ServiceRequest copyWith({
    RequestStatus? status,
    DateTime? updatedAt,
    String? mechanicId,
    String? mechanicName,
    String? acceptedEstimateId,
    int? agreedAmount,
    String? cancelReason,
    int? etaMinutes,
    LatLng? mechanicStart,
    DateTime? startedAt,
    DateTime? completedAt,
    PaymentMethod? paymentMethod,
    DateTime? paidAt,
    Set<String>? rejectedBy,
  }) {
    return ServiceRequest(
      id: id,
      customerId: customerId,
      customerName: customerName,
      vehicleId: vehicleId,
      vehicleTitle: vehicleTitle,
      vehicleType: vehicleType,
      problem: problem,
      description: description,
      location: location,
      address: address,
      photos: photos,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mechanicId: mechanicId ?? this.mechanicId,
      mechanicName: mechanicName ?? this.mechanicName,
      acceptedEstimateId: acceptedEstimateId ?? this.acceptedEstimateId,
      agreedAmount: agreedAmount ?? this.agreedAmount,
      cancelReason: cancelReason ?? this.cancelReason,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      mechanicStart: mechanicStart ?? this.mechanicStart,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
    );
  }
}
