import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/constants/app_constants.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/app_user.dart';
import 'package:fixonway/models/enums/problem_type.dart';
import 'package:fixonway/models/enums/user_role.dart';
import 'package:fixonway/models/enums/vehicle_type.dart';
import 'package:fixonway/models/estimate.dart';
import 'package:fixonway/models/lat_lng.dart';
import 'package:fixonway/models/live_location.dart';
import 'package:fixonway/models/service_request.dart';
import 'package:fixonway/models/vehicle.dart';
import 'package:fixonway/repositories/api/codecs.dart';
import 'package:fixonway/repositories/mock_data_store.dart';
import 'package:fixonway/repositories/mock_request_repository.dart';
import 'package:fixonway/services/job_service.dart';
import 'package:fixonway/services/request_service.dart';
import 'package:fixonway/core/widgets/map_canvas.dart';

void main() {
  late DateTime clock;
  late MockRequestRepository repo;
  late RequestService requests;
  late JobService jobs;

  const AppUser ali = AppUser(
    id: 'u1',
    role: UserRole.customer,
    name: 'Ali Raza',
    phone: '+923001234567',
    email: 'ali.raza@example.pk',
  );
  const Vehicle cultus = Vehicle(
    id: 'v0',
    ownerId: 'u1',
    type: VehicleType.car,
    make: 'Suzuki',
    model: 'Cultus',
    plate: 'ICT-1234',
  );
  const LatLng onRoad = LatLng(33.69, 73.05);

  setUp(() {
    clock = DateTime(2026, 1, 1, 12);
    final MockDataStore store =
        MockDataStore(now: () => clock, simulatedDelay: Duration.zero);
    repo = MockRequestRepository(store);
    requests = RequestService(repo, now: () => clock);
    jobs = JobService(repo, now: () => clock);
  });

  Future<ServiceRequest> acceptedJob() async {
    final ServiceRequest r = await requests.createRequest(
      customer: ali,
      vehicle: cultus,
      problem: ProblemType.flatTire,
      description: '',
      location: LatLng.islamabad,
      address: 'F-10 Markaz',
    );
    final Estimate e = await requests.submitEstimate(
      mechanicId: 'u2',
      requestId: r.id,
      amount: 1000,
      etaMinutes: 10,
    );
    return requests.acceptEstimate(r.id, e.id);
  }

  Future<void> expectError(Future<Object?> Function() action, String part) async {
    try {
      await action();
      fail('Expected an AppException containing "$part"');
    } on AppException catch (e) {
      expect(e.message, contains(part));
    }
  }

  group('live GPS of the mechanic', () {
    test('is refused before the trip has started', () async {
      final ServiceRequest r = await acceptedJob();
      await expectError(
        () => jobs.reportLocation('u2', r.id, onRoad),
        'on the way',
      );
    });

    test('is saved while on the way and read back by the customer', () async {
      final ServiceRequest r = await acceptedJob();
      await jobs.startTrip('u2', r.id);
      await jobs.reportLocation('u2', r.id, onRoad);
      final LiveLocation? live = await requests.liveLocation(r.id);
      expect(live, isNotNull);
      expect(live!.position, onRoad);
    });

    test('only the assigned mechanic can report', () async {
      final ServiceRequest r = await acceptedJob();
      await jobs.startTrip('u2', r.id);
      await expectError(
        () => jobs.reportLocation('m2', r.id, onRoad),
        'not your job',
      );
    });

    test('positions outside Pakistan are refused', () async {
      final ServiceRequest r = await acceptedJob();
      await jobs.startTrip('u2', r.id);
      await expectError(
        () => jobs.reportLocation('u2', r.id, const LatLng(51.5, -0.12)),
        'outside Pakistan',
      );
    });

    test('an old position is ignored', () async {
      final ServiceRequest r = await acceptedJob();
      await jobs.startTrip('u2', r.id);
      await jobs.reportLocation('u2', r.id, onRoad);
      clock = clock.add(AppConstants.liveLocationMaxAge + const Duration(seconds: 1));
      expect(await requests.liveLocation(r.id), isNull);
    });

    test('no position before anything was reported', () async {
      final ServiceRequest r = await acceptedJob();
      expect(await requests.liveLocation(r.id), isNull);
    });

    test('live location survives the Firestore codec', () {
      final LiveLocation l =
          LiveLocation(position: onRoad, updatedAt: DateTime(2026, 1, 1, 12, 5));
      final LiveLocation back =
          Codecs.liveLocationFromMap(Codecs.liveLocationToMap(l));
      expect(back.position, onRoad);
      expect(back.updatedAt, l.updatedAt);
    });
  });

  group('map zoom', () {
    test('smaller span means more zoom', () {
      expect(MapCanvas.zoomForSpan(0.06) > MapCanvas.zoomForSpan(0.12), isTrue);
      expect(MapCanvas.zoomForSpan(0.12), closeTo(13, 0.001));
    });

    test('zoom stays inside the limits', () {
      expect(MapCanvas.zoomForSpan(0), lessThanOrEqualTo(18));
      expect(MapCanvas.zoomForSpan(500), greaterThanOrEqualTo(3));
    });
  });
}
