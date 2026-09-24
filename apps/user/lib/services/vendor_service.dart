import '../config/app_config.dart';
import '../screens/vendor/vendor_order.dart';
import 'api_client.dart';
import 'session_store.dart';

class VendorSubscription {
  final int quantity;
  final String frequency;
  final String status;
  final String nextDelivery;

  const VendorSubscription({
    required this.quantity,
    required this.frequency,
    required this.status,
    required this.nextDelivery,
  });

  factory VendorSubscription.fromJson(Map<String, dynamic> json) =>
      VendorSubscription(
        quantity: (json['quantity'] as num? ?? 0).toInt(),
        frequency: '${json['frequency'] ?? ''}',
        status: '${json['status'] ?? ''}',
        nextDelivery:
            '${json['nextDelivery'] ?? json['next_delivery'] ?? ''}',
      );
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

/// Vendor data layer. Demo mode serves bundled seed instantly;
/// live mode hits the PII-stripped vendor endpoints (contract).
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

  static const _demoKpis = VendorKpis(
    todayDeliveries: 3,
    todayRevenue: 400,
    activeSubscriptions: 1,
    pendingOrders: 2,
  );

  static final _demoOrders = [
    VendorOrder(
      id: 'WD-00124',
      items: [
        VendorOrderItem(name: '20L Drinking Water Jar', qty: 2, price: 60),
      ],
      total: 130,
      addressLabel: 'Home',
      addressLine: '123, Example Colony',
      addressCity: 'Bhopal',
      slot: 'Tomorrow • 8:00 AM',
      status: 'scheduled',
      type: 'one-time',
      createdAt: 'Today',
    ),
    VendorOrder(
      id: 'WD-00119',
      items: [
        VendorOrderItem(name: '20L Drinking Water Jar', qty: 2, price: 60),
      ],
      total: 130,
      addressLabel: 'Home',
      addressLine: '123, Example Colony',
      addressCity: 'Bhopal',
      slot: 'Every Day • 8:00 AM',
      type: 'regular',
      status: 'active',
      createdAt: '20 Sept',
    ),
  ];

  Future<VendorKpis> fetchKpis() async {
    if (AppConfig.demoMode) return _demoKpis;
    final api = await _client();
    final body = await api.get('/api/vendor/kpis');
    return VendorKpis.fromJson(Map<String, dynamic>.from(body as Map));
  }

  Future<List<VendorOrder>> fetchOrders({String? status}) async {
    if (AppConfig.demoMode) {
      final all = List<VendorOrder>.from(_demoOrders);
      if (status == null || status.isEmpty || status == 'all') return all;
      return all.where((o) => o.status == status).toList();
    }
    final api = await _client();
    final body = await api.get('/api/vendor/orders',
        query: status == null ? null : {'status': status});
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
      final i = _demoOrders.indexWhere((o) => o.id == id);
      if (i == -1) throw const AppException('NOT_FOUND', 'Order not found');
      final o = _demoOrders[i];
      _demoOrders[i] = VendorOrder(
        id: o.id,
        items: o.items,
        total: o.total,
        addressLabel: o.addressLabel,
        addressLine: o.addressLine,
        addressCity: o.addressCity,
        slot: o.slot,
        status: status,
        type: o.type,
        createdAt: o.createdAt,
      );
      return;
    }
    final api = await _client();
    await api.patch('/api/vendor/orders/$id', body: {'status': status});
  }

  static const _demoSubs = [
    VendorSubscription(
      quantity: 2,
      frequency: 'Every Day',
      status: 'active',
      nextDelivery: 'Tomorrow • 8:00 AM',
    ),
  ];

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
