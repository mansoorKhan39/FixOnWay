import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../models/app_notification.dart';
import '../models/enums/estimate_status.dart';
import '../models/enums/request_status.dart';
import '../models/estimate.dart';
import '../models/lat_lng.dart';
import '../models/mechanic_profile.dart';
import '../models/service_request.dart';
import '../repositories/request_repository.dart';

/// A request a mechanic can answer, with the distance and the mechanic's
/// own estimate (if one was sent).
class IncomingRequest {
  const IncomingRequest(this.request, this.distanceKm, this.myEstimate);

  final ServiceRequest request;
  final double distanceKm;
  final Estimate? myEstimate;
}

/// Mechanic side of the job: UC-26 to UC-31.
class JobService {
  JobService(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final RequestRepository _repository;
  final DateTime Function() _now;

  Future<void> _notify(
    String userId,
    String title,
    String body,
    String requestId,
  ) {
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

  /// UC-26: open requests near an online mechanic that match what they offer.
  Future<List<IncomingRequest>> incoming(String mechanicId) async {
    final MechanicProfile? mechanic = await _repository.mechanic(mechanicId);
    if (mechanic == null || !mechanic.isOnline) return <IncomingRequest>[];

    final DateTime now = _now();
    final List<ServiceRequest> all = await _repository.all();
    final List<IncomingRequest> result = <IncomingRequest>[];
    for (final ServiceRequest r in all) {
      if (r.status != RequestStatus.pending &&
          r.status != RequestStatus.estimated) {
        continue;
      }
      if (now.difference(r.createdAt) >= AppConstants.requestExpiry) continue;
      if (r.rejectedBy.contains(mechanicId)) continue;
      if (!mechanic.services.contains(r.problem)) continue;
      if (!mechanic.vehicleTypes.contains(r.vehicleType)) continue;
      final double km = mechanic.location.distanceKmTo(r.location);
      if (km > mechanic.serviceRadiusKm) continue;

      final List<Estimate> estimates = await _repository.estimatesFor(r.id);
      Estimate? mine;
      bool declined = false;
      for (final Estimate e in estimates) {
        if (e.mechanicId != mechanicId) continue;
        if (e.status == EstimateStatus.offered && !e.isExpiredAt(now)) {
          mine = e;
        }
        if (e.status == EstimateStatus.declined) declined = true;
      }
      if (declined && mine == null) continue;
      result.add(IncomingRequest(r, km, mine));
    }
    result.sort(
      (IncomingRequest a, IncomingRequest b) =>
          a.distanceKm.compareTo(b.distanceKm),
    );
    return result;
  }

  /// UC-27 (reject).
  Future<void> reject(String mechanicId, String requestId) async {
    final ServiceRequest? r = await _repository.byId(requestId);
    if (r == null) throw const AppException('Request not found.');
    if (r.status != RequestStatus.pending &&
        r.status != RequestStatus.estimated) {
      throw const AppException('This request is no longer open.');
    }
    await _repository.update(
      r.copyWith(rejectedBy: <String>{...r.rejectedBy, mechanicId}),
    );
  }

  /// All jobs of a mechanic, newest first.
  Future<List<ServiceRequest>> myJobs(String mechanicId) async {
    final List<ServiceRequest> all = await _repository.all();
    return all
        .where((ServiceRequest r) => r.mechanicId == mechanicId)
        .toList();
  }

  Future<ServiceRequest> _ownJob(String mechanicId, String requestId) async {
    final ServiceRequest? r = await _repository.byId(requestId);
    if (r == null) throw const AppException('Request not found.');
    if (r.mechanicId != mechanicId) {
      throw const AppException('This job belongs to another mechanic.');
    }
    return r;
  }

  Future<ServiceRequest> _move(
    String mechanicId,
    String requestId,
    RequestStatus next, {
    required String notifyTitle,
    required String notifyBody,
    ServiceRequest Function(ServiceRequest r, DateTime now)? extra,
  }) async {
    final ServiceRequest r = await _ownJob(mechanicId, requestId);
    if (!r.status.canMoveTo(next)) {
      throw AppException(
        'You cannot do this while the job is "${r.status.name}".',
      );
    }
    final DateTime now = _now();
    ServiceRequest updated = r.copyWith(status: next, updatedAt: now);
    if (extra != null) updated = extra(updated, now);
    await _repository.update(updated);
    await _notify(r.customerId, notifyTitle, notifyBody, requestId);
    return updated;
  }

  /// UC-29 / UC-30: start driving to the customer.
  Future<ServiceRequest> startTrip(String mechanicId, String requestId) async {
    final MechanicProfile? mechanic = await _repository.mechanic(mechanicId);
    if (mechanic == null) throw const AppException('Mechanic not found.');
    return _move(
      mechanicId,
      requestId,
      RequestStatus.onTheWay,
      notifyTitle: 'Mechanic is on the way',
      notifyBody: '${mechanic.name} has started driving to you.',
      extra: (ServiceRequest r, DateTime now) => r.copyWith(
        mechanicStart: mechanic.location,
        startedAt: now,
      ),
    );
  }

  /// Live GPS: the mechanic's phone reports where it is while on the way.
  Future<void> reportLocation(
    String mechanicId,
    String requestId,
    LatLng position,
  ) async {
    final ServiceRequest? r = await _repository.byId(requestId);
    if (r == null || r.mechanicId != mechanicId) {
      throw const AppException('This is not your job.');
    }
    if (r.status != RequestStatus.onTheWay) {
      throw const AppException('Location is shared only while you are on the way.');
    }
    if (!position.isInPakistan) {
      throw const AppException('That location is outside Pakistan.');
    }
    await _repository.saveLiveLocation(requestId, position, _now());
  }

  Future<ServiceRequest> markArrived(String mechanicId, String requestId) {
    return _move(
      mechanicId,
      requestId,
      RequestStatus.arrived,
      notifyTitle: 'Mechanic has arrived',
      notifyBody: 'Your mechanic is at your location.',
    );
  }

  Future<ServiceRequest> startWork(String mechanicId, String requestId) {
    return _move(
      mechanicId,
      requestId,
      RequestStatus.working,
      notifyTitle: 'Work started',
      notifyBody: 'The mechanic has started working on your vehicle.',
    );
  }

  /// UC-31.
  Future<ServiceRequest> completeJob(String mechanicId, String requestId) {
    return _move(
      mechanicId,
      requestId,
      RequestStatus.completed,
      notifyTitle: 'Job completed',
      notifyBody: 'Please check the work and pay to finish.',
      extra: (ServiceRequest r, DateTime now) => r.copyWith(completedAt: now),
    );
  }
}
