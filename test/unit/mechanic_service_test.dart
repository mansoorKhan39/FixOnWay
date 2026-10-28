import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/app_user.dart';
import 'package:fixonway/models/enums/problem_type.dart';
import 'package:fixonway/models/enums/user_role.dart';
import 'package:fixonway/models/enums/vehicle_type.dart';
import 'package:fixonway/models/enums/verification_status.dart';
import 'package:fixonway/models/mechanic_application.dart';
import 'package:fixonway/models/mechanic_profile.dart';
import 'package:fixonway/repositories/mock_application_repository.dart';
import 'package:fixonway/repositories/mock_auth_repository.dart';
import 'package:fixonway/repositories/mock_data_store.dart';
import 'package:fixonway/repositories/mock_request_repository.dart';
import 'package:fixonway/services/mechanic_service.dart';

void main() {
  late DateTime clock;
  late MockAuthRepository auth;
  late MockRequestRepository requests;
  late MechanicService service;
  late AppUser newMechanic;

  setUp(() async {
    clock = DateTime(2026, 1, 1, 12);
    final MockDataStore store =
        MockDataStore(now: () => clock, simulatedDelay: Duration.zero);
    auth = MockAuthRepository(now: () => clock, simulatedDelay: Duration.zero);
    requests = MockRequestRepository(store);
    service = MechanicService(
      requests,
      MockApplicationRepository(store),
      auth,
      now: () => clock,
    );
    await auth.sendOtp('+923111234567');
    await auth.verifyOtp('+923111234567', '123456');
    newMechanic = await auth.register(
      role: UserRole.mechanic,
      name: 'Nadeem Shah',
      phone: '+923111234567',
      email: 'nadeem@example.pk',
      password: 'Secret@123',
    );
  });

  Future<MechanicApplication> apply({
    String cnic = '12345-1234567-1',
    int experience = 4,
    String address = 'Shop 5, I-9 Markaz',
    Set<ProblemType>? services,
    Set<VehicleType>? vehicles,
    List<String>? documents,
  }) {
    return service.submitApplication(
      userId: newMechanic.id,
      name: newMechanic.name,
      phone: newMechanic.phone,
      cnic: cnic,
      experienceYears: experience,
      workshopAddress: address,
      services: services ?? <ProblemType>{ProblemType.flatTire},
      vehicleTypes: vehicles ?? <VehicleType>{VehicleType.car},
      documents: documents ?? <String>['CNIC front', 'CNIC back'],
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

  group('UC-23 verification details', () {
    test('valid details are saved without dashes in the CNIC', () async {
      final MechanicApplication a = await apply();
      expect(a.cnic, '1234512345671');
      expect((await service.application(newMechanic.id))?.userId, newMechanic.id);
    });

    test('CNIC must have 13 digits', () async {
      await expectError(() => apply(cnic: '12345-1234567'), '13 digits');
      await expectError(() => apply(cnic: '12345-1234567-12'), '13 digits');
    });

    test('experience boundaries 0 and 60 are accepted, 61 is not', () async {
      await apply(experience: 0);
      await apply(experience: 60);
      await expectError(() => apply(experience: 61), '0 and 60');
    });

    test('workshop address is required', () async {
      await expectError(() => apply(address: ' '), 'Workshop address');
    });

    test('at least one service and one vehicle type', () async {
      await expectError(
        () => apply(services: <ProblemType>{}),
        'at least one service',
      );
      await expectError(
        () => apply(vehicles: <VehicleType>{}),
        'vehicle type',
      );
    });

    test('2 to 5 documents', () async {
      await expectError(
        () => apply(documents: <String>['CNIC front']),
        'at least 2',
      );
      await expectError(
        () => apply(
          documents: <String>['a', 'b', 'c', 'd', 'e', 'f'],
        ),
        'up to 5',
      );
      await apply(documents: <String>['a', 'b', 'c', 'd', 'e']);
    });
  });

  group('UC-34 approval', () {
    test('approving creates a profile and verifies the user', () async {
      await apply();
      await service.approve(newMechanic.id);
      final MechanicProfile? p = await service.profile(newMechanic.id);
      expect(p, isNotNull);
      expect(p!.isOnline, isFalse);
      expect(auth.currentUser?.verificationStatus, VerificationStatus.verified);
      expect(await service.application(newMechanic.id), isNull);
    });

    test('approving without details is rejected', () async {
      await expectError(
        () => service.approve(newMechanic.id),
        'not submitted',
      );
    });

    test('rejecting needs a reason and lets the mechanic apply again', () async {
      await apply();
      await expectError(() => service.reject(newMechanic.id, ' '), 'reason');
      await service.reject(newMechanic.id, 'CNIC photo is blurry');
      expect(auth.currentUser?.verificationStatus, VerificationStatus.rejected);
      expect(await service.application(newMechanic.id), isNull);
      await apply();
    });
  });

  group('UC-25 online / UC-24 service area', () {
    test('an unverified mechanic cannot go online', () async {
      await expectError(
        () => service.setOnline(newMechanic.id, true),
        'not verified',
      );
    });

    test('a verified mechanic can go online and offline', () async {
      final MechanicProfile on = await service.setOnline('u2', true);
      expect(on.isOnline, isTrue);
      final MechanicProfile off = await service.setOnline('u2', false);
      expect(off.isOnline, isFalse);
    });

    test('radius boundaries 1 and 20 are accepted, 0 and 21 are not', () async {
      Future<MechanicProfile> save(int radius) => service.updateServiceArea(
            userId: 'u2',
            radiusKm: radius,
            startMinutes: 540,
            endMinutes: 1260,
            services: <ProblemType>{ProblemType.flatTire},
            vehicleTypes: <VehicleType>{VehicleType.car},
          );
      expect((await save(1)).serviceRadiusKm, 1);
      expect((await save(20)).serviceRadiusKm, 20);
      await expectError(() => save(0), 'between 1 and 20');
      await expectError(() => save(21), 'between 1 and 20');
    });

    test('closing time must be after opening time', () async {
      await expectError(
        () => service.updateServiceArea(
          userId: 'u2',
          radiusKm: 5,
          startMinutes: 600,
          endMinutes: 600,
          services: <ProblemType>{ProblemType.flatTire},
          vehicleTypes: <VehicleType>{VehicleType.car},
        ),
        'after opening',
      );
    });

    test('working hours are saved as text', () async {
      final MechanicProfile p = await service.updateServiceArea(
        userId: 'u2',
        radiusKm: 5,
        startMinutes: 8 * 60 + 30,
        endMinutes: 18 * 60,
        services: <ProblemType>{ProblemType.towing},
        vehicleTypes: <VehicleType>{VehicleType.van},
      );
      expect(p.workingHours, '8:30 AM - 6:00 PM');
      expect(p.services, <ProblemType>{ProblemType.towing});
    });

    test('empty services or vehicles are rejected', () async {
      await expectError(
        () => service.updateServiceArea(
          userId: 'u2',
          radiusKm: 5,
          startMinutes: 540,
          endMinutes: 1260,
          services: <ProblemType>{},
          vehicleTypes: <VehicleType>{VehicleType.car},
        ),
        'service',
      );
    });
  });

  group('time helpers', () {
    test('formatMinutes', () {
      expect(MechanicService.formatMinutes(0), '12:00 AM');
      expect(MechanicService.formatMinutes(540), '9:00 AM');
      expect(MechanicService.formatMinutes(720), '12:00 PM');
      expect(MechanicService.formatMinutes(1260), '9:00 PM');
    });

    test('parseHours', () {
      final ({int start, int end}) h =
          MechanicService.parseHours('8:30 AM - 6:00 PM');
      expect(h.start, 510);
      expect(h.end, 1080);
      final ({int start, int end}) bad = MechanicService.parseHours('nonsense');
      expect(bad.start, 540);
      expect(bad.end, 1260);
    });
  });

  test('UC-32 earnings add up paid jobs only', () async {
    final Earnings e = await service.earnings('u2');
    expect(e.total, 2700);
    expect(e.jobs.length, 2);
    expect(e.today, 0);
    expect(e.last7Days, 2700);
    final Earnings none = await service.earnings('m2');
    expect(none.total, 0);
  });
}
