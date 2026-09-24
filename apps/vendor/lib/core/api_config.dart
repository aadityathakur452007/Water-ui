/// API base URL resolution per fullstack-contract.md.
///
/// - Default: `http://localhost:3000` (iOS simulator, Docker host, CI).
/// - Android emulator: launch with
///   `--dart-define API_BASE_URL=http://10.0.2.2:3000`.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
}
