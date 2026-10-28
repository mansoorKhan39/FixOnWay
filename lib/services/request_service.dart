import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/enums/estimate_status.dart';
import '../models/enums/problem_type.dart';
import '../models/enums/request_status.dart';
import '../models/estimate.dart';
import '../models/lat_lng.dart';
import '../models/live_location.dart';
import '../models/mechanic_profile.dart';
import '../models/photo_attachment.dart';
import '../models/service_request.dart';
import '../models/vehicle.dart';
import '../repositories/request_repository.dart';

/// A mechanic together with the distance to the customer.
class NearbyMechanic {
  const NearbyMechanic(this.profile, this.distanceKm);

  final MechanicProfile profile;
  final double distanceKm;
}

/// Business rules for UC-08 to UC-14 and UC-17.
class RequestService {
  RequestService(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final RequestRepository _repository;
  final DateTime Function() _now;

  Future<void> _notify(
    String userId,
    String title,
    String body, {
    String? requestId,
  }) {
    return _repository.addNotification(
      AppNotification(
        id: '',
        userId: userId,
        title: title,
        body: body,
        createdAt: _now(),
        requestId: requestId,
      ),
    );
  }

  /// UC-12: online mechanics around [from], nearest first.
  Future<List<NearbyMechanic>> nearbyMechanics(
    LatLng from, {
    int radiusKm = AppConstants.defaultRadiusKm,
    ProblemType? problem,
  }) async {
    if (radiusKm < AppConstants.minRadiusKm ||
        radiusKm > AppConstants.maxRadiusKm) {
      throw const AppException(
        'Radius must be between ${AppConstants.minRadiusKm} and '
        '${AppConstants.maxRadiusKm} km.',
      );
    }
    final List<MechanicProfile> all = await _repository.mechanics();
    final List<NearbyMechanic> result = <NearbyMechanic>[];
    for (final MechanicProfile m in all) {
      if (!m.isOnline) continue;
      if (problem != null && !m.services.contains(problem)) continue;
      final double km = from.distanceKmTo(m.location);
      if (km <= radiusKm) result.add(NearbyMechanic(m, km));
    }
    result.sort(
      (NearbyMechanic a, NearbyMechanic b) =>
          a.distanceKm.compareTo(b.distanceKm),
    );
    return result;
  }

  /// UC-08, UC-09, UC-10, UC-11.
  Future<ServiceRequest> createRequest({
    required AppUser customer,
    required Vehicle vehicle,
    required ProblemType problem,
    required String description,
    required LatLng location,
    required String address,
    List<PhotoAttachment> photos = const <PhotoAttachment>[],
  }) async {
    if (vehicle.ownerId != customer.id) {
      throw const AppException('Please choose one of your own vehicles.');
    }
    final String? descriptionError = Validators.description(
      description,
      isRequired: problem == ProblemType.other,
    );
    if (descriptionError != null) throw AppException(descriptionError);
    if (address.trim().isEmpty) {
      throw const AppException('Please enter your location or address.');
    }
    if (!location.isInPakistan) {
      throw const AppException('Your location must be inside Pakistan.');
    }
    if (photos.length > AppConstants.maxPhotos) {
      throw const AppException(
        'You can attach up to ${AppConstants.maxPhotos} photos.',
      );
    }
    if (photos.any((PhotoAttachment p) => p.sizeBytes > AppConstants.maxPhotoBytes)) {
      throw const AppException('Each photo must be 5 MB or smaller.');
    }

    await refresh(customer.id);
    final List<ServiceRequest> mine = await _repository.byCustomer(customer.id);
    if (mine.any((ServiceRequest r) => r.isActive)) {
      throw const AppException(
        'You already have an active request. Finish or cancel it first.',
      );
    }

    final DateTime now = _now();
    final ServiceRequest created = await _repository.create(
      ServiceRequest(
        id: '',
        customerId: customer.id,
        customerName: customer.name,
        vehicleId: vehicle.id,
        vehicleTitle: '${vehicle.title} (${vehicle.plate})',
        vehicleType: vehicle.type,
        problem: problem,
        description: description.trim(),
        location: location,
        address: address.trim(),
        photos: List<PhotoAttachment>.unmodifiable(photos),
        status: RequestStatus.pending,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final List<NearbyMechanic> nearby = await nearbyMechanics(
      location,
      problem: problem,
    );
    for (final NearbyMechanic m in nearby) {
      await _notify(
        m.profile.userId,
        'New request nearby',
        '${problem.label} - ${m.distanceKm.toStringAsFixed(1)} km away',
        requestId: created.id,
      );
    }
    return created;
  }

  /// Expires old requests and estimates. Safe to call often.
  Future<void> refresh(String customerId) async {
    final DateTime now = _now();
    final List<ServiceRequest> requests =
        await _repository.byCustomer(customerId);
    for (final ServiceRequest r in requests) {
      if (r.status != RequestStatus.pending &&
          r.status != RequestStatus.estimated) {
        continue;
      }
      final List<Estimate> estimates = await _repository.estimatesFor(r.id);
      for (final Estimate e in estimates) {
        if (e.status == EstimateStatus.offered && e.isExpiredAt(now)) {
          await _repository.updateEstimate(e.withStatus(EstimateStatus.expired));
        }
      }
      final List<Estimate> after = await _repository.estimatesFor(r.id);
      final bool hasOffer =
          after.any((Estimate e) => e.status == EstimateStatus.offered);

      if (r.status == RequestStatus.estimated && !hasOffer) {
        await _repository.update(
          r.copyWith(status: RequestStatus.pending, updatedAt: now),
        );
      }
      final bool stale = now.difference(r.createdAt) >= AppConstants.requestExpiry;
      if (stale && !hasOffer) {
        await _repository.update(
          r.copyWith(status: RequestStatus.expired, updatedAt: now),
        );
        await _notify(
          r.customerId,
          'Request expired',
          'No mechanic accepted your ${r.problem.label} request in time.',
          requestId: r.id,
        );
      }
    }
  }

  Future<List<ServiceRequest>> myRequests(String customerId) async {
    await refresh(customerId);
    return _repository.byCustomer(customerId);
  }

  /// The mechanic's live GPS position, or null when there is none (or it
  /// is too old).
  Future<LiveLocation?> liveLocation(String requestId) async {
    final LiveLocation? live = await _repository.liveLocation(requestId);
    if (live == null) return null;
    return live.isFreshAt(_now(), AppConstants.liveLocationMaxAge) ? live : null;
  }

  Future<ServiceRequest> requestById(String id) async {
    final ServiceRequest? r = await _repository.byId(id);
    if (r == null) throw const AppException('Request not found.');
    return r;
  }

  Future<List<Estimate>> estimates(String requestId) =>
      _repository.estimatesFor(requestId);

  /// UC-28: a mechanic offers a price.
  Future<Estimate> submitEstimate({
    required String mechanicId,
    required String requestId,
    required int amount,
    required int etaMinutes,
    String note = '',
  }) async {
    final MechanicProfile? mechanic = await _repository.mechanic(mechanicId);
    if (mechanic == null) throw const AppException('Mechanic not found.');
    if (!mechanic.isOnline) {
      throw const AppException('Go online to send estimates.');
    }
    final ServiceRequest request = await requestById(requestId);
    if (request.status != RequestStatus.pending &&
        request.status != RequestStatus.estimated) {
      throw const AppException('This request is no longer open.');
    }
    final String? amountError = Validators.amount('$amount');
    if (amountError != null) throw AppException(amountError);
    final String? etaError = Validators.eta('$etaMinutes');
    if (etaError != null) throw AppException(etaError);
    if (note.trim().length > 200) {
      throw const AppException('Keep the note under 200 characters.');
    }
    final List<Estimate> existing = await _repository.estimatesFor(requestId);
    if (existing.any(
      (Estimate e) =>
          e.mechanicId == mechanicId && e.status == EstimateStatus.offered,
    )) {
      throw const AppException('You already sent an estimate for this request.');
    }

    final DateTime now = _now();
    final Estimate saved = await _repository.addEstimate(
      Estimate(
        id: '',
        requestId: requestId,
        mechanicId: mechanicId,
        mechanicName: mechanic.name,
        amount: amount,
        etaMinutes: etaMinutes,
        note: note.trim(),
        createdAt: now,
        expiresAt: now.add(AppConstants.estimateValidity),
      ),
    );
    if (request.status == RequestStatus.pending) {
      await _repository.update(
        request.copyWith(status: RequestStatus.estimated, updatedAt: now),
      );
    }
    await _notify(
      request.customerId,
      'New estimate received',
      '${mechanic.name} offered PKR $amount ($etaMinutes min away).',
      requestId: requestId,
    );
    return saved;
  }

  /// UC-14: the customer accepts one estimate.
  Future<ServiceRequest> acceptEstimate(
    String requestId,
    String estimateId,
  ) async {
    final ServiceRequest request = await requestById(requestId);
    if (!request.status.canMoveTo(RequestStatus.accepted)) {
      throw const AppException('This request cannot accept an estimate now.');
    }
    final List<Estimate> all = await _repository.estimatesFor(requestId);
    Estimate? chosen;
    for (final Estimate e in all) {
      if (e.id == estimateId) chosen = e;
    }
    if (chosen == null) throw const AppException('Estimate not found.');
    final DateTime now = _now();
    if (chosen.status != EstimateStatus.offered || chosen.isExpiredAt(now)) {
      throw const AppException('This estimate has expired. Please pick another.');
    }

    for (final Estimate e in all) {
      if (e.id == chosen.id) {
        await _repository.updateEstimate(e.withStatus(EstimateStatus.accepted));
      } else if (e.status == EstimateStatus.offered) {
        await _repository.updateEstimate(e.withStatus(EstimateStatus.declined));
      }
    }
    final ServiceRequest updated = request.copyWith(
      status: RequestStatus.accepted,
      updatedAt: now,
      mechanicId: chosen.mechanicId,
      mechanicName: chosen.mechanicName,
      acceptedEstimateId: chosen.id,
      agreedAmount: chosen.amount,
      etaMinutes: chosen.etaMinutes,
    );
    await _repository.update(updated);
    await _notify(
      chosen.mechanicId,
      'Estimate accepted',
      '${request.customerName} accepted your PKR ${chosen.amount} estimate.',
      requestId: requestId,
    );
    return updated;
  }

  /// UC-14: the customer declines one estimate.
  Future<void> declineEstimate(String estimateId) async {
    Estimate? target;
    ServiceRequest? request;
    final List<ServiceRequest> requests = await _repository.all();
    for (final ServiceRequest r in requests) {
      final List<Estimate> list = await _repository.estimatesFor(r.id);
      for (final Estimate e in list) {
        if (e.id == estimateId) {
          target = e;
          request = r;
        }
      }
    }
    if (target == null || request == null) {
      throw const AppException('Estimate not found.');
    }
    if (target.status != EstimateStatus.offered) {
      throw const AppException('This estimate can no longer be declined.');
    }
    await _repository.updateEstimate(target.withStatus(EstimateStatus.declined));
    final List<Estimate> after = await _repository.estimatesFor(request.id);
    final bool hasOffer =
        after.any((Estimate e) => e.status == EstimateStatus.offered);
    if (!hasOffer && request.status == RequestStatus.estimated) {
      await _repository.update(
        request.copyWith(status: RequestStatus.pending, updatedAt: _now()),
      );
    }
    await _notify(
      target.mechanicId,
      'Estimate declined',
      '${request.customerName} declined your estimate.',
      requestId: request.id,
    );
  }

  /// UC-17.
  Future<ServiceRequest> cancel(String requestId, {String reason = ''}) async {
    final ServiceRequest request = await requestById(requestId);
    if (!request.status.canMoveTo(RequestStatus.cancelled)) {
      throw const AppException('This request can no longer be cancelled.');
    }
    if (reason.trim().length > 200) {
      throw const AppException('Keep the reason under 200 characters.');
    }
    final DateTime now = _now();
    final List<Estimate> estimates = await _repository.estimatesFor(requestId);
    for (final Estimate e in estimates) {
      if (e.status == EstimateStatus.offered) {
        await _repository.updateEstimate(e.withStatus(EstimateStatus.declined));
      }
    }
    final ServiceRequest updated = request.copyWith(
      status: RequestStatus.cancelled,
      updatedAt: now,
      cancelReason: reason.trim().isEmpty ? 'No reason given' : reason.trim(),
    );
    await _repository.update(updated);
    if (request.mechanicId != null) {
      await _notify(
        request.mechanicId!,
        'Request cancelled',
        '${request.customerName} cancelled the ${request.problem.label} request.',
        requestId: requestId,
      );
    }
    return updated;
  }

  /// Development helper: the nearest suitable mechanic sends an estimate, so
  /// the customer flow can be tried without a second login.
  Future<Estimate> simulateEstimate(String requestId) async {
    final ServiceRequest request = await requestById(requestId);
    final List<NearbyMechanic> nearby = await nearbyMechanics(
      request.location,
      problem: request.problem,
    );
    final List<Estimate> existing = await _repository.estimatesFor(requestId);
    for (final NearbyMechanic m in nearby) {
      if (!m.profile.vehicleTypes.contains(request.vehicleType)) continue;
      final bool already =
          existing.any((Estimate e) => e.mechanicId == m.profile.userId);
      if (already) continue;
      final int base = switch (request.problem) {
        ProblemType.flatTire => 800,
        ProblemType.batteryJump => 1000,
        ProblemType.outOfFuel => 700,
        ProblemType.engineTrouble => 2500,
        ProblemType.towing => 4000,
        ProblemType.lockout => 1500,
        ProblemType.other => 1200,
      };
      final int amount = base + (m.distanceKm * 50).round();
      final int eta = (m.distanceKm * 4).round() + 5;
      return submitEstimate(
        mechanicId: m.profile.userId,
        requestId: requestId,
        amount: amount,
        etaMinutes: eta,
        note: 'On my way after you accept.',
      );
    }
    throw const AppException('No more mechanics available nearby.');
  }

  Future<List<AppNotification>> notifications(String userId) =>
      _repository.notificationsFor(userId);

  Future<void> markNotificationsRead(String userId) =>
      _repository.markAllNotificationsRead(userId);

  Future<MechanicProfile> mechanicProfile(String userId) async {
    final MechanicProfile? m = await _repository.mechanic(userId);
    if (m == null) throw const AppException('Mechanic not found.');
    return m;
  }
}
