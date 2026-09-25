import '../config/app_config.dart';
import '../config/demo_store.dart';
import '../screens/vendor/vendor_order.dart';
import 'api_client.dart';
import 'session_store.dart';

/// Turns a wire enum (`every_day`) into a display label (`Every day`).
/// Never surfaces raw wire values in the UI.
String humanizeFrequency(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Query for `GET /api/vendor/orders`: 'all'/empty means "no filter"
/// (the backend has no `all` status — sending `?status=all` returns nothing).
Map<String, String>? ordersQuery(String? status) =>
    (status == null || status.isEmpty || status == 'all')
        ? null
        : {'status': status};

class VendorSubscription {
  final String productId;
  final String productName;
  final int quantity;
  final String frequency;
  final String status;
  final String nextDelivery;

  const VendorSubscription({
    this.productId = '',
    this.productName = '',
    required this.quantity,
    required this.frequency,
    required this.status,
    required this.nextDelivery,
  });

  factory VendorSubscription.fromJson(Map<String, dynamic> json) {
    // Live rows nest the product (`product: {id, name}`); user rows use
    // flat `product_id`/`product_name`. Accept both, never user PII.
    final product = json['product'];
    final Map<String, dynamic> p =
        product is Map<String, dynamic> ? product : const {};
    return VendorSubscription(
      productId: '${json['product_id'] ?? json['productId'] ?? p['id'] ?? ''}',
      productName:
          '${p['name'] ?? json['product_name'] ?? json['productName'] ?? json['product_id'] ?? ''}',
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      frequency: humanizeFrequency('${json['frequency'] ?? ''}'),
      status: '${json['status'] ?? ''}',
      nextDelivery:
          '${json['nextDelivery'] ?? json['next_delivery'] ?? ''}',
    );
  }
}

class VendorKpis {  final int todayDeliveries;
  final num todayRevenue;
  final int activeSubscriptions;
  final int pendingOrders;

  const VendorKpis({
    required this.todayDeliveries,
    required this.todayRevenue,
    required this.activeSubscriptions,
    required this.pendingOrders,
  });

  factory VendorKpis.fromJson(Map<String, dynamic> json) => VendorKpis(
        todayDeliveries: (json['todayDeliveries'] as num? ?? 0).toInt(),
        todayRevenue: json['todayRevenue'] as num? ?? 0,
        activeSubscriptions:
            (json['activeSubscriptions'] as num? ?? 0).toInt(),
        pendingOrders: (json['pendingOrders'] as num? ?? 0).toInt(),
      );
}

/// Vendor data layer. Demo mode serves the shared [DemoStore] instantly
/// (the same order list the user repositories use); live mode hits the
/// PII-stripped vendor endpoints (contract) plus the approved nested
/// `customer: {name, phone, email}` identity block.
class VendorService {
  const VendorService({SessionStore? sessions, ApiClient? api})
      : _sessions = sessions ?? const SessionStore(),
        _api = api;

  final SessionStore _sessions;
  final ApiClient? _api;

  Future<ApiClient> _client() async {
    if (_api != null) return _api;
    return ApiClient(token: await _sessions.readToken());
  }

  static List<VendorOrder> get _demoOrders => DemoStore.orders
      .map((e) => VendorOrder.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static VendorKpis get _demoKpis {
    final all = _demoOrders;
    final deliveredToday = all
        .where((o) => o.status == 'delivered' && o.createdAt == 'Today')
        .toList();
    final pending = all
        .where((o) =>
            o.status == 'scheduled' ||
            o.status == 'preparing' ||
            o.status == 'out_for_delivery')
        .length;
    final activeSubs = _demoSubs.where((s) => s.status == 'active').length;
    final revenue =
        deliveredToday.fold<num>(0, (sum, o) => sum + o.total);
    return VendorKpis(
      todayDeliveries: deliveredToday.length,
      todayRevenue: revenue,
      activeSubscriptions: activeSubs,
      pendingOrders: pending,
    );
  }

  Future<VendorKpis> fetchKpis() async {
    if (AppConfig.demoMode) return _demoKpis;
    final api = await _client();
    final body = await api.get('/api/vendor/kpis');
    return VendorKpis.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<List<VendorOrder>> fetchOrders({String? status}) async {
    if (AppConfig.demoMode) {
      final all = _demoOrders;
      if (status == null || status.isEmpty || status == 'all') return all;
      return all.where((o) => o.status == status).toList();
    }
    final api = await _client();
    final body = await api.get('/api/vendor/orders',
        query: ordersQuery(status));
    final list = body is List ? body : (body as Map)['orders'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) =>
            VendorOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> updateStatus(String id, String status) async {
    if (AppConfig.demoMode) {
      final i = DemoStore.orders.indexWhere((o) => '${o['id']}' == id);
      if (i == -1) throw const AppException('NOT_FOUND', 'Order not found');
      final o = VendorOrder.fromJson(
          Map<String, dynamic>.from(DemoStore.orders[i]));
      // Mirror the live guard (contract: forward-only, any→cancelled):
      // illegal jumps are rejected here just like the live 409.
      final isFinal = o.status == 'delivered' || o.status == 'cancelled';
      final legal =
          (status == 'cancelled' && !isFinal) || status == nextStatus(o.status);
      if (!legal) {
        throw AppException(
            'CONFLICT', 'Cannot move order from ${o.status} to $status');
      }
      DemoStore.orders[i] = {
        ...DemoStore.orders[i],
        'status': status,
      };
      return;
    }
    final api = await _client();
    await api.patch('/api/vendor/orders/$id', body: {'status': status});
  }

  static List<VendorSubscription> get _demoSubs => DemoStore
      .vendorSubscriptions
      .map((e) => VendorSubscription.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  Future<List<VendorSubscription>> fetchVendorSubscriptions() async {
    if (AppConfig.demoMode) return List.of(_demoSubs);
    final api = await _client();
    final body = await api.get('/api/vendor/subscriptions');
    final list = body is List ? body : (body as Map)['subscriptions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => VendorSubscription.fromJson(
            Map<String, dynamic>.from(e)))
        .toList();
  }
}
