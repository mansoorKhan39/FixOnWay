import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/constants/app_constants.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/app_notification.dart';
import 'package:fixonway/models/app_user.dart';
import 'package:fixonway/models/enums/estimate_status.dart';
import 'package:fixonway/models/enums/problem_type.dart';
import 'package:fixonway/models/enums/request_status.dart';
import 'package:fixonway/models/enums/user_role.dart';
import 'package:fixonway/models/enums/vehicle_type.dart';
import 'package:fixonway/models/estimate.dart';
import 'package:fixonway/models/lat_lng.dart';
import 'package:fixonway/models/photo_attachment.dart';
import 'package:fixonway/models/service_request.dart';
import 'package:fixonway/models/vehicle.dart';
import 'package:fixonway/repositories/mock_data_store.dart';
import 'package:fixonway/repositories/mock_request_repository.dart';
import 'package:fixonway/repositories/request_repository.dart';
import 'package:fixonway/services/request_service.dart';

void main() {
  late DateTime clock;
  late MockDataStore store;
  late RequestRepository repo;
  late RequestService service;

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

  setUp(() {
    clock = DateTime(2026, 1, 1, 12);
    store = MockDataStore(now: () => clock, simulatedDelay: Duration.zero);
    repo = MockRequestRepository(store);
    service = RequestService(repo, now: () => clock);
  });

  Future<ServiceRequest> create({
    ProblemType problem = ProblemType.flatTire,
    String description = '',
    String address = 'Near Faisal Avenue',
    LatLng location = LatLng.islamabad,
    List<PhotoAttachment> photos = const <PhotoAttachment>[],
    Vehicle vehicle = cultus,
  }) {
    return service.createRequest(
      customer: ali,
      vehicle: vehicle,
      problem: problem,
      description: description,
      location: location,
      address: address,
      photos: photos,
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

  group('UC-08 create request', () {
    test('valid request starts as pending', () async {
      final ServiceRequest r = await create();
      expect(r.status, RequestStatus.pending);
      expect(r.vehicleTitle, contains('ICT-1234'));
    });

    test('nearby mechanics are notified', () async {
      final ServiceRequest r = await create();
      final List<AppNotification> list = await repo.notificationsFor('u2');
      expect(list.any((AppNotification n) => n.requestId == r.id), isTrue);
    });

    test('"Other" needs a description', () async {
      await expectError(
        () => create(problem: ProblemType.other),
        'describe',
      );
    });

    test('description over 300 characters is rejected', () async {
      await expectError(
        () => create(description: 'x' * 301),
        '300',
      );
    });

    test('description of exactly 300 characters is accepted', () async {
      final ServiceRequest r = await create(description: 'x' * 300);
      expect(r.description.length, 300);
    });

    test('empty address is rejected', () async {
      await expectError(() => create(address: '  '), 'location or address');
    });

    test('location outside Pakistan is rejected', () async {
      await expectError(
        () => create(location: const LatLng(51.5, -0.12)),
        'inside Pakistan',
      );
    });

    test('3 photos are accepted, 4 are rejected', () async {
      const PhotoAttachment p = PhotoAttachment(name: 'a.jpg', sizeBytes: 1000);
      final ServiceRequest r =
          await create(photos: const <PhotoAttachment>[p, p, p]);
      expect(r.photos.length, 3);
      await service.cancel(r.id);
      await expectError(
        () => create(photos: const <PhotoAttachment>[p, p, p, p]),
        'up to 3',
      );
    });

    test('photo of exactly 5 MB is accepted, 5 MB + 1 byte is rejected', () async {
      final ServiceRequest r = await create(
        photos: const <PhotoAttachment>[
          PhotoAttachment(name: 'a.jpg', sizeBytes: AppConstants.maxPhotoBytes),
        ],
      );
      await service.cancel(r.id);
      await expectError(
        () => create(
          photos: const <PhotoAttachment>[
            PhotoAttachment(
              name: 'b.jpg',
              sizeBytes: AppConstants.maxPhotoBytes + 1,
            ),
          ],
        ),
        '5 MB',
      );
    });

    test('a second active request is rejected', () async {
      await create();
      await expectError(() => create(), 'active request');
    });

    test('a new request is allowed after cancelling', () async {
      final ServiceRequest r = await create();
      await service.cancel(r.id);
      final ServiceRequest again = await create();
      expect(again.status, RequestStatus.pending);
    });

    test("someone else's vehicle is rejected", () async {
      await expectError(
        () => create(
          vehicle: const Vehicle(
            id: 'vx',
            ownerId: 'u9',
            type: VehicleType.car,
            make: 'Honda',
            model: 'City',
            plate: 'LHR-1',
          ),
        ),
        'own vehicles',
      );
    });
  });

  group('UC-12 nearby mechanics', () {
    test('only online mechanics, nearest first', () async {
      final List<NearbyMechanic> list =
          await service.nearbyMechanics(LatLng.islamabad);
      expect(list.any((NearbyMechanic m) => m.profile.userId == 'm5'), isFalse);
      expect(list.first.profile.userId, 'u2');
      for (int i = 1; i < list.length; i++) {
        expect(list[i].distanceKm >= list[i - 1].distanceKm, isTrue);
      }
    });

    test('small radius returns fewer mechanics', () async {
      final List<NearbyMechanic> near =
          await service.nearbyMechanics(LatLng.islamabad, radiusKm: 3);
      final List<NearbyMechanic> far =
          await service.nearbyMechanics(LatLng.islamabad, radiusKm: 20);
      expect(near.length < far.length, isTrue);
    });

    test('radius 0 and 21 are rejected, 1 and 20 are accepted', () async {
      await expectError(
        () => service.nearbyMechanics(LatLng.islamabad, radiusKm: 0),
        'Radius',
      );
      await expectError(
        () => service.nearbyMechanics(LatLng.islamabad, radiusKm: 21),
        'Radius',
      );
      await service.nearbyMechanics(LatLng.islamabad, radiusKm: 1);
      await service.nearbyMechanics(LatLng.islamabad, radiusKm: 20);
    });

    test('filters by problem type', () async {
      final List<NearbyMechanic> list = await service.nearbyMechanics(
        LatLng.islamabad,
        problem: ProblemType.towing,
      );
      expect(
        list.every((NearbyMechanic m) => m.profile.services.contains(ProblemType.towing)),
        isTrue,
      );
    });
  });

  group('UC-13 / UC-28 estimates', () {
    test('first estimate moves the request to estimated', () async {
      final ServiceRequest r = await create();
      await service.submitEstimate(
        mechanicId: 'u2',
        requestId: r.id,
        amount: 1500,
        etaMinutes: 15,
      );
      final ServiceRequest after = await service.requestById(r.id);
      expect(after.status, RequestStatus.estimated);
      final List<AppNotification> mine = await repo.notificationsFor('u1');
      expect(mine.any((AppNotification n) => n.title.contains('estimate')), isTrue);
    });

    test('price boundaries: 99 rejected, 100 accepted, 100001 rejected', () async {
      final ServiceRequest r = await create();
      await expectError(
        () => service.submitEstimate(
          mechanicId: 'u2', requestId: r.id, amount: 99, etaMinutes: 10),
        'between',
      );
      await expectError(
        () => service.submitEstimate(
          mechanicId: 'u2', requestId: r.id, amount: 100001, etaMinutes: 10),
        'between',
      );
      await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 100, etaMinutes: 10);
    });

    test('arrival time boundaries: 0 and 121 rejected, 1 and 120 ok', () async {
      final ServiceRequest r = await create();
      await expectError(
        () => service.submitEstimate(
          mechanicId: 'u2', requestId: r.id, amount: 500, etaMinutes: 0),
        'Arrival',
      );
      await expectError(
        () => service.submitEstimate(
          mechanicId: 'u2', requestId: r.id, amount: 500, etaMinutes: 121),
        'Arrival',
      );
      await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 500, etaMinutes: 1);
      await service.submitEstimate(
        mechanicId: 'm2', requestId: r.id, amount: 500, etaMinutes: 120);
    });

    test('the same mechanic cannot send two offers', () async {
      final ServiceRequest r = await create();
      await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 500, etaMinutes: 10);
      await expectError(
        () => service.submitEstimate(
          mechanicId: 'u2', requestId: r.id, amount: 600, etaMinutes: 10),
        'already sent',
      );
    });

    test('an offline mechanic cannot send an estimate', () async {
      final ServiceRequest r = await create();
      await expectError(
        () => service.submitEstimate(
          mechanicId: 'm5', requestId: r.id, amount: 500, etaMinutes: 10),
        'online',
      );
    });

    test('estimate expires after 10 minutes and the request goes back to pending', () async {
      final ServiceRequest r = await create();
      await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 500, etaMinutes: 10);
      clock = clock.add(AppConstants.estimateValidity + const Duration(seconds: 1));
      await service.refresh('u1');
      final List<Estimate> list = await service.estimates(r.id);
      expect(list.single.status, EstimateStatus.expired);
      final ServiceRequest after = await service.requestById(r.id);
      expect(after.status, RequestStatus.pending);
    });

    test('simulateEstimate picks a suitable nearby mechanic', () async {
      final ServiceRequest r = await create();
      final Estimate e = await service.simulateEstimate(r.id);
      expect(e.mechanicId, 'u2');
    });
  });

  group('UC-14 accept / decline', () {
    test('accepting one estimate declines the others', () async {
      final ServiceRequest r = await create();
      final Estimate a = await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 900, etaMinutes: 10);
      final Estimate b = await service.submitEstimate(
        mechanicId: 'm4', requestId: r.id, amount: 700, etaMinutes: 25);
      final ServiceRequest accepted =
          await service.acceptEstimate(r.id, a.id);
      expect(accepted.status, RequestStatus.accepted);
      expect(accepted.mechanicId, 'u2');
      expect(accepted.agreedAmount, 900);
      final List<Estimate> all = await service.estimates(r.id);
      expect(
        all.firstWhere((Estimate e) => e.id == b.id).status,
        EstimateStatus.declined,
      );
      expect(
        all.firstWhere((Estimate e) => e.id == a.id).status,
        EstimateStatus.accepted,
      );
    });

    test('an expired estimate cannot be accepted', () async {
      final ServiceRequest r = await create();
      final Estimate a = await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 900, etaMinutes: 10);
      clock = clock.add(AppConstants.estimateValidity);
      await expectError(() => service.acceptEstimate(r.id, a.id), 'expired');
    });

    test('declining the only estimate returns the request to pending', () async {
      final ServiceRequest r = await create();
      final Estimate a = await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 900, etaMinutes: 10);
      await service.declineEstimate(a.id);
      final ServiceRequest after = await service.requestById(r.id);
      expect(after.status, RequestStatus.pending);
    });

    test('accepting without any estimate is not possible', () async {
      final ServiceRequest r = await create();
      await expectError(
        () => service.acceptEstimate(r.id, 'nope'),
        'cannot accept',
      );
    });
  });

  group('UC-17 cancel', () {
    test('a pending request can be cancelled with a reason', () async {
      final ServiceRequest r = await create();
      final ServiceRequest c = await service.cancel(r.id, reason: 'Fixed it myself');
      expect(c.status, RequestStatus.cancelled);
      expect(c.cancelReason, 'Fixed it myself');
    });

    test('cancelling twice is rejected', () async {
      final ServiceRequest r = await create();
      await service.cancel(r.id);
      await expectError(() => service.cancel(r.id), 'no longer');
    });

    test('an accepted request can be cancelled and the mechanic is told', () async {
      final ServiceRequest r = await create();
      final Estimate a = await service.submitEstimate(
        mechanicId: 'u2', requestId: r.id, amount: 900, etaMinutes: 10);
      await service.acceptEstimate(r.id, a.id);
      await service.cancel(r.id);
      final List<AppNotification> list = await repo.notificationsFor('u2');
      expect(list.any((AppNotification n) => n.title == 'Request cancelled'), isTrue);
    });

    test('work in progress cannot be cancelled', () async {
      final ServiceRequest r = await create();
      await repo.update(r.copyWith(status: RequestStatus.working));
      await expectError(() => service.cancel(r.id), 'no longer');
    });
  });

  group('request expiry', () {
    test('a pending request with no estimate expires after 15 minutes', () async {
      final ServiceRequest r = await create();
      clock = clock.add(AppConstants.requestExpiry);
      await service.refresh('u1');
      final ServiceRequest after = await service.requestById(r.id);
      expect(after.status, RequestStatus.expired);
    });

    test('just before 15 minutes it is still pending', () async {
      final ServiceRequest r = await create();
      clock = clock.add(
        AppConstants.requestExpiry - const Duration(seconds: 1),
      );
      await service.refresh('u1');
      final ServiceRequest after = await service.requestById(r.id);
      expect(after.status, RequestStatus.pending);
    });
  });
}
