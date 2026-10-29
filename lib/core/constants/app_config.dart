/// Build-time switches.
///
/// The app talks to the Node.js + MongoDB backend (folder `backend`).
/// `--dart-define=API_URL=https://your-server` changes the address
/// (default http://localhost:5000).
///
/// Run with `--dart-define=USE_MOCK=true` to use in-memory data instead (no
/// backend needed, nothing is saved).
class AppConfig {
  AppConfig._();

  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5000',
  );
}
