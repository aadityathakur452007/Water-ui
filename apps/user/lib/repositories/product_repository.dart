import '../config/app_config.dart';
import '../models/product_model.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

/// Product source. Sync methods serve the bundled demo catalog (kept for
/// tests + offline fallback); async methods hit the contract endpoints:
/// `GET /api/products`, `GET /api/products/search?q=`.
/// Widgets never hold hardcoded products.
class ProductRepository {
  const ProductRepository();

  List<ProductModel> all() => demoPopularProducts;

  ProductModel byId(String id, {ProductModel? fallback}) =>
      demoPopularProducts.firstWhere(
        (p) => p.id == id,
        orElse: () => fallback ?? demoPopularProducts.first,
      );

  /// Nullable lookup: returns null for unknown ids (order rows use this
  /// for the thumbnail fallback so a stale productId never throws).
  ProductModel? tryById(String id) {
    for (final p in demoPopularProducts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Refill↔jar cross-sell sibling. Returns null for the 1L bottle
  /// (unavailable — no cross-sell) and for unknown ids.
  ProductModel? crossSellSibling(String id) {
    if (id == 'wd-20l-refill') return tryById('wd-20l-jar');
    if (id == 'wd-20l-jar') return tryById('wd-20l-refill');
    return null;
  }

  List<ProductModel> byCategory(String query) {
    final q = query.toLowerCase();
    if (q.contains("jar")) {
      return demoPopularProducts.where((p) => p.unit == "jar").toList();
    }
    if (q.contains("can")) {
      return demoPopularProducts.where((p) => p.unit == "can").toList();
    }
    if (q.contains("bottle") || q.contains("packaged")) {
      return demoPopularProducts.where((p) => p.unit == "pack").toList();
    }
    return all();
  }

  List<ProductModel> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all();
    return demoPopularProducts.where((p) {
      final haystack =
          "${p.title} ${p.capacity} ${p.container} ${p.waterType} water jar bottle mineral drinking"
              .toLowerCase();
      return q.split(" ").every((word) => haystack.contains(word));
    }).toList();
  }

  Future<ApiClient> _client(ApiClient? client) async {
    if (client != null) return client;
    final token = await const SessionStore().readToken();
    return ApiClient(token: token);
  }

  static List<ProductModel> _parseList(dynamic body) {
    final list = body is List ? body : (body is Map ? body['products'] : null);
    if (list is! List) return demoPopularProducts;
    return list
        .whereType<Map>()
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /api/products` — full catalog (matches Flutter seed prices).
  /// Demo mode serves the bundled catalog (no network attempted).
  Future<List<ProductModel>> fetchAll({ApiClient? client}) async {
    if (AppConfig.demoMode && client == null) return all();
    final api = await _client(client);
    final body = await api.get('/api/products');
    return _parseList(body);
  }

  /// `GET /api/products/search?q=` — multi-word match on
  /// name/capacity/type (server-side).
  /// Demo mode searches the bundled catalog (no network attempted).
  Future<List<ProductModel>> searchRemote(String query,
      {ApiClient? client}) async {
    if (AppConfig.demoMode && client == null) return search(query);
    final api = await _client(client);
    final body = await api.get('/api/products/search', query: {'q': query});
    return _parseList(body);
  }
}
