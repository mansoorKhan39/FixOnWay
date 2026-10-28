import '../constants/app_constants.dart';

/// Form validators. Each returns an error message, or null when the value is valid.
class Validators {
  Validators._();

  static final RegExp _emailPattern =
      RegExp(r'^[\w.+\-]+@([\w\-]+\.)+[\w\-]{2,}$');
  static final RegExp _phonePattern = RegExp(r'^(?:\+92|92|0)(3\d{9})$');

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? name(String? value) {
    final String? missing = required(value, 'Name');
    if (missing != null) return missing;
    if (value!.trim().length < 2) return 'Enter your full name';
    return null;
  }

  /// Turns 0300 1234567, +92 300 1234567 or 923001234567 into +923001234567.
  /// Returns null when the value is not a Pakistani mobile number.
  static String? normalizePhone(String input) {
    final String cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');
    final RegExpMatch? match = _phonePattern.firstMatch(cleaned);
    if (match == null) return null;
    return '+92${match.group(1)}';
  }

  static String? phone(String? value) {
    final String? missing = required(value, 'Phone number');
    if (missing != null) return missing;
    if (normalizePhone(value!) == null) {
      return 'Enter a valid mobile number, e.g. 0300 1234567';
    }
    return null;
  }

  static String? email(String? value) {
    final String? missing = required(value, 'Email');
    if (missing != null) return missing;
    if (!_emailPattern.hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// UC-01: at least [AppConstants.minPasswordLength] characters.
  static String? password(String? value) {
    final String? missing = required(value, 'Password');
    if (missing != null) return missing;
    if (value!.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final String? missing = required(value, 'Confirm password');
    if (missing != null) return missing;
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? otp(String? value) {
    final String code = (value ?? '').trim();
    if (!RegExp('^\\d{${AppConstants.otpLength}}\$').hasMatch(code)) {
      return 'Enter the ${AppConstants.otpLength}-digit code';
    }
    return null;
  }

  static String? plate(String? value) {
    final String? missing = required(value, 'Number plate');
    if (missing != null) return missing;
    final int length = value!.trim().length;
    if (length < 3 || length > 12) {
      return 'Enter a valid number plate, e.g. ICT-1234';
    }
    return null;
  }

  static String? description(String? value, {bool isRequired = false}) {
    final String text = (value ?? '').trim();
    if (isRequired && text.isEmpty) return 'Please describe the problem';
    if (text.length > AppConstants.maxDescriptionLength) {
      return 'Keep it under ${AppConstants.maxDescriptionLength} characters';
    }
    return null;
  }

  static String? amount(String? value) {
    final String? missing = required(value, 'Price');
    if (missing != null) return missing;
    final int? parsed = int.tryParse(value!.trim());
    if (parsed == null) return 'Enter a whole number';
    if (parsed < AppConstants.minEstimateAmount ||
        parsed > AppConstants.maxEstimateAmount) {
      return 'Price must be between ${AppConstants.minEstimateAmount} and '
          '${AppConstants.maxEstimateAmount}';
    }
    return null;
  }

  static String? eta(String? value) {
    final String? missing = required(value, 'Arrival time');
    if (missing != null) return missing;
    final int? parsed = int.tryParse(value!.trim());
    if (parsed == null) return 'Enter minutes as a whole number';
    if (parsed < 1 || parsed > AppConstants.maxEtaMinutes) {
      return 'Arrival time must be 1 to ${AppConstants.maxEtaMinutes} minutes';
    }
    return null;
  }

  /// 13 digits, with or without dashes: 12345-1234567-1.
  static String? cnic(String? value) {
    final String? missing = required(value, 'CNIC');
    if (missing != null) return missing;
    final String digits = value!.replaceAll('-', '').trim();
    if (!RegExp(r'^\d{13}$').hasMatch(digits)) {
      return 'CNIC must have 13 digits';
    }
    return null;
  }

  static String? experience(String? value) {
    final String? missing = required(value, 'Experience');
    if (missing != null) return missing;
    final int? years = int.tryParse(value!.trim());
    if (years == null || years < 0 || years > 60) {
      return 'Enter years between 0 and 60';
    }
    return null;
  }

  static String? workshopAddress(String? value) {
    final String? missing = required(value, 'Workshop address');
    if (missing != null) return missing;
    if (value!.trim().length < 5) return 'Enter a fuller address';
    return null;
  }
}
