import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/enums/problem_type.dart';
import 'package:fixonway/models/enums/request_status.dart';
import 'package:fixonway/models/enums/vehicle_type.dart';
import 'package:fixonway/models/lat_lng.dart';
import 'package:fixonway/models/service_request.dart';
import 'package:fixonway/models/vehicle.dart';
import 'package:fixonway/repositories/mock_data_store.dart';
import 'package:fixonway/repositories/mock_request_repository.dart';
import 'package:fixonway/repositories/mock_vehicle_repository.dart';
import 'package:fixonway/services/vehicle_service.dart';

void main() {
  late MockDataStore store;
  late MockRequestRepository requests;
  late VehicleService service;

  setUp(() {
    store = MockDataStore(simulatedDelay: Duration.zero);
    requests = MockRequestRepository(store);
    service = VehicleService(MockVehicleRepository(store), requests);
  });

  Future<Vehicle> add(String plate, {String make = 'Honda'}) {
    return service.add(
      ownerId: 'u1',
      type: VehicleType.car,
      make: make,
      model: 'City',
      plate: plate,
    );
  }

  Future<void> expectError(Future<Object?> Function() action, String part) async {
    try {
      await action();
      fail('Expected an AppException containing "$part"');
    } on AppException catch (e) {
      expect(e.message, contains(part));
    }
  }

  test('seed vehicle is listed for its owner only', () async {
    expect((await service.list('u1')).length, 1);
    expect((await service.list('u2')).length, 0);
  });

  test('plate is trimmed and upper-cased', () async {
    final Vehicle v = await add(' lhr-555 ');
    expect(v.plate, 'LHR-555');
  });

  test('up to 5 vehicles; the 6th is rejected', () async {
    await add('A-1111');
    await add('A-2222');
    await add('A-3333');
    await add('A-4444'); // seed + 4 = 5
    await expectError(() => add('A-5555'), 'up to 5');
  });

  test('duplicate plate is rejected', () async {
    await expectError(() => add('ict-1234'), 'already saved');
  });

  test('make is required and a 2 character plate is invalid', () async {
    await expectError(() => add('LHR-555', make: ' '), 'Make');
    await expectError(() => add('AB'), 'number plate');
  });

  test('update changes the details', () async {
    final Vehicle v = (await service.list('u1')).first;
    final Vehicle updated = await service.update(
      v,
      type: VehicleType.van,
      make: 'Toyota',
      model: 'Hiace',
      plate: 'isb-9',
    );
    expect(updated.make, 'Toyota');
    expect(updated.type, VehicleType.van);
  });

  test('a vehicle in an active request cannot be removed', () async {
    final Vehicle v = (await service.list('u1')).first;
    final DateTime t = DateTime(2026, 1, 1);
    await requests.create(
      ServiceRequest(
        id: '',
        customerId: 'u1',
        customerName: 'Ali',
        vehicleId: v.id,
        vehicleTitle: v.title,
        vehicleType: v.type,
        problem: ProblemType.flatTire,
        description: '',
        location: LatLng.islamabad,
        address: 'x',
        photos: const [],
        status: RequestStatus.pending,
        createdAt: t,
        updatedAt: t,
      ),
    );
    await expectError(() => service.remove(v), 'active request');
  });

  test('an unused vehicle can be removed', () async {
    final Vehicle v = (await service.list('u1')).first;
    await service.remove(v);
    expect(await service.list('u1'), isEmpty);
  });
}
