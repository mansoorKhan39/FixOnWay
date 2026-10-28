import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/enums/problem_type.dart';
import '../models/enums/vehicle_type.dart';
import '../models/lat_lng.dart';
import '../models/mechanic_application.dart';
import '../models/mechanic_profile.dart';
import '../models/review.dart';
import '../models/service_request.dart';
import '../services/job_service.dart';
import '../services/mechanic_service.dart';
import '../services/payment_service.dart';
import '../services/request_service.dart';
import '../services/review_service.dart';

/// State for the mechanic screens (Observer pattern via [ChangeNotifier]).
class MechanicController extends ChangeNotifier {
  MechanicController(
    this._mechanics,
    this._jobs,
    this._requests,
    this._payments,
    this._reviews,
  );

  final MechanicService _mechanics;
  final JobService _jobs;
  final RequestService _requests;
  final PaymentService _payments;
  final ReviewService _reviews;

  String? _userId;
  MechanicProfile? _profile;
  MechanicApplication? _application;
  List<IncomingRequest> _incoming = <IncomingRequest>[];
  List<ServiceRequest> _myJobs = <ServiceRequest>[];
  List<AppNotification> _notifications = <AppNotification>[];
  List<Review> _myReviews = <Review>[];
  Earnings? _earnings;
  bool _isLoading = false;
  String? _errorMessage;

  MechanicProfile? get profile => _profile;
  MechanicApplication? get application => _application;
  List<IncomingRequest> get incoming => _incoming;
  List<ServiceRequest> get myJobs => _myJobs;
  List<AppNotification> get notifications => _notifications;
  List<Review> get reviews => _myReviews;
  Earnings? get earnings => _earnings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount =>
      _notifications.where((AppNotification n) => !n.read).length;

  /// The job the mechanic is working on right now, if any.
  ServiceRequest? get activeJob {
    for (final ServiceRequest r in _myJobs) {
      if (r.isActive) return r;
    }
    return null;
  }

  ServiceRequest? jobById(String id) {
    for (final ServiceRequest r in _myJobs) {
      if (r.id == id) return r;
    }
    return null;
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    Future<void>.microtask(notifyListeners);
  }

  void clear() {
    _userId = null;
    _profile = null;
    _application = null;
    _incoming = <IncomingRequest>[];
    _myJobs = <ServiceRequest>[];
    _notifications = <AppNotification>[];
    _myReviews = <Review>[];
    _earnings = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads everything at the same time (one round trip instead of seven).
  Future<void> _reloadAll() async {
    final String id = _userId!;
    final r = await (
      _mechanics.profile(id),
      _mechanics.application(id),
      _jobs.incoming(id),
      _jobs.myJobs(id),
      _requests.notifications(id),
      _reviews.reviewsOfMechanic(id),
      _mechanics.earnings(id),
    ).wait;
    _profile = r.$1;
    _application = r.$2;
    _incoming = r.$3;
    _myJobs = r.$4;
    _notifications = r.$5;
    _myReviews = r.$6;
    _earnings = r.$7;
  }

  Future<bool> load(AppUser user) {
    _userId = user.id;
    return _run(_reloadAll);
  }

  /// Background refresh without the loader.
  Future<void> refresh() async {
    if (_userId == null) return;
    try {
      await _reloadAll();
      notifyListeners();
    } catch (_) {
      // Keep the old data when a background refresh fails.
    }
  }

  /// UC-23.
  Future<bool> submitApplication({
    required AppUser user,
    required String cnic,
    required int experienceYears,
    required String workshopAddress,
    required Set<ProblemType> services,
    required Set<VehicleType> vehicleTypes,
    required List<String> documents,
  }) {
    return _run(() async {
      await _mechanics.submitApplication(
        userId: user.id,
        name: user.name,
        phone: user.phone,
        cnic: cnic,
        experienceYears: experienceYears,
        workshopAddress: workshopAddress,
        services: services,
        vehicleTypes: vehicleTypes,
        documents: documents,
      );
      await _reloadAll();
    });
  }

  /// Development helper until the admin screens exist.
  Future<bool> approveMyself() {
    return _run(() async {
      await _mechanics.approve(_userId!);
      await _reloadAll();
    });
  }

  /// UC-25.
  Future<bool> setOnline(bool online) {
    return _run(() async {
      _profile = await _mechanics.setOnline(_userId!, online);
      _incoming = await _jobs.incoming(_userId!);
    });
  }

  /// Saves the mechanic's work location (for example the phone's GPS).
  Future<bool> setLocation(LatLng location) {
    return _run(() async {
      _profile = await _mechanics.setLocation(_userId!, location);
    });
  }

  /// Live GPS while driving to a customer. Quiet: a failed update is
  /// ignored, the next one will try again.
  Future<void> shareLocation(String requestId, LatLng position) async {
    final String? id = _userId;
    if (id == null) return;
    try {
      await _jobs.reportLocation(id, requestId, position);
    } catch (_) {
      // Not on the way any more, or no network. Nothing to show.
    }
  }

  /// UC-24.
  Future<bool> updateServiceArea({
    required int radiusKm,
    required int startMinutes,
    required int endMinutes,
    required Set<ProblemType> services,
    required Set<VehicleType> vehicleTypes,
  }) {
    return _run(() async {
      _profile = await _mechanics.updateServiceArea(
        userId: _userId!,
        radiusKm: radiusKm,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        services: services,
        vehicleTypes: vehicleTypes,
      );
    });
  }

  /// UC-27 / UC-28.
  Future<bool> sendEstimate({
    required String requestId,
    required int amount,
    required int etaMinutes,
    required String note,
  }) {
    return _run(() async {
      await _requests.submitEstimate(
        mechanicId: _userId!,
        requestId: requestId,
        amount: amount,
        etaMinutes: etaMinutes,
        note: note,
      );
      await _reloadAll();
    });
  }

  Future<bool> reject(String requestId) {
    return _run(() async {
      await _jobs.reject(_userId!, requestId);
      await _reloadAll();
    });
  }

  /// UC-29, UC-31: runs one of the job actions and reloads the data.
  Future<bool> _jobAction(
    Future<ServiceRequest> Function(String mechanicId) action,
  ) {
    return _run(() async {
      await action(_userId!);
      await _reloadAll();
    });
  }

  Future<bool> startTrip(String requestId) =>
      _jobAction((String id) => _jobs.startTrip(id, requestId));

  Future<bool> markArrived(String requestId) =>
      _jobAction((String id) => _jobs.markArrived(id, requestId));

  Future<bool> startWork(String requestId) =>
      _jobAction((String id) => _jobs.startWork(id, requestId));

  Future<bool> completeJob(String requestId) =>
      _jobAction((String id) => _jobs.completeJob(id, requestId));

  /// UC-40.
  Future<bool> confirmCash(String requestId) =>
      _jobAction(
        (String id) =>
            _payments.confirmCash(requestId: requestId, mechanicId: id),
      );

  Future<bool> markNotificationsRead() {
    return _run(() async {
      await _requests.markNotificationsRead(_userId!);
      _notifications = await _requests.notifications(_userId!);
    });
  }
}
