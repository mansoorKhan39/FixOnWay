import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/app_notification.dart';
import '../models/enums/problem_type.dart';
import '../models/enums/request_status.dart';
import '../models/enums/vehicle_type.dart';
import '../models/enums/verification_status.dart';
import '../models/lat_lng.dart';
import '../models/mechanic_application.dart';
import '../models/mechanic_profile.dart';
import '../models/service_request.dart';
import '../repositories/application_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/request_repository.dart';

/// Totals for UC-32.
class Earnings {
  const Earnings({
    required this.total,
    required this.today,
    required this.last7Days,
    required this.jobs,
  });

  final int total;
  final int today;
  final int last7Days;
  final List<ServiceRequest> jobs;
}

/// Mechanic account: UC-23, UC-24, UC-25, UC-32 (and admin approval, UC-34).
class MechanicService {
  MechanicService(
    this._requests,
    this._applications,
    this._auth, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RequestRepository _requests;
  final ApplicationRepository _applications;
  final AuthRepository _auth;
  final DateTime Function() _now;

  Future<MechanicProfile?> profile(String userId) => _requests.mechanic(userId);

  Future<MechanicApplication?> application(String userId) =>
      _applications.byUser(userId);

  /// UC-23.
  Future<MechanicApplication> submitApplication({
    required String userId,
    required String name,
    required String phone,
    required String cnic,
    required int experienceYears,
    required String workshopAddress,
    required Set<ProblemType> services,
    required Set<VehicleType> vehicleTypes,
    required List<String> documents,
  }) async {
    final String? error = Validators.cnic(cnic) ??
        Validators.workshopAddress(workshopAddress) ??
        Validators.experience('$experienceYears');
    if (error != null) throw AppException(error);
    if (services.isEmpty) {
      throw const AppException('Choose at least one service you offer.');
    }
    if (vehicleTypes.isEmpty) {
      throw const AppException('Choose at least one vehicle type.');
    }
    if (documents.length < 2) {
      throw const AppException('Upload at least 2 documents (CNIC front and back).');
    }
    if (documents.length > 5) {
      throw const AppException('You can upload up to 5 documents.');
    }
    final MechanicApplication application = MechanicApplication(
      userId: userId,
      name: name,
      phone: phone,
      cnic: cnic.replaceAll('-', '').trim(),
      experienceYears: experienceYears,
      workshopAddress: workshopAddress.trim(),
      services: services,
      vehicleTypes: vehicleTypes,
      documents: List<String>.unmodifiable(documents),
      submittedAt: _now(),
    );
    await _applications.save(application);
    return application;
  }

  /// UC-34: approving creates the public mechanic profile.
  Future<void> approve(String userId) async {
    final MechanicApplication? application = await _applications.byUser(userId);
    if (application == null) {
      throw const AppException('This mechanic has not submitted details yet.');
    }
    await _auth.setVerificationStatus(
      userId: userId,
      status: VerificationStatus.verified,
    );
    await _requests.saveMechanic(
      MechanicProfile(
        userId: userId,
        name: application.name,
        phone: application.phone,
        location: LatLng.islamabad,
        experienceYears: application.experienceYears,
        services: application.services,
        vehicleTypes: application.vehicleTypes,
      ),
    );
    await _applications.remove(userId);
    await _requests.addNotification(
      AppNotification(
        id: '',
        userId: userId,
        title: 'You are verified',
        body: 'Go online to start receiving requests.',
        createdAt: _now(),
      ),
    );
  }

  /// UC-34: rejecting lets the mechanic fix the details and apply again.
  Future<void> reject(String userId, String reason) async {
    if (reason.trim().isEmpty) {
      throw const AppException('Please give a reason.');
    }
    await _auth.setVerificationStatus(
      userId: userId,
      status: VerificationStatus.rejected,
    );
    await _applications.remove(userId);
    await _requests.addNotification(
      AppNotification(
        id: '',
        userId: userId,
        title: 'Verification rejected',
        body: reason.trim(),
        createdAt: _now(),
      ),
    );
  }

  Future<MechanicProfile> _verifiedProfile(String userId) async {
    final MechanicProfile? profile = await _requests.mechanic(userId);
    if (profile == null) {
      throw const AppException('Your account is not verified yet.');
    }
    return profile;
  }

  /// UC-25.
  Future<MechanicProfile> setOnline(String userId, bool online) async {
    final MechanicProfile profile = await _verifiedProfile(userId);
    final MechanicProfile updated = profile.copyWith(isOnline: online);
    await _requests.saveMechanic(updated);
    return updated;
  }

  /// Sets where the mechanic works from (for example from the phone's GPS).
  Future<MechanicProfile> setLocation(String userId, LatLng location) async {
    final MechanicProfile profile = await _verifiedProfile(userId);
    if (!location.isInPakistan) {
      throw const AppException('That location is outside Pakistan.');
    }
    final MechanicProfile updated = profile.copyWith(location: location);
    await _requests.saveMechanic(updated);
    return updated;
  }

  /// UC-24.
  Future<MechanicProfile> updateServiceArea({
    required String userId,
    required int radiusKm,
    required int startMinutes,
    required int endMinutes,
    required Set<ProblemType> services,
    required Set<VehicleType> vehicleTypes,
  }) async {
    final MechanicProfile profile = await _verifiedProfile(userId);
    if (radiusKm < 1 || radiusKm > 20) {
      throw const AppException('Service radius must be between 1 and 20 km.');
    }
    if (endMinutes <= startMinutes) {
      throw const AppException('Closing time must be after opening time.');
    }
    if (services.isEmpty) {
      throw const AppException('Choose at least one service.');
    }
    if (vehicleTypes.isEmpty) {
      throw const AppException('Choose at least one vehicle type.');
    }
    final MechanicProfile updated = profile.copyWith(
      serviceRadiusKm: radiusKm,
      workingHours: '${formatMinutes(startMinutes)} - ${formatMinutes(endMinutes)}',
      services: services,
      vehicleTypes: vehicleTypes,
    );
    await _requests.saveMechanic(updated);
    return updated;
  }

  /// 540 -> "9:00 AM".
  static String formatMinutes(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    final int hour12 = h % 12 == 0 ? 12 : h % 12;
    final String period = h >= 12 ? 'PM' : 'AM';
    return '$hour12:${m.toString().padLeft(2, '0')} $period';
  }

  /// "9:00 AM - 9:00 PM" -> (540, 1260). Falls back to 9 AM - 9 PM.
  static ({int start, int end}) parseHours(String text) {
    int? parse(String part) {
      final RegExpMatch? m =
          RegExp(r'^(\d{1,2}):(\d{2}) (AM|PM)$').firstMatch(part.trim());
      if (m == null) return null;
      final int h = int.parse(m.group(1)!) % 12;
      final int min = int.parse(m.group(2)!);
      return (h + (m.group(3) == 'PM' ? 12 : 0)) * 60 + min;
    }

    final List<String> parts = text.split(' - ');
    if (parts.length == 2) {
      final int? a = parse(parts[0]);
      final int? b = parse(parts[1]);
      if (a != null && b != null) return (start: a, end: b);
    }
    return (start: 540, end: 1260);
  }

  /// UC-32: money from jobs the customer has paid for.
  Future<Earnings> earnings(String mechanicId) async {
    final DateTime now = _now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final DateTime weekAgo = now.subtract(const Duration(days: 7));
    final List<ServiceRequest> all = await _requests.all();
    final List<ServiceRequest> paid = all
        .where(
          (ServiceRequest r) =>
              r.mechanicId == mechanicId &&
              (r.status == RequestStatus.paid ||
                  r.status == RequestStatus.closed) &&
              r.agreedAmount != null,
        )
        .toList();
    int total = 0;
    int today = 0;
    int week = 0;
    for (final ServiceRequest r in paid) {
      final int amount = r.agreedAmount!;
      final DateTime when = r.paidAt ?? r.updatedAt;
      total += amount;
      if (!when.isBefore(startOfToday)) today += amount;
      if (!when.isBefore(weekAgo)) week += amount;
    }
    return Earnings(total: total, today: today, last7Days: week, jobs: paid);
  }
}
