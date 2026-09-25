import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown for every non-2xx API response.
///
/// The backend always replies `{error: {code, message}}` with an HTTP
/// status. Codes: VALIDATION, UNAUTHENTICATED, FORBIDDEN, NOT_FOUND,
/// CONFLICT (see fullstack-contract.md).
class AppException implements Exception {
  final String code;
  final String message;
  final int? status;

  const AppException(this.code, this.message, [this.status]);

  @override
  String toString() => '$code: $message';
}

/// Thin HTTP layer. Repositories own models; this class only talks
/// network and maps `{error}` payloads to [AppException].
class ApiClient {
  /// `--dart-define API_BASE_URL=<url>` wins, else the Android-emulator
  /// loopback. iOS sim / Docker host / CI pass their own URL via the
  /// dart-define (contract: `http://localhost:3000`).
  final String baseUrl;
  final http.Client _http;

  /// Set from [SessionStore] after login; sent as `Authorization: Bearer`.
  String? token;

  ApiClient({String? baseUrl, http.Client? httpClient, this.token})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:3000',
            ),
        _http = httpClient ?? http.Client();

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      throw AppException('UNKNOWN', 'Bad server response', res.statusCode);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      throw AppException(
        err['code']?.toString() ?? 'UNKNOWN',
        err['message']?.toString() ?? 'Request failed',
        res.statusCode,
      );
    }
    throw AppException('UNKNOWN', 'Request failed', res.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await _send(_http.get(uri, headers: _headers()));
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _send(_http.post(
      uri,
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    ));
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _send(_http.patch(
      uri,
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    ));
    return _decode(res);
  }

  void close() => _http.close();

  /// 15s ceiling per request: a hanging server becomes a typed error
  /// instead of an infinite spinner. Transport failures map to NETWORK
  /// so screens can offer retry (and stay offline-capable in demo).
  static const _timeout = Duration(seconds: 15);

  Future<http.Response> _send(Future<http.Response> call) async {
    try {
      return await call.timeout(_timeout);
    } on TimeoutException {
      throw const AppException(
          'NETWORK', 'Server unreachable. Try again.');
    } catch (_) {
      throw const AppException(
          'NETWORK', 'Could not reach the server.');
    }
  }
}
