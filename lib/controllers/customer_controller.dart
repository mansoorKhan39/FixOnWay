import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/complaint.dart';
import '../models/enums/complaint_category.dart';
import '../models/enums/payment_method.dart';
import '../models/enums/problem_type.dart';
import '../models/enums/request_status.dart';
import '../models/enums/vehicle_type.dart';
import '../models/estimate.dart';
import '../models/lat_lng.dart';
import '../models/live_location.dart';
import '../models/mechanic_profile.dart';
import '../models/photo_attachment.dart';
import '../models/review.dart';
import '../models/service_request.dart';
import '../models/vehicle.dart';
import '../services/job_service.dart';
import '../services/payment_service.dart';
import '../services/request_service.dart';
import '../services/review_service.dart';
import '../services/vehicle_service.dart';

/// State for the customer screens (Observer pattern via [ChangeNotifier]).
class CustomerController extends ChangeNotifier {
  CustomerController(
    this._requestService,
    this._vehicleService,
    this._paymentService,
    this._reviewService,
    this._jobService,
  );

  final RequestService _requestService;
  final VehicleService _vehicleService;
  final PaymentService _paymentService;
  final ReviewService _reviewService;
  final JobService _jobService;

  String? _userId;
  List<Vehicle> _vehicles = <Vehicle>[];
  List<ServiceRequest> _requests = <ServiceRequest>[];
  List<AppNotification> _notifications = <AppNotification>[];
  List<NearbyMechanic> _nearby = <NearbyMechanic>[];
  final Map<String, List<Estimate>> _estimates = <String, List<Estimate>>{};
  final Map<String, Review> _reviews = <String, Review>{};
  final Set<String> _complained = <String>{};
  final Map<String, LiveLocation> _live = <String, LiveLocation>{};

  /// Finished requests whose review/complaint were already read, so the
  /// background refresh does not read them again and again.
  final Set<String> _detailsLoaded = <String>{};
  LatLng? _myLocation;
  bool _isLoading = false;
  String? _errorMessage;

  List<Vehicle> get vehicles => _vehicles;
  List<ServiceRequest> get requests => _requests;
  List<AppNotification> get notifications => _notifications;
  List<NearbyMechanic> get nearby => _nearby;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount =>
      _notifications.where((AppNotification n) => !n.read).length;

  ServiceRequest? get activeRequest {
    for (final ServiceRequest r in _requests) {
      if (r.isActive) return r;
    }
    return null;
  }

  ServiceRequest? requestById(String id) {
    for (final ServiceRequest r in _requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<Estimate> estimatesOf(String requestId) =>
      _estimates[requestId] ?? <Estimate>[];

  Review? reviewOf(String requestId) => _reviews[requestId];

  bool hasComplaint(String requestId) => _complained.contains(requestId);

  /// The mechanic's live GPS position for a job, if recent.
  LiveLocation? liveLocationOf(String requestId) => _live[requestId];

  /// The customer's own position (GPS), or null if it was not shared.
  LatLng? get myLocation => _myLocation;

  /// Where to search for mechanics: the customer's position or the default.
  LatLng get searchCenter => _myLocation ?? LatLng.islamabad;

  /// Remembers the customer's position and refreshes the nearby mechanics.
  Future<void> setMyLocation(LatLng position) async {
    _myLocation = position;
    notifyListeners();
    await loadNearby(position);
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    // Often called from initState, so notify after the current build.
    Future<void>.microtask(notifyListeners);
  }

  /// Forget everything (called on logout).
  void clear() {
    _userId = null;
    _vehicles = <Vehicle>[];
    _requests = <ServiceRequest>[];
    _notifications = <AppNotification>[];
    _nearby = <NearbyMechanic>[];
    _estimates.clear();
    _reviews.clear();
    _complained.clear();
    _live.clear();
    _detailsLoaded.clear();
    _myLocation = null;
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

  /// Loads everything at the same time (one round trip instead of many).
  Future<void> _reloadAll() async {
    final String id = _userId!;
    final (
      List<Vehicle> vehicles,
      List<ServiceRequest> requests,
      List<AppNotification> notifications,
    ) = await (
      _vehicleService.list(id),
      _requestService.myRequests(id),
      _requestService.notifications(id),
    ).wait;
    _vehicles = vehicles;
    _requests = requests;
    _notifications = notifications;
    await Future.wait(<Future<void>>[
      for (final ServiceRequest r in _requests) _loadExtras(r),
    ]);
  }

  Future<void> _loadExtras(ServiceRequest r) async {
    final bool alreadyRead =
        r.status.isFinished && _detailsLoaded.contains(r.id);
    final bool needDetails = r.mechanicId != null && !alreadyRead;
    final List<Future<void>> jobs = <Future<void>>[];
    if (r.isActive) {
      jobs.add(() async {
        _estimates[r.id] = await _requestService.estimates(r.id);
      }());
    }
    if (r.status == RequestStatus.onTheWay) {
      jobs.add(() async {
        final LiveLocation? live = await _requestService.liveLocation(r.id);
        if (live == null) {
          _live.remove(r.id);
        } else {
          _live[r.id] = live;
        }
      }());
    }
    if (needDetails) {
      jobs.add(() async {
        final Review? review = await _reviewService.reviewOf(r.id);
        if (review != null) _reviews[r.id] = review;
      }());
      jobs.add(() async {
        final List<Complaint> complaints =
            await _reviewService.complaintsOfRequest(r.id);
        if (complaints.isNotEmpty) _complained.add(r.id);
      }());
    }
    await Future.wait(jobs);
    if (needDetails && r.status.isFinished) _detailsLoaded.add(r.id);
  }

  Future<bool> load(AppUser user) {
    _userId = user.id;
    return _run(_reloadAll);
  }

  /// Refreshes the data without showing the full-screen loader.
  Future<void> refresh() async {
    if (_userId == null) return;
    try {
      await _reloadAll();
      notifyListeners();
    } catch (_) {
      // Keep the old data when a background refresh fails.
    }
  }

  Future<bool> loadNearby(
    LatLng from, {
    int radiusKm = 10,
    ProblemType? problem,
  }) {
    return _run(() async {
      _nearby = await _requestService.nearbyMechanics(
        from,
        radiusKm: radiusKm,
        problem: problem,
      );
    });
  }

  Future<bool> addVehicle({
    required VehicleType type,
    required String make,
    required String model,
    required String plate,
  }) {
    return _run(() async {
      await _vehicleService.add(
        ownerId: _userId!,
        type: type,
        make: make,
        model: model,
        plate: plate,
      );
      _vehicles = await _vehicleService.list(_userId!);
    });
  }

  Future<bool> updateVehicle(
    Vehicle vehicle, {
    required VehicleType type,
    required String make,
    required String model,
    required String plate,
  }) {
    return _run(() async {
      await _vehicleService.update(
        vehicle,
        type: type,
        make: make,
        model: model,
        plate: plate,
      );
      _vehicles = await _vehicleService.list(_userId!);
    });
  }

  Future<bool> removeVehicle(Vehicle vehicle) {
    return _run(() async {
      await _vehicleService.remove(vehicle);
      _vehicles = await _vehicleService.list(_userId!);
    });
  }

  /// Returns the new request, or null when something failed.
  Future<ServiceRequest?> createRequest({
    required AppUser customer,
    required Vehicle vehicle,
    required ProblemType problem,
    required String description,
    required LatLng location,
    required String address,
    required List<PhotoAttachment> photos,
  }) async {
    ServiceRequest? created;
    final bool ok = await _run(() async {
      created = await _requestService.createRequest(
        customer: customer,
        vehicle: vehicle,
        problem: problem,
        description: description,
        location: location,
        address: address,
        photos: photos,
      );
      await _reloadAll();
    });
    return ok ? created : null;
  }

  Future<bool> acceptEstimate(String requestId, String estimateId) {
    return _run(() async {
      await _requestService.acceptEstimate(requestId, estimateId);
      await _reloadAll();
    });
  }

  Future<bool> declineEstimate(String estimateId) {
    return _run(() async {
      await _requestService.declineEstimate(estimateId);
      await _reloadAll();
    });
  }

  Future<bool> cancelRequest(String requestId, String reason) {
    return _run(() async {
      await _requestService.cancel(requestId, reason: reason);
      await _reloadAll();
    });
  }

  /// Development helper (see [RequestService.simulateEstimate]).
  Future<bool> simulateEstimate(String requestId) {
    return _run(() async {
      await _requestService.simulateEstimate(requestId);
      await _reloadAll();
    });
  }

  Future<bool> markNotificationsRead() {
    return _run(() async {
      await _requestService.markNotificationsRead(_userId!);
      _notifications = await _requestService.notifications(_userId!);
    });
  }

  Future<MechanicProfile?> mechanicProfile(String userId) async {
    try {
      return await _requestService.mechanicProfile(userId);
    } on AppException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    }
  }

  /// UC-18.
  Future<bool> pay(
    String requestId,
    PaymentMethod method, {
    String? account,
  }) {
    return _run(() async {
      _detailsLoaded.remove(requestId);
      await _paymentService.pay(
        requestId: requestId,
        customerId: _userId!,
        method: method,
        account: account,
      );
      await _reloadAll();
    });
  }

  /// UC-19.
  Future<bool> submitReview(String requestId, int rating, String comment) {
    return _run(() async {
      _detailsLoaded.remove(requestId);
      await _reviewService.submitReview(
        requestId: requestId,
        customerId: _userId!,
        rating: rating,
        comment: comment,
      );
      await _reloadAll();
    });
  }

  Future<bool> skipReview(String requestId) {
    return _run(() async {
      _detailsLoaded.remove(requestId);
      await _reviewService.skipReview(requestId, _userId!);
      await _reloadAll();
    });
  }

  /// UC-22.
  Future<bool> submitComplaint(
    String requestId,
    ComplaintCategory category,
    String description,
  ) {
    return _run(() async {
      _detailsLoaded.remove(requestId);
      await _reviewService.submitComplaint(
        requestId: requestId,
        customerId: _userId!,
        category: category,
        description: description,
      );
      await _reloadAll();
    });
  }

  /// Development helper: moves the job one step forward on behalf of the
  /// assigned mechanic, so the customer side can be tried alone.
  Future<bool> debugAdvanceJob(String requestId) {
    return _run(() async {
      final ServiceRequest r = await _requestService.requestById(requestId);
      final String? mechanicId = r.mechanicId;
      if (mechanicId == null) {
        throw const AppException('No mechanic is assigned yet.');
      }
      switch (r.status) {
        case RequestStatus.accepted:
          await _jobService.startTrip(mechanicId, requestId);
        case RequestStatus.onTheWay:
          await _jobService.markArrived(mechanicId, requestId);
        case RequestStatus.arrived:
          await _jobService.startWork(mechanicId, requestId);
        case RequestStatus.working:
          await _jobService.completeJob(mechanicId, requestId);
        case RequestStatus.completed:
          if (r.awaitingCashConfirmation) {
            await _paymentService.confirmCash(
              requestId: requestId,
              mechanicId: mechanicId,
            );
          }
        default:
          break;
      }
      await _reloadAll();
    });
  }
}
