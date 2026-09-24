import '../../core/api_client.dart';
import '../../core/session.dart';

/// POST /api/auth/login {phone, password} -> {token, user}.
///
/// Contract: role is server-side. The app verifies `user.role == 'vendor'`
/// and refuses otherwise ("Vendor access only") — a non-vendor token is
/// discarded, never persisted.
class AuthService {
  AuthService(this._api, this._session);

  final ApiClient _api;
  final Session _session;

  Future<void> login({required String phone, required String password}) async {
    final body = await _api.post('/api/auth/login', {
      'phone': phone.trim(),
      'password': password,
    });
    final map = body as Map<String, dynamic>;
    final user = map['user'] as Map<String, dynamic>?;
    if (user == null || user['role'] != 'vendor') {
      // Do not persist a non-vendor session.
      throw ApiException('FORBIDDEN', 'Vendor access only', 403);
    }
    await _session.save(map['token'] as String, 'vendor');
  }

  Future<void> logout() => _session.clear();
}
