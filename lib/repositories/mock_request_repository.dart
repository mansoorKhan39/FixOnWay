import '../models/app_notification.dart';
import '../models/estimate.dart';
import '../models/lat_lng.dart';
import '../models/live_location.dart';
import '../models/mechanic_profile.dart';
import '../models/service_request.dart';
import 'mock_data_store.dart';
import 'request_repository.dart';

class MockRequestRepository implements RequestRepository {
  MockRequestRepository(this._store);

  final MockDataStore _store;

  @override
  Future<ServiceRequest> create(ServiceRequest request) async {
    await _store.simulate();
    final String id = _store.newId('r');
    final ServiceRequest saved = ServiceRequest(
      id: id,
      customerId: request.customerId,
      customerName: request.customerName,
      vehicleId: request.vehicleId,
      vehicleTitle: request.vehicleTitle,
      vehicleType: request.vehicleType,
      problem: request.problem,
      description: request.description,
      location: request.location,
      address: request.address,
      photos: request.photos,
      status: request.status,
      createdAt: request.createdAt,
      updatedAt: request.updatedAt,
    );
    _store.requests[id] = saved;
    return saved;
  }

  @override
  Future<void> update(ServiceRequest request) async {
    await _store.simulate();
    _store.requests[request.id] = request;
  }

  @override
  Future<ServiceRequest?> byId(String id) async {
    await _store.simulate();
    return _store.requests[id];
  }

  @override
  Future<List<ServiceRequest>> byCustomer(String customerId) async {
    await _store.simulate();
    final List<ServiceRequest> list = _store.requests.values
        .where((ServiceRequest r) => r.customerId == customerId)
        .toList();
    list.sort(
      (ServiceRequest a, ServiceRequest b) => b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<List<ServiceRequest>> all() async {
    await _store.simulate();
    final List<ServiceRequest> list = _store.requests.values.toList();
    list.sort(
      (ServiceRequest a, ServiceRequest b) => b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<List<Estimate>> estimatesFor(String requestId) async {
    await _store.simulate();
    final List<Estimate> list = _store.estimates.values
        .where((Estimate e) => e.requestId == requestId)
        .toList();
    list.sort((Estimate a, Estimate b) => a.amount.compareTo(b.amount));
    return list;
  }

  @override
  Future<Estimate> addEstimate(Estimate estimate) async {
    await _store.simulate();
    final String id = _store.newId('e');
    final Estimate saved = Estimate(
      id: id,
      requestId: estimate.requestId,
      mechanicId: estimate.mechanicId,
      mechanicName: estimate.mechanicName,
      amount: estimate.amount,
      etaMinutes: estimate.etaMinutes,
      note: estimate.note,
      createdAt: estimate.createdAt,
      expiresAt: estimate.expiresAt,
      status: estimate.status,
    );
    _store.estimates[id] = saved;
    return saved;
  }

  @override
  Future<void> updateEstimate(Estimate estimate) async {
    await _store.simulate();
    _store.estimates[estimate.id] = estimate;
  }

  @override
  Future<List<MechanicProfile>> mechanics() async {
    await _store.simulate();
    return _store.mechanics.values.toList();
  }

  @override
  Future<MechanicProfile?> mechanic(String userId) async {
    await _store.simulate();
    return _store.mechanics[userId];
  }

  @override
  Future<void> saveMechanic(MechanicProfile profile) async {
    await _store.simulate();
    _store.mechanics[profile.userId] = profile;
  }

  @override
  Future<List<AppNotification>> notificationsFor(String userId) async {
    await _store.simulate();
    final List<AppNotification> list = _store.notifications.values
        .where((AppNotification n) => n.userId == userId)
        .toList();
    list.sort(
      (AppNotification a, AppNotification b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<void> addNotification(AppNotification notification) async {
    final String id = _store.newId('n');
    _store.notifications[id] = AppNotification(
      id: id,
      userId: notification.userId,
      title: notification.title,
      body: notification.body,
      createdAt: notification.createdAt,
      requestId: notification.requestId,
    );
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    await _store.simulate();
    for (final String key in _store.notifications.keys.toList()) {
      final AppNotification n = _store.notifications[key]!;
      if (n.userId == userId && !n.read) {
        _store.notifications[key] = n.markRead();
      }
    }
  }

  @override
  Future<void> saveLiveLocation(
    String requestId,
    LatLng position,
    DateTime at,
  ) async {
    _store.liveLocations[requestId] =
        LiveLocation(position: position, updatedAt: at);
  }

  @override
  Future<LiveLocation?> liveLocation(String requestId) async {
    return _store.liveLocations[requestId];
  }
}
