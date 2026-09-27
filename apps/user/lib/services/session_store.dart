import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the auth session (token + user) via shared_preferences.
/// The UI reads the token on boot and injects it into [ApiClient].
class SessionStore {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _seenOnboardingKey = 'seen_onboarding';

  const SessionStore();

  Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> readUser() async {    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// First-launch flag: false until the onboarding flow completes or is
  /// skipped. Sign-out ([clear]) never resets it — onboarding shows once
  /// per install, never after auth.
  Future<bool> readSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenOnboardingKey) ?? false;
  }

  Future<void> setSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
  }

  /// Merges [fields] (e.g. name/phone from the profile edit sheet) into
  /// the stored user map so the header and user-info screen reflect them.
  Future<void> updateUserFields(Map<String, String> fields) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await readUser() ?? <String, dynamic>{};
    for (final entry in fields.entries) {
      current[entry.key] = entry.value;
    }
    await prefs.setString(_userKey, jsonEncode(current));
  }
}
