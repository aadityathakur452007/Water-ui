import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Uniform contract error: `{error: {code, message}}` + HTTP status.
class ApiException implements Exception {
  ApiException(this.code, this.message, this.status);

  final String code;
  final String message;
  final int status;

  @override
  String toString() => message;
}

/// Minimal JSON client. Token is attached per request (no storage here —
/// see [Session]); nothing sensitive is ever logged.
class ApiClient {
  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final err = body is Map ? body['error'] : null;
    throw ApiException(
      err is Map && err['code'] is String ? err['code'] as String : 'UNKNOWN',
      err is Map && err['message'] is String
          ? err['message'] as String
          : 'Request failed (${res.statusCode})',
      res.statusCode,
    );
  }

  Future<dynamic> get(String path, {String? token}) async {
    final res = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers(token),
    );
    return _decode(res);
  }

  Future<dynamic> post(String path, Map<String, Object?> json,
      {String? token}) async {
    final res = await _http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers(token),
      body: jsonEncode(json),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, Map<String, Object?> json,
      {String? token}) async {
    final res = await _http.patch(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers(token),
      body: jsonEncode(json),
    );
    return _decode(res);
  }
}
