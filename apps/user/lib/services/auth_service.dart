import '../config/app_config.dart';
import '../config/demo_store.dart';
import 'api_client.dart';
import 'session_store.dart';

/// Single sign-in entry point shared by the login screen.
/// Demo mode serves the shared [DemoStore] seed sessions instantly
/// (no network); live mode talks to `POST /api/auth/*` and enforces
/// the role gate.
class AuthService {
  const AuthService({SessionStore? sessions, ApiClient? api})
      : _sessions = sessions ?? const SessionStore(),
        _api = api;

  final SessionStore _sessions;
  final ApiClient? _api;

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required String role, // 'user' | 'vendor'
  }) async {
    final id = identifier.trim();
    if (AppConfig.demoMode) {
      Map<String, dynamic>? match;
      for (final u in DemoStore.users) {
        final email = '${u['email'] ?? ''}';
        final phone = '${u['phone'] ?? ''}';
        if ((id == email || id == phone) &&
            password == '${u['password'] ?? ''}' &&
            role == '${u['role'] ?? ''}') {
          match = u;
          break;
        }
      }
      if (match == null) {
        throw const AppException(
            'UNAUTHENTICATED', 'Invalid demo credentials');
      }
      final user = <String, dynamic>{
        'id': '${match['id'] ?? ''}',
        'name': '${match['name'] ?? ''}',
        'role': '${match['role'] ?? ''}',
      };
      await _sessions.saveSession(token: 'demo-token-$role', user: user);
      return user;
    }
    final api = _api ?? ApiClient();
    final body = id.contains('@')
        ? {'email': id, 'password': password}
        : {'phone': id, 'password': password};
    final res =
        await api.post('/api/auth/login', body: body) as Map;
    final token = res['token']?.toString() ?? '';
    final user = res['user'] is Map
        ? Map<String, dynamic>.from(res['user'] as Map)
        : <String, dynamic>{};
    if (token.isEmpty) throw const AppException('UNKNOWN', 'No token');
    if ((user['role']?.toString() ?? 'user') != role) {
      throw AppException('FORBIDDEN',
          role == 'vendor' ? 'Vendor access only' : 'Not a user account');
    }
    await _sessions.saveSession(token: token, user: user);
    return user;
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (AppConfig.demoMode) {
      // Demo registration resolves to the seeded demo-user profile
      // (same session shape as login; no new seed rows are created).
      Map<String, dynamic>? seed;
      for (final u in DemoStore.users) {
        if ('${u['role']}' == 'user') {
          seed = u;
          break;
        }
      }
      final user = <String, dynamic>{
        'id': '${seed?['id'] ?? 'demo-user'}',
        'name': '${seed?['name'] ?? 'Demo User'}',
        'role': 'user',
      };
      await _sessions.saveSession(
          token: 'demo-token-user', user: user);
      return user;
    }
    final api = _api ?? ApiClient();
    final res = await api.post('/api/auth/register', body: {
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'password': password,
    }) as Map;
    final token = res['token']?.toString() ?? '';
    final user = res['user'] is Map
        ? Map<String, dynamic>.from(res['user'] as Map)
        : <String, dynamic>{};
    if (token.isEmpty) throw const AppException('UNKNOWN', 'No token');
    await _sessions.saveSession(token: token, user: user);
    return user;
  }

  Future<void> logout() => _sessions.clear();

  /// Call when an API call fails with UNAUTHENTICATED: drops the dead
  /// session so the next screen shows login instead of retry loops.
  Future<void> handleUnauthorized() => logout();

  Future<String?> role() async {
    final user = await _sessions.readUser();
    return user?['role']?.toString();
  }
}
