import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/enums/vehicle_type.dart';
import '../models/service_request.dart';
import '../models/vehicle.dart';
import '../repositories/request_repository.dart';
import '../repositories/vehicle_repository.dart';

/// UC-21: manage saved vehicles.
class VehicleService {
  VehicleService(this._vehicles, this._requests);

  final VehicleRepository _vehicles;
  final RequestRepository _requests;

  Future<List<Vehicle>> list(String ownerId) => _vehicles.byOwner(ownerId);

  void _check(String make, String model, String plate) {
    final String? error = Validators.required(make, 'Make') ??
        Validators.required(model, 'Model') ??
        Validators.plate(plate);
    if (error != null) throw AppException(error);
  }

  Future<Vehicle> add({
    required String ownerId,
    required VehicleType type,
    required String make,
    required String model,
    required String plate,
  }) async {
    _check(make, model, plate);
    final List<Vehicle> existing = await _vehicles.byOwner(ownerId);
    if (existing.length >= AppConstants.maxVehicles) {
      throw const AppException(
        'You can save up to ${AppConstants.maxVehicles} vehicles.',
      );
    }
    final String normalized = plate.trim().toUpperCase();
    if (existing.any((Vehicle v) => v.plate == normalized)) {
      throw const AppException('This number plate is already saved.');
    }
    return _vehicles.save(
      Vehicle(
        id: '',
        ownerId: ownerId,
        type: type,
        make: make.trim(),
        model: model.trim(),
        plate: normalized,
      ),
    );
  }

  Future<Vehicle> update(
    Vehicle vehicle, {
    required VehicleType type,
    required String make,
    required String model,
    required String plate,
  }) async {
    _check(make, model, plate);
    final String normalized = plate.trim().toUpperCase();
    final List<Vehicle> existing = await _vehicles.byOwner(vehicle.ownerId);
    if (existing.any((Vehicle v) => v.id != vehicle.id && v.plate == normalized)) {
      throw const AppException('This number plate is already saved.');
    }
    return _vehicles.save(
      vehicle.copyWith(
        type: type,
        make: make.trim(),
        model: model.trim(),
        plate: normalized,
      ),
    );
  }

  /// A vehicle used by an active request cannot be removed.
  Future<void> remove(Vehicle vehicle) async {
    final List<ServiceRequest> requests =
        await _requests.byCustomer(vehicle.ownerId);
    final bool inUse = requests.any(
      (ServiceRequest r) => r.vehicleId == vehicle.id && r.isActive,
    );
    if (inUse) {
      throw const AppException(
        'This vehicle is used by an active request and cannot be removed.',
      );
    }
    await _vehicles.delete(vehicle.id);
  }
}
