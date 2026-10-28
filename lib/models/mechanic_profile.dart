import 'enums/problem_type.dart';
import 'enums/vehicle_type.dart';
import 'lat_lng.dart';

/// Public details of a verified mechanic (UC-12, UC-24, UC-41).
class MechanicProfile {
  const MechanicProfile({
    required this.userId,
    required this.name,
    required this.phone,
    required this.location,
    this.rating = 0,
    this.reviewCount = 0,
    this.jobsDone = 0,
    this.experienceYears = 0,
    this.bio = '',
    this.services = const <ProblemType>{},
    this.vehicleTypes = const <VehicleType>{},
    this.isOnline = false,
    this.serviceRadiusKm = 10,
    this.workingHours = '9:00 AM - 9:00 PM',
  });

  final String userId;
  final String name;
  final String phone;
  final LatLng location;
  final double rating;
  final int reviewCount;
  final int jobsDone;
  final int experienceYears;
  final String bio;
  final Set<ProblemType> services;
  final Set<VehicleType> vehicleTypes;
  final bool isOnline;
  final int serviceRadiusKm;
  final String workingHours;

  MechanicProfile copyWith({
    LatLng? location,
    double? rating,
    int? reviewCount,
    int? jobsDone,
    String? bio,
    Set<ProblemType>? services,
    Set<VehicleType>? vehicleTypes,
    bool? isOnline,
    int? serviceRadiusKm,
    String? workingHours,
  }) {
    return MechanicProfile(
      userId: userId,
      name: name,
      phone: phone,
      location: location ?? this.location,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      jobsDone: jobsDone ?? this.jobsDone,
      experienceYears: experienceYears,
      bio: bio ?? this.bio,
      services: services ?? this.services,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      isOnline: isOnline ?? this.isOnline,
      serviceRadiusKm: serviceRadiusKm ?? this.serviceRadiusKm,
      workingHours: workingHours ?? this.workingHours,
    );
  }
}
