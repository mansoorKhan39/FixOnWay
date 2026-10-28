import 'enums/complaint_category.dart';
import 'enums/complaint_status.dart';

/// UC-22: a complaint about a job. Admins handle it in UC-38.
class Complaint {
  const Complaint({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.customerName,
    required this.category,
    required this.description,
    required this.createdAt,
    this.mechanicId,
    this.mechanicName,
    this.status = ComplaintStatus.open,
    this.resolution = '',
  });

  final String id;
  final String requestId;
  final String customerId;
  final String customerName;
  final String? mechanicId;
  final String? mechanicName;
  final ComplaintCategory category;
  final String description;
  final DateTime createdAt;
  final ComplaintStatus status;
  final String resolution;

  Complaint resolve(ComplaintStatus newStatus, String note) => Complaint(
        id: id,
        requestId: requestId,
        customerId: customerId,
        customerName: customerName,
        mechanicId: mechanicId,
        mechanicName: mechanicName,
        category: category,
        description: description,
        createdAt: createdAt,
        status: newStatus,
        resolution: note,
      );
}
