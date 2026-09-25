import '../config/app_config.dart';
import '../config/demo_store.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

/// Order source. Sync methods serve bundled demo orders (kept for tests +
/// offline fallback); async methods hit the contract endpoints:
/// `POST /api/orders`, `GET /api/orders`, `PATCH /api/orders/:id/cancel`.
/// Statuses here mirror what the backend returns.
///
/// Demo mode reads/writes the shared [DemoStore] order list (the same list
/// the vendor service uses), so a user-placed order appears in the vendor
/// fetch and a vendor status advance reflects here after refresh.
/// [createOrder] appends with its `WD-` counter id and embedded ₹10 fee;
/// [cancelOrder] marks it cancelled.
class OrderRepository {
  const OrderRepository();

  static List<Order> _demoAll() => DemoStore.orders
      .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static bool _isOngoingStatus(OrderStatus s) =>
      s == OrderStatus.scheduled ||
      s == OrderStatus.preparing ||
      s == OrderStatus.outForDelivery ||
      s == OrderStatus.active;

  List<Order> ongoing() =>
      _demoAll().where((o) => _isOngoingStatus(o.status)).toList();

  List<Order> past() =>
      _demoAll().where((o) => !_isOngoingStatus(o.status)).toList();

  Order? lastOrder() {
    final list = ongoing();
    return list.isEmpty ? null : list.first;
  }

  /// Places an order locally; returns the confirmed order and records
  /// it in the shared demo store (₹10 fee embedded in [total]).
  /// Address falls back to [defaultAddress] when neither [addressId] nor
  /// [address] resolves (same fallback as before).
  Order placeOrder({
    required List<OrderItem> items,
    required double total,
    required OrderType orderType,
    required String deliverySlot,
    String? addressId,
    Map<String, String>? address,
  }) {
    final id = 'WD-${DemoStore.nextOrderNumber()}';
    final resolved = _resolveAddress(addressId, address);
    final map = <String, dynamic>{
      'id': id,
      'type': orderType == OrderType.regular ? 'regular' : 'one-time',
      'status': 'scheduled',
      'total': total,
      'slot': deliverySlot,
      'created_at': 'Today',
      'items': [
        for (final e in items)
          {
            'productId': e.productId,
            'name': e.name,
            'qty': e.qty,
            'price': e.price,
          },
      ],
      'address': {
        'label': resolved.label,
        'line': resolved.line,
        'city': resolved.city,
      },
      'customer': {
        'name': 'Demo User',
        'phone': '9000000001',
        'email': 'user@demo.local',
      },
    };
    DemoStore.orders.insert(0, map);
    return Order.fromJson(Map<String, dynamic>.from(map));
  }

  static DeliveryAddress _resolveAddress(
      String? addressId, Map<String, String>? address) {
    if (address != null) {
      return DeliveryAddress(
        label: address['label'] ?? 'Home',
        line: address['line'] ?? '',
        city: address['city'] ?? '',
      );
    }
    if (addressId != null) {
      for (final a in DemoStore.addresses) {
        if ('${a['id']}' == addressId) {
          return DeliveryAddress(
            label: '${a['label'] ?? 'Home'}',
            line: '${a['line'] ?? ''}',
            city: '${a['city'] ?? ''}',
          );
        }
      }
    }
    return defaultAddress;
  }

  Future<ApiClient> _client(ApiClient? client) async {
    if (client != null) return client;
    final token = await const SessionStore().readToken();
    return ApiClient(token: token);
  }

  static List<Order> _parseList(dynamic body) {
    final list = body is List ? body : (body is Map ? body['orders'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /api/orders` — own orders, newest first (auth required).
  /// Demo mode serves the shared store instantly (no network attempted).
  Future<List<Order>> fetchOrders({ApiClient? client}) async {
    if (AppConfig.demoMode && client == null) {
      return [...ongoing(), ...past()];
    }
    final api = await _client(client);
    final body = await api.get('/api/orders');
    return _parseList(body);
  }

  /// `POST /api/orders {items:[{productId,qty}], addressId|address,
  /// type, slot}` → 201 order, status `scheduled`.
  Future<Order> createOrder({
    required List<OrderItem> items,
    required String slot,
    required OrderType orderType,
    String? addressId,
    Map<String, String>? address,
    ApiClient? client,
  }) async {
    if (AppConfig.demoMode && client == null) {
      final subtotal =
          items.fold<double>(0, (s, e) => s + e.price * e.qty);
      return placeOrder(
        items: items,
        total: subtotal + Cart.deliveryFee,
        orderType: orderType,
        deliverySlot: slot,
        addressId: addressId,
        address: address,
      );
    }
    final api = await _client(client);
    final body = await api.post('/api/orders', body: {
      'items': [
        for (final e in items) {'productId': e.productId, 'qty': e.qty},
      ],
      if (addressId != null) 'addressId': addressId,
      if (address != null) 'address': address,
      'type': orderType == OrderType.regular ? 'regular' : 'one-time',
      'slot': slot,
    });
    final orderJson = body is Map && body['order'] is Map
        ? Map<String, dynamic>.from(body['order'] as Map)
        : Map<String, dynamic>.from(body as Map);
    return Order.fromJson(orderJson);
  }

  /// `PATCH /api/orders/:id/cancel` — own + only when `scheduled`.
  /// Demo mode marks the booked order cancelled so the next
  /// `fetchOrders` shows the new status (orders screen reloads).
  Future<void> cancelOrder(String id, {ApiClient? client}) async {
    if (AppConfig.demoMode && client == null) {
      final index = DemoStore.orders.indexWhere((o) => '${o['id']}' == id);
      if (index != -1) {
        DemoStore.orders[index] = {
          ...DemoStore.orders[index],
          'status': 'cancelled',
        };
      }
      return;
    }
    final api = await _client(client);
    await api.patch('/api/orders/$id/cancel');
  }
}
