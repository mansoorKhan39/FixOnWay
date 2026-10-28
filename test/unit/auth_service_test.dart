import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/constants/app_constants.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/app_user.dart';
import 'package:fixonway/models/enums/user_role.dart';
import 'package:fixonway/models/enums/verification_status.dart';
import 'package:fixonway/models/registration_draft.dart';
import 'package:fixonway/repositories/mock_auth_repository.dart';
import 'package:fixonway/services/auth_service.dart';

void main() {
  late DateTime clock;
  late AuthService service;

  RegistrationDraft draft({
    UserRole role = UserRole.customer,
    String phone = '0311 2223344',
    String email = 'new.user@example.pk',
    String password = 'Secret@123',
  }) {
    return RegistrationDraft(
      role: role,
      name: 'New User',
      phone: phone,
      email: email,
      password: password,
    );
  }

  setUp(() {
    clock = DateTime(2026, 1, 1, 12);
    service = AuthService(
      MockAuthRepository(now: () => clock, simulatedDelay: Duration.zero),
    );
  });

  Future<void> expectMessage(Future<Object?> Function() action, String part) async {
    try {
      await action();
      fail('Expected an AppException containing "$part"');
    } on AppException catch (e) {
      expect(e.message, contains(part));
    }
  }

  group('UC-01 register', () {
    test('customer registers with a correct OTP', () async {
      final String phone = await service.startRegistration(draft());
      expect(phone, '+923112223344');
      final user =
          await service.completeRegistration(draft(), AppConstants.demoOtp);
      expect(user.role, UserRole.customer);
      expect(user.phone, '+923112223344');
    });

    test('mechanic starts as pending verification', () async {
      final RegistrationDraft d = draft(role: UserRole.mechanic);
      await service.startRegistration(d);
      final user = await service.completeRegistration(d, AppConstants.demoOtp);
      expect(user.verificationStatus, VerificationStatus.pending);
      expect(user.isPendingVerification, isTrue);
    });

    test('7 character password is rejected', () async {
      await expectMessage(
        () => service.startRegistration(draft(password: 'Abcde@1')),
        'at least 8',
      );
    });

    test('duplicate phone is rejected', () async {
      await expectMessage(
        () => service.startRegistration(draft(phone: '0300 1234567')),
        'phone number already exists',
      );
    });

    test('duplicate email is rejected', () async {
      await expectMessage(
        () => service.startRegistration(draft(email: 'ALI.RAZA@example.pk')),
        'email already exists',
      );
    });

    test('invalid phone is rejected', () async {
      await expectMessage(
        () => service.startRegistration(draft(phone: '12345')),
        'valid Pakistani',
      );
    });
  });

  group('UC-03 OTP', () {
    test('wrong code shows attempts left', () async {
      await service.startRegistration(draft());
      await expectMessage(
        () => service.completeRegistration(draft(), '000000'),
        '2 attempt',
      );
    });

    test('3 wrong codes invalidate the OTP', () async {
      await service.startRegistration(draft());
      for (int i = 0; i < 2; i++) {
        await expectMessage(
          () => service.completeRegistration(draft(), '000000'),
          'Incorrect',
        );
      }
      await expectMessage(
        () => service.completeRegistration(draft(), '000000'),
        'Too many wrong attempts',
      );
      await expectMessage(
        () => service.completeRegistration(draft(), AppConstants.demoOtp),
        'request a new code',
      );
    });

    test('expired OTP is rejected', () async {
      await service.startRegistration(draft());
      clock = clock.add(AppConstants.otpValidity + const Duration(seconds: 1));
      await expectMessage(
        () => service.completeRegistration(draft(), AppConstants.demoOtp),
        'expired',
      );
    });

    test('resend before 60 seconds is rejected', () async {
      final String phone = await service.startRegistration(draft());
      clock = clock.add(const Duration(seconds: 30));
      await expectMessage(() => service.resendOtp(phone), 'wait');
    });

    test('resend after 60 seconds works', () async {
      final String phone = await service.startRegistration(draft());
      clock = clock.add(const Duration(seconds: 61));
      await service.resendOtp(phone);
    });
  });

  group('UC-02 login', () {
    test('customer logs in with email', () async {
      final user = await service.login('ali.raza@example.pk', 'Pass@1234');
      expect(user.role, UserRole.customer);
    });

    test('customer logs in with phone', () async {
      final user = await service.login('0300 1234567', 'Pass@1234');
      expect(user.name, 'Ali Raza');
    });

    test('wrong password is rejected', () async {
      await expectMessage(
        () => service.login('ali.raza@example.pk', 'wrong'),
        'Invalid',
      );
    });

    test('empty fields are rejected', () async {
      await expectMessage(() => service.login('', ''), 'Enter your');
    });

    test('blocked account is suspended', () async {
      await expectMessage(
        () => service.login('blocked@example.pk', 'Pass@1234'),
        'suspended',
      );
    });

    test('5th failed attempt locks the login', () async {
      for (int i = 0; i < 4; i++) {
        await expectMessage(
          () => service.login('ali.raza@example.pk', 'bad$i'),
          'Invalid',
        );
      }
      await expectMessage(
        () => service.login('ali.raza@example.pk', 'bad5'),
        'locked',
      );
      await expectMessage(
        () => service.login('ali.raza@example.pk', 'Pass@1234'),
        'Try again',
      );
    });

    test('login works again after the lock time', () async {
      for (int i = 0; i < 5; i++) {
        try {
          await service.login('ali.raza@example.pk', 'bad$i');
        } on AppException {
          // expected
        }
      }
      clock = clock.add(AppConstants.loginLockDuration + const Duration(seconds: 1));
      final user = await service.login('ali.raza@example.pk', 'Pass@1234');
      expect(user.id, 'u1');
    });
  });

  group('UC-04 password reset', () {
    test('full reset flow, then login with the new password', () async {
      final String phone = await service.startPasswordReset('0300 1234567');
      await service.verifyOtp(phone, AppConstants.demoOtp);
      await service.completePasswordReset(phone, 'NewPass@123');
      final user = await service.login('ali.raza@example.pk', 'NewPass@123');
      expect(user.id, 'u1');
    });

    test('unknown number is rejected', () async {
      await expectMessage(
        () => service.startPasswordReset('0399 0000000'),
        'No account',
      );
    });

    test('same password as before is rejected', () async {
      final String phone = await service.startPasswordReset('0300 1234567');
      await service.verifyOtp(phone, AppConstants.demoOtp);
      await expectMessage(
        () => service.completePasswordReset(phone, 'Pass@1234'),
        'different',
      );
    });

    test('reset without OTP verification is rejected', () async {
      await expectMessage(
        () => service.completePasswordReset('+923001234567', 'NewPass@123'),
        'not verified',
      );
    });
  });

  test('UC-07 logout clears the current user', () async {
    await service.login('ali.raza@example.pk', 'Pass@1234');
    expect(service.currentUser, isNotNull);
    await service.logout();
    expect(service.currentUser, isNull);
  });

  group('session restore', () {
    test('nobody is logged in when the app starts', () async {
      expect(await service.restoreSession(), isNull);
    });

    test('a logged-in user is brought back', () async {
      final AppUser user = await service.login('ali.raza@example.pk', 'Pass@1234');
      final AppUser? back = await service.restoreSession();
      expect(back?.id, user.id);
    });

    test('after logout nobody is restored', () async {
      await service.login('ali.raza@example.pk', 'Pass@1234');
      await service.logout();
      expect(await service.restoreSession(), isNull);
    });
  });
}
