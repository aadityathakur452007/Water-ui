import 'package:shared_preferences/shared_preferences.dart';

/// Token persistence (ssdlc notes):
/// - Only the opaque session token (+ cached role for the auth gate) is
///   stored. No password, no customer data, and per the contract's PII rule
///   the vendor API never returns user name/phone/email, so there is nothing
///   PII to leak from storage either.
/// - shared_preferences is "secure-ish" per the task brief: sufficient for a
///   30-day opaque bearer on device; a future hardening step is
///   flutter_secure_storage (Keychain/Keystore) with zero API changes
///   (this class is the only storage boundary).
class Session {
  static const _tokenKey = 'vendor.session.token';
  static const _roleKey = 'vendor.session.role';

  String? token;
  String? role;

  bool get isSignedIn => token != null && token!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    role = prefs.getString(_roleKey);
  }

  Future<void> save(String newToken, String newRole) async {
    token = newToken;
    role = newRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, newToken);
    await prefs.setString(_roleKey, newRole);
  }

  Future<void> clear() async {
    token = null;
    role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }
}
