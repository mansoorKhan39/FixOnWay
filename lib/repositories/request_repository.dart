import '../models/app_notification.dart';
import '../models/lat_lng.dart';
import '../models/live_location.dart';
import '../models/estimate.dart';
import '../models/mechanic_profile.dart';
import '../models/service_request.dart';

abstract class RequestRepository {
  /// Stores a new request and returns it with its generated id.
  Future<ServiceRequest> create(ServiceRequest request);

  Future<void> update(ServiceRequest request);

  Future<ServiceRequest?> byId(String id);

  Future<List<ServiceRequest>> byCustomer(String customerId);

  Future<List<ServiceRequest>> all();

  Future<List<Estimate>> estimatesFor(String requestId);

  Future<Estimate> addEstimate(Estimate estimate);

  Future<void> updateEstimate(Estimate estimate);

  Future<List<MechanicProfile>> mechanics();

  Future<MechanicProfile?> mechanic(String userId);

  Future<void> saveMechanic(MechanicProfile profile);

  Future<List<AppNotification>> notificationsFor(String userId);

  Future<void> addNotification(AppNotification notification);

  Future<void> markAllNotificationsRead(String userId);

  /// The mechanic's GPS position for a job (kept apart from the request so a
  /// position update can never overwrite a status change).
  Future<void> saveLiveLocation(
    String requestId,
    LatLng position,
    DateTime at,
  );

  Future<LiveLocation?> liveLocation(String requestId);
}
