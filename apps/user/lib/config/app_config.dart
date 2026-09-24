/// App-wide runtime config. Everything is compile-time overridable so
/// CI/release builds stay deterministic with zero code changes:
///
///   flutter build apk --dart-define=API_BASE_URL=http://10.0.2.2:3000
///                     --dart-define=DEMO_MODE=false
class AppConfig {
  /// Base URL of the Hono API. Default targets the Android emulator
  /// loopback; iOS sim / host / CI pass their own via dart-define.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// When true (default), the app runs fully offline on bundled seed data:
  /// no network is attempted, demo logins work instantly, repositories serve
  /// local data. Set false to talk to a real backend (with error states).
  static const demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );

  /// Demo logins (demo mode only — never sent to a server).
  static const demoUserEmail = 'user@demo.local';
  static const demoUserPassword = 'demo123';
  static const demoVendorEmail = 'vendor@demo.local';
  static const demoVendorPassword = 'vendor123';
}
