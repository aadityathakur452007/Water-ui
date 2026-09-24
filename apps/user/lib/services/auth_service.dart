import '../config/app_config.dart';
import 'api_client.dart';
import 'session_store.dart';

/// Single sign-in entry point shared by the login screen.
/// Demo mode serves bundled seed sessions instantly (no network);
/// live mode talks to `POST /api/auth/*` and enforces the role gate.
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
      final ok = (role == 'user' &&
              id == AppConfig.demoUserEmail &&
              password == AppConfig.demoUserPassword) ||
          (role == 'vendor' &&
              id == AppConfig.demoVendorEmail &&
              password == AppConfig.demoVendorPassword);
      if (!ok) {
        throw const AppException(
            'UNAUTHENTICATED', 'Invalid demo credentials');
      }
      final user = role == 'vendor'
          ? const {
              'id': 'demo-vendor',
              'name': 'Demo Vendor',
              'role': 'vendor',
            }
          : const {
              'id': 'demo-user',
              'name': 'Demo User',
              'role': 'user',
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
      const user = {
        'id': 'demo-user',
        'name': 'Demo User',
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

  Future<String?> role() async {
    final user = await _sessions.readUser();
    return user?['role']?.toString();
  }
}
