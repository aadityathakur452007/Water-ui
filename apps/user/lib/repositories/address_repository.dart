import '../config/app_config.dart';
import '../config/demo_store.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

/// Delivery address as stored by the backend:
/// `GET /api/addresses` → `[{id, label, line, city}]`,
/// `POST /api/addresses {label, line, city}` → 201 address.
class Address {
  final String id;
  final String label;
  final String line;
  final String city;

  const Address({
    required this.id,
    required this.label,
    required this.line,
    required this.city,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      line: json['line']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
    );
  }
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

  /// `POST /api/addresses {label, line, city}` → 201 address.
  Future<Address> createAddress({
    required String label,
    required String line,
    required String city,
    ApiClient? client,
  }) async {
    if (AppConfig.demoMode && client == null) {
      final created = <String, dynamic>{
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'label': label.trim(),
        'line': line.trim(),
        'city': city.trim(),
      };
      DemoStore.addresses.add(created);
      return Address.fromJson(Map<String, dynamic>.from(created));
    }
    final api = await _client(client);
    final body = await api.post('/api/addresses', body: {
      'label': label.trim(),
      'line': line.trim(),
      'city': city.trim(),
    });
    return Address.fromJson(Map<String, dynamic>.from(body as Map));
  }
}
