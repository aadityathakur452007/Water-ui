import '../config/app_config.dart';
import '../config/demo_store.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

/// Delivery address as stored by the backend:
/// `GET /api/addresses` → `[{id, label, line, city, house, street, area,
/// pincode, phone, lat, lng}]`,
/// `POST /api/addresses {label, line, city, ...optional}` → 201 address.
/// Extended fields are nullable for back-compat: old rows keep working
/// with the `line` fallback (see [displayLine]).
class Address {
  final String id;
  final String label;
  final String line;
  final String city;
  final String? house;
  final String? street;
  final String? area;
  final String? pincode;
  final String? phone;
  final double? lat;
  final double? lng;

  const Address({
    required this.id,
    required this.label,
    required this.line,
    required this.city,
    this.house,
    this.street,
    this.area,
    this.pincode,
    this.phone,
    this.lat,
    this.lng,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    double? numOrNull(dynamic v) {
      if (v == null || (v is String && v.trim().isEmpty)) return null;
      return (v as num?)?.toDouble() ?? double.tryParse(v.toString());
    }

    String? strOrNull(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return Address(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      line: json['line']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      house: strOrNull(json['house']),
      street: strOrNull(json['street']),
      area: strOrNull(json['area']),
      pincode: strOrNull(json['pincode']),
      phone: strOrNull(json['phone']),
      lat: numOrNull(json['lat']),
      lng: numOrNull(json['lng']),
    );
  }

  /// Full address line: extended parts when present, else legacy [line].
  String get displayLine {
    final parts = [house, street, area].whereType<String>().toList();
    return parts.isEmpty ? line : parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'label': label.trim(),
        'line': line.trim(),
        'city': city.trim(),
        if (house != null) 'house': house,
        if (street != null) 'street': street,
        if (area != null) 'area': area,
        if (pincode != null) 'pincode': pincode,
        if (phone != null) 'phone': phone,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

/// Allowlist field validators (mirror backend 400 rules). Null = valid.
String? validatePincode(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  return RegExp(r'^[1-9][0-9]{5}$').hasMatch(s)
      ? null
      : 'Enter a 6-digit pincode';
}

String? validatePhone(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  return RegExp(r'^[0-9]{10}$').hasMatch(s)
      ? null
      : 'Enter a 10-digit phone number';
}

String? validateLat(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  if (n == null || n < -90 || n > 90) return 'Lat must be -90 to 90';
  return null;
}

String? validateLng(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  if (n == null || n < -180 || n > 180) return 'Lng must be -180 to 180';
  return null;
}

/// Address source. Demo mode serves the shared [DemoStore] address list
/// instantly (no network attempted) and persists created addresses there
/// for the session; live mode hits the contract endpoints
/// `GET /api/addresses` and `POST /api/addresses` (auth required).
class AddressRepository {
  const AddressRepository();

  List<Address> demo() => DemoStore.addresses
      .map((e) => Address.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  Future<ApiClient> _client(ApiClient? client) async {
    if (client != null) return client;
    final token = await const SessionStore().readToken();
    return ApiClient(token: token);
  }

  static List<Address> _parseList(dynamic body) {
    final list =
        body is List ? body : (body is Map ? body['addresses'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Address.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /api/addresses` — own addresses, oldest first.
  /// Empty list is valid (genuine-empty → empty state in the UI).
  /// Demo mode returns the persisted in-memory list (seed + created).
  Future<List<Address>> fetchAddresses({ApiClient? client}) async {
    if (AppConfig.demoMode && client == null) return demo();
    final api = await _client(client);
    final body = await api.get('/api/addresses');
    return _parseList(body);
  }

  /// `POST /api/addresses {label, line, city, ...optional}` → 201 address.
  Future<Address> createAddress({
    required String label,
    required String line,
    required String city,
    String? house,
    String? street,
    String? area,
    String? pincode,
    String? phone,
    double? lat,
    double? lng,
    ApiClient? client,
  }) async {
    final payload = <String, dynamic>{
      'label': label.trim(),
      'line': line.trim(),
      'city': city.trim(),
      if (house?.trim().isNotEmpty ?? false) 'house': house!.trim(),
      if (street?.trim().isNotEmpty ?? false) 'street': street!.trim(),
      if (area?.trim().isNotEmpty ?? false) 'area': area!.trim(),
      if (pincode?.trim().isNotEmpty ?? false) 'pincode': pincode!.trim(),
      if (phone?.trim().isNotEmpty ?? false) 'phone': phone!.trim(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
    if (AppConfig.demoMode && client == null) {
      final created = <String, dynamic>{
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        ...payload,
      };
      DemoStore.addresses.add(created);
      return Address.fromJson(Map<String, dynamic>.from(created));
    }
    final api = await _client(client);
    final body = await api.post('/api/addresses', body: payload);
    return Address.fromJson(Map<String, dynamic>.from(body as Map));
  }
}
