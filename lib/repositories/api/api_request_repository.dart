import '../../models/app_notification.dart';
import '../../models/estimate.dart';
import '../../models/lat_lng.dart';
import '../../models/live_location.dart';
import '../../models/mechanic_profile.dart';
import '../../models/service_request.dart';
import '../request_repository.dart';
import 'api_client.dart';
import 'codecs.dart';

/// Requests, estimates, mechanic profiles, notifications and live GPS on the
/// backend (MongoDB). Lists are sorted here the same way the mock does.
class ApiRequestRepository implements RequestRepository {
  ApiRequestRepository(this._api);

  final ApiClient _api;

  ServiceRequest _request(Map<String, dynamic> m) =>
      Codecs.requestFromMap(m['id'] as String, m);

  List<ServiceRequest> _sortedRequests(Object? json) {
    final List<ServiceRequest> list =
        ApiClient.maps(json).map(_request).toList();
    list.sort(
      (ServiceRequest a, ServiceRequest b) => b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<ServiceRequest> create(ServiceRequest request) async {
    final Object? json =
        await _api.post('/api/requests', Codecs.requestToMap(request));
    return _request(ApiClient.map(json));
  }

  @override
  Future<void> update(ServiceRequest request) async {
    await _api.put('/api/requests/${request.id}', Codecs.requestToMap(request));
  }

  @override
  Future<ServiceRequest?> byId(String id) async {
    if (id.isEmpty) return null;
    final Object? json = await _api.getOrNull('/api/requests/$id');
    return json == null ? null : _request(ApiClient.map(json));
  }

  @override
  Future<List<ServiceRequest>> byCustomer(String customerId) async {
    return _sortedRequests(
      await _api.get(
        '/api/requests',
        query: <String, String>{'customerId': customerId},
      ),
    );
  }

  @override
  Future<List<ServiceRequest>> all() async =>
      _sortedRequests(await _api.get('/api/requests'));

  @override
  Future<List<Estimate>> estimatesFor(String requestId) async {
    final Object? json = await _api.get(
      '/api/estimates',
      query: <String, String>{'requestId': requestId},
    );
    final List<Estimate> list = <Estimate>[
      for (final Map<String, dynamic> m in ApiClient.maps(json))
        Codecs.estimateFromMap(m['id'] as String, m),
    ];
    list.sort((Estimate a, Estimate b) => a.amount.compareTo(b.amount));
    return list;
  }

  @override
  Future<Estimate> addEstimate(Estimate estimate) async {
    final Map<String, dynamic> m = ApiClient.map(
      await _api.post('/api/estimates', Codecs.estimateToMap(estimate)),
    );
    return Codecs.estimateFromMap(m['id'] as String, m);
  }

  @override
  Future<void> updateEstimate(Estimate estimate) async {
    await _api.put('/api/estimates/${estimate.id}', Codecs.estimateToMap(estimate));
  }

  @override
  Future<List<MechanicProfile>> mechanics() async {
    final Object? json = await _api.get('/api/mechanics');
    return <MechanicProfile>[
      for (final Map<String, dynamic> m in ApiClient.maps(json))
        Codecs.mechanicFromMap(m['id'] as String, m),
    ];
  }

  @override
  Future<MechanicProfile?> mechanic(String userId) async {
    if (userId.isEmpty) return null;
    final Object? json = await _api.getOrNull('/api/mechanics/$userId');
    if (json == null) return null;
    final Map<String, dynamic> m = ApiClient.map(json);
    return Codecs.mechanicFromMap(m['id'] as String, m);
  }

  @override
  Future<void> saveMechanic(MechanicProfile profile) async {
    await _api.put(
      '/api/mechanics/${profile.userId}',
      Codecs.mechanicToMap(profile),
    );
  }

  @override
  Future<List<AppNotification>> notificationsFor(String userId) async {
    final Object? json = await _api.get(
      '/api/notifications',
      query: <String, String>{'userId': userId},
    );
    final List<AppNotification> list = <AppNotification>[
      for (final Map<String, dynamic> m in ApiClient.maps(json))
        Codecs.notificationFromMap(m['id'] as String, m),
    ];
    list.sort(
      (AppNotification a, AppNotification b) => b.createdAt.compareTo(a.createdAt),
    );
    return list;
  }

  @override
  Future<void> addNotification(AppNotification notification) async {
    await _api.post(
      '/api/notifications',
      Codecs.notificationToMap(notification),
    );
  }

  @override
  Future<void> markAllNotificationsRead(String userId) async {
    await _api.post(
      '/api/notifications/read-all',
      <String, dynamic>{'userId': userId},
    );
  }

  @override
  Future<void> saveLiveLocation(
    String requestId,
    LatLng position,
    DateTime at,
  ) async {
    await _api.put(
      '/api/live/$requestId',
      Codecs.liveLocationToMap(LiveLocation(position: position, updatedAt: at)),
    );
  }

  @override
  Future<LiveLocation?> liveLocation(String requestId) async {
    if (requestId.isEmpty) return null;
    final Object? json = await _api.getOrNull('/api/live/$requestId');
    return json == null
        ? null
        : Codecs.liveLocationFromMap(ApiClient.map(json));
  }
}
