/// Build-time switches.
///
/// The app talks to the Node.js + MongoDB backend (folder `backend`).
/// `--dart-define=API_URL=https://your-server` changes the address
/// (default http://localhost:5000).
///
/// Run with `--dart-define=USE_MOCK=true` to use in-memory data instead (no
/// backend needed, nothing is saved).
///
/// Free photo upload (Cloudinary, no card needed):
/// `--dart-define=CLOUDINARY_CLOUD=<cloud name>`
/// `--dart-define=CLOUDINARY_PRESET=<unsigned upload preset>`
/// Without both values photos stay in demo mode (name and size only).
class AppConfig {
  AppConfig._();

  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5000',
  );

  static const String cloudinaryCloud =
      String.fromEnvironment('CLOUDINARY_CLOUD');
  static const String cloudinaryPreset =
      String.fromEnvironment('CLOUDINARY_PRESET');

  static bool get photoUploadEnabled =>
      cloudinaryCloud.isNotEmpty && cloudinaryPreset.isNotEmpty;
}
