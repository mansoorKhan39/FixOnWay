import 'enums/problem_type.dart';
import 'enums/vehicle_type.dart';

/// UC-23: the details a mechanic submits for verification.
class MechanicApplication {
  const MechanicApplication({
    required this.userId,
    required this.name,
    required this.phone,
    required this.cnic,
    required this.experienceYears,
    required this.workshopAddress,
    required this.services,
    required this.vehicleTypes,
    required this.documents,
    required this.submittedAt,
  });

  final String userId;
  final String name;
  final String phone;
  final String cnic;
  final int experienceYears;
  final String workshopAddress;
  final Set<ProblemType> services;
  final Set<VehicleType> vehicleTypes;

  /// Names of the uploaded documents (CNIC front/back, licence, ...).
  final List<String> documents;
  final DateTime submittedAt;
}
