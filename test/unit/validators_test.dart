import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/utils/validators.dart';

void main() {
  group('password (BVA around 8 characters)', () {
    test('7 characters is rejected', () {
      expect(Validators.password('Abcde@1'), isNotNull);
    });
    test('8 characters is accepted', () {
      expect(Validators.password('Abcdef@1'), isNull);
    });
    test('9 characters is accepted', () {
      expect(Validators.password('Abcdefg@1'), isNull);
    });
    test('empty is rejected', () {
      expect(Validators.password(''), isNotNull);
    });
  });

  group('phone (equivalence partitions)', () {
    test('local format is normalized', () {
      expect(Validators.normalizePhone('0300 1234567'), '+923001234567');
    });
    test('international format is normalized', () {
      expect(Validators.normalizePhone('+92 300 1234567'), '+923001234567');
    });
    test('92 prefix is normalized', () {
      expect(Validators.normalizePhone('923001234567'), '+923001234567');
    });
    test('too short is rejected', () {
      expect(Validators.phone('030012345'), isNotNull);
    });
    test('letters are rejected', () {
      expect(Validators.phone('0300abcdefg'), isNotNull);
    });
    test('landline style is rejected', () {
      expect(Validators.phone('0511234567'), isNotNull);
    });
    test('empty is rejected', () {
      expect(Validators.phone(''), isNotNull);
    });
  });

  group('email', () {
    test('valid address passes', () {
      expect(Validators.email('ali.raza@example.pk'), isNull);
    });
    test('missing @ fails', () {
      expect(Validators.email('ali.example.pk'), isNotNull);
    });
    test('missing domain fails', () {
      expect(Validators.email('ali@'), isNotNull);
    });
  });

  group('name, confirm password, otp', () {
    test('one letter name fails', () {
      expect(Validators.name('A'), isNotNull);
    });
    test('normal name passes', () {
      expect(Validators.name('Ali Raza'), isNull);
    });
    test('mismatching confirm password fails', () {
      expect(Validators.confirmPassword('abc', 'abd'), isNotNull);
    });
    test('matching confirm password passes', () {
      expect(Validators.confirmPassword('abcdefgh', 'abcdefgh'), isNull);
    });
    test('5 digit otp fails', () {
      expect(Validators.otp('12345'), isNotNull);
    });
    test('6 digit otp passes', () {
      expect(Validators.otp('123456'), isNull);
    });
    test('non numeric otp fails', () {
      expect(Validators.otp('12a456'), isNotNull);
    });
  });
}
