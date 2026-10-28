/// App-wide constants. Business rules come from the SRS use cases.
class AppConstants {
  AppConstants._();

  static const String appName = 'FixOnWay';
  static const String tagline = 'Help, on your way.';

  /// UC-01: minimum password length.
  static const int minPasswordLength = 8;

  /// UC-03: OTP rules.
  static const int otpLength = 6;
  static const Duration otpValidity = Duration(minutes: 5);
  static const int maxOtpAttempts = 3;
  static const Duration otpResendWait = Duration(seconds: 60);

  /// UC-02: lock the account after too many wrong passwords.
  static const int maxLoginAttempts = 5;
  static const Duration loginLockDuration = Duration(minutes: 15);

  /// Development only: the code the mock repository always "sends".
  static const String demoOtp = '123456';

  /// UC-21: saved vehicles.
  static const int maxVehicles = 5;

  /// UC-08 / UC-11: request rules.
  static const int maxDescriptionLength = 300;
  static const int maxPhotos = 3;
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const Duration requestExpiry = Duration(minutes: 15);

  /// UC-13: how long a mechanic estimate stays valid.
  static const Duration estimateValidity = Duration(minutes: 10);
  static const int minEstimateAmount = 100;
  static const int maxEstimateAmount = 100000;
  static const int maxEtaMinutes = 120;

  /// UC-12 / UC-24: search and service radius in km.
  static const int minRadiusKm = 1;
  static const int maxRadiusKm = 20;
  static const int defaultRadiusKm = 10;

  /// UC-15: the demo mechanic travels this many times faster than real time.
  static const int trackingSpeedUp = 10;

  /// Live GPS: a mechanic position older than this is ignored, and the
  /// demo tracking is shown instead.
  static const Duration liveLocationMaxAge = Duration(minutes: 2);

  /// UC-16: chat message length.
  static const int maxMessageLength = 500;

  /// UC-19 / UC-22.
  static const int maxReviewLength = 300;
  static const int minComplaintLength = 10;
  static const int maxComplaintLength = 500;
}
