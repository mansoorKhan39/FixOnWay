import '../../models/vehicle.dart';
import '../vehicle_repository.dart';
import 'api_client.dart';

class ApiVehicleRepository implements VehicleRepository {
  ApiVehicleRepository(this._api);

  final ApiClient _api;

  Vehicle _vehicle(Map<String, dynamic> m) =>
      Vehicle.fromMap(m['id'] as String, m);

  @override
  Future<List<Vehicle>> byOwner(String ownerId) async {
    final Object? json = await _api.get(
      '/api/vehicles',
      query: <String, String>{'ownerId': ownerId},
    );
    final List<Vehicle> list = ApiClient.maps(json).map(_vehicle).toList();
    list.sort((Vehicle a, Vehicle b) => a.title.compareTo(b.title));
    return list;
  }

  @override
  Future<Vehicle> save(Vehicle vehicle) async {
    final Object? json = vehicle.id.isEmpty
        ? await _api.post('/api/vehicles', vehicle.toMap())
        : await _api.put('/api/vehicles/${vehicle.id}', vehicle.toMap());
    return _vehicle(ApiClient.map(json));
  }

  @override
  Future<void> delete(String vehicleId) async {
    await _api.delete('/api/vehicles/$vehicleId');
  }
}
