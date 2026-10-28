import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/app_user.dart';
import 'package:fixonway/models/complaint.dart';
import 'package:fixonway/models/enums/complaint_category.dart';
import 'package:fixonway/models/enums/complaint_status.dart';
import 'package:fixonway/models/enums/request_status.dart';
import 'package:fixonway/models/enums/user_role.dart';
import 'package:fixonway/models/enums/verification_status.dart';
import 'package:fixonway/models/service_request.dart';
import 'package:fixonway/repositories/mock_application_repository.dart';
import 'package:fixonway/repositories/mock_audit_repository.dart';
import 'package:fixonway/repositories/mock_auth_repository.dart';
import 'package:fixonway/repositories/mock_data_store.dart';
import 'package:fixonway/repositories/mock_request_repository.dart';
import 'package:fixonway/repositories/mock_review_repository.dart';
import 'package:fixonway/services/admin_service.dart';
import 'package:fixonway/services/mechanic_service.dart';

void main() {
  final DateTime clock = DateTime(2026, 1, 10, 12);
  late MockAuthRepository auth;
  late MockRequestRepository requests;
  late MockReviewRepository reviews;
  late MockAuditRepository audit;
  late AdminService service;
  late AppUser admin;

  Future<AppUser> user(String id) async =>
      (await auth.allUsers()).firstWhere((AppUser u) => u.id == id);

  setUp(() async {
    final MockDataStore store =
        MockDataStore(now: () => clock, simulatedDelay: Duration.zero);
    auth = MockAuthRepository(now: () => clock, simulatedDelay: Duration.zero);
    requests = MockRequestRepository(store);
    reviews = MockReviewRepository(store);
    audit = MockAuditRepository(store);
    final MockApplicationRepository applications =
        MockApplicationRepository(store);
    service = AdminService(
      auth,
      requests,
      reviews,
      applications,
      audit,
      MechanicService(requests, applications, auth, now: () => clock),
      now: () => clock,
    );
    admin = await user('u3');
  });

  group('permissions', () {
    test('a customer cannot use admin actions', () async {
      final AppUser customer = await user('u1');
      expect(
        () => service.blockUser(customer, 'u6', 'spam'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('mechanic approvals (UC-34)', () {
    test('seeded application is listed', () async {
      final list = await service.applications();
      expect(list.map((a) => a.userId), contains('u5'));
    });

    test('approve verifies the mechanic and writes an audit entry', () async {
      await service.approveMechanic(admin, 'u5');
      expect((await user('u5')).verificationStatus, VerificationStatus.verified);
      expect(await requests.mechanic('u5'), isNotNull);
      final logs = await service.recentActivity();
      expect(logs.first.action, 'Approved mechanic');
    });

    test('reject needs a reason and removes the application', () async {
      expect(
        () => service.rejectMechanic(admin, 'u5', '  '),
        throwsA(isA<AppException>()),
      );
      await service.rejectMechanic(admin, 'u5', 'CNIC photo is unclear');
      expect((await user('u5')).verificationStatus, VerificationStatus.rejected);
      final list = await service.applications();
      expect(list.where((a) => a.userId == 'u5'), isEmpty);
    });
  });

  group('users (UC-35, UC-36)', () {
    test('list never includes admins and can filter by role', () async {
      final all = await service.users();
      expect(all.any((AppUser u) => u.role == UserRole.admin), isFalse);
      final mechanics = await service.users(role: UserRole.mechanic);
      expect(mechanics.every((AppUser u) => u.role == UserRole.mechanic), isTrue);
    });

    test('search matches name, phone and email', () async {
      expect((await service.users(query: 'hira')).map((u) => u.id), <String>['u6']);
      expect((await service.users(query: 'ZAHID@')).map((u) => u.id), <String>['u5']);
      expect((await service.users(query: 'nobody-here')), isEmpty);
    });

    test('block needs a reason', () async {
      expect(
        () => service.blockUser(admin, 'u6', 'x'),
        throwsA(isA<AppException>()),
      );
    });

    test('cannot block yourself, an admin or a blocked user', () async {
      expect(
        () => service.blockUser(admin, admin.id, 'testing'),
        throwsA(isA<AppException>()),
      );
      expect(
        () => service.blockUser(admin, 'u4', 'already blocked'),
        throwsA(isA<AppException>()),
      );
    });

    test('blocked customer cannot log in; unblock restores access', () async {
      await service.blockUser(admin, 'u6', 'Fake requests');
      expect((await user('u6')).isBlocked, isTrue);
      expect(
        () => auth.login(identifier: 'hira@example.pk', password: 'Pass@1234'),
        throwsA(isA<AppException>()),
      );
      await service.unblockUser(admin, 'u6');
      final AppUser back =
          await auth.login(identifier: 'hira@example.pk', password: 'Pass@1234');
      expect(back.isBlocked, isFalse);
    });

    test('unblocking an active user is refused', () async {
      expect(
        () => service.unblockUser(admin, 'u6'),
        throwsA(isA<AppException>()),
      );
    });

    test('blocking a mechanic takes them offline', () async {
      await service.blockUser(admin, 'u2', 'Repeated no-shows');
      expect((await requests.mechanic('u2'))!.isOnline, isFalse);
    });
  });

  group('complaints (UC-38)', () {
    late Complaint complaint;

    setUp(() async {
      final ServiceRequest job = (await requests.byId('r_seed1'))!;
      await requests.update(
        job.copyWith(status: RequestStatus.disputed, updatedAt: clock),
      );
      complaint = await reviews.addComplaint(
        Complaint(
          id: '',
          requestId: job.id,
          customerId: job.customerId,
          customerName: job.customerName,
          mechanicId: job.mechanicId,
          mechanicName: job.mechanicName,
          category: ComplaintCategory.overcharged,
          description: 'Charged more than agreed.',
          createdAt: clock,
        ),
      );
    });

    test('note must be at least 5 characters', () async {
      expect(
        () => service.resolveComplaint(
          admin: admin,
          complaintId: complaint.id,
          upheld: true,
          resolution: 'ok',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('upheld closes the disputed request', () async {
      final Complaint done = await service.resolveComplaint(
        admin: admin,
        complaintId: complaint.id,
        upheld: true,
        resolution: 'Refund arranged with the mechanic.',
      );
      expect(done.status, ComplaintStatus.resolved);
      expect((await requests.byId('r_seed1'))!.status, RequestStatus.closed);
    });

    test('dismissed marks the request paid', () async {
      final Complaint done = await service.resolveComplaint(
        admin: admin,
        complaintId: complaint.id,
        upheld: false,
        resolution: 'The price matched the agreed estimate.',
      );
      expect(done.status, ComplaintStatus.rejected);
      final ServiceRequest r = (await requests.byId('r_seed1'))!;
      expect(r.status, RequestStatus.paid);
      expect(r.paidAt, isNotNull);
    });

    test('a handled complaint cannot be handled twice', () async {
      await service.resolveComplaint(
        admin: admin,
        complaintId: complaint.id,
        upheld: true,
        resolution: 'Refund arranged with the mechanic.',
      );
      expect(
        () => service.resolveComplaint(
          admin: admin,
          complaintId: complaint.id,
          upheld: false,
          resolution: 'Changing my mind later.',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('filter by status', () async {
      expect((await service.complaints(status: ComplaintStatus.open)).length, 1);
      expect((await service.complaints(status: ComplaintStatus.resolved)), isEmpty);
    });
  });

  group('report (UC-39)', () {
    test('counts users and finished jobs from the seed data', () async {
      final Report r = await service.report();
      expect(r.totalRequests, (await requests.all()).length);
      expect(r.finishedJobs, 2);
      expect(r.revenue, 2700);
      expect(r.topMechanics.first.mechanicId, 'u2');
      expect(r.last7Days.length, 7);
      expect(
        r.byStatus.values.fold<int>(0, (int a, int b) => a + b),
        r.totalRequests,
      );
    });

    test('day filter keeps only recent requests', () async {
      final Report week = await service.report(days: 7);
      final Report none = await service.report(days: 1);
      expect(week.totalRequests, 2);
      expect(none.totalRequests, 0);
    });
  });

  group('change password (UC-42)', () {
    test('wrong current password is refused', () async {
      expect(
        () => auth.changePassword(
          userId: admin.id,
          currentPassword: 'Wrong@123',
          newPassword: 'Another@123',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('new password works for the next login', () async {
      await auth.changePassword(
        userId: admin.id,
        currentPassword: 'Admin@1234',
        newPassword: 'Another@123',
      );
      final AppUser again = await auth.login(
        identifier: 'sara.khan@fixonway.pk',
        password: 'Another@123',
      );
      expect(again.id, admin.id);
    });
  });
}
