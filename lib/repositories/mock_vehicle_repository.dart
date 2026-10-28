import '../models/vehicle.dart';
import 'mock_data_store.dart';
import 'vehicle_repository.dart';

class MockVehicleRepository implements VehicleRepository {
  MockVehicleRepository(this._store);

  final MockDataStore _store;

  @override
  Future<List<Vehicle>> byOwner(String ownerId) async {
    await _store.simulate();
    return _store.vehicles.values
        .where((Vehicle v) => v.ownerId == ownerId)
        .toList();
  }

  @override
  Future<Vehicle> save(Vehicle vehicle) async {
    await _store.simulate();
    final String id = vehicle.id.isEmpty ? _store.newId('v') : vehicle.id;
    final Vehicle saved = Vehicle(
      id: id,
      ownerId: vehicle.ownerId,
      type: vehicle.type,
      make: vehicle.make,
      model: vehicle.model,
      plate: vehicle.plate,
    );
    _store.vehicles[id] = saved;
    return saved;
  }

  @override
  Future<void> delete(String vehicleId) async {
    await _store.simulate();
    _store.vehicles.remove(vehicleId);
  }
}
