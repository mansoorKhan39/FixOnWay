import '../models/vehicle.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> byOwner(String ownerId);

  /// Creates the vehicle when [vehicle.id] is empty, otherwise updates it.
  Future<Vehicle> save(Vehicle vehicle);

  Future<void> delete(String vehicleId);
}
