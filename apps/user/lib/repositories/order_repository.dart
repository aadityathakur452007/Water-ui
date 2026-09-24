import '../config/app_config.dart';
import '../models/cart_model.dart';
import '../models/order_model.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

/// Order source. Sync methods serve bundled demo orders (kept for tests +
/// offline fallback); async methods hit the contract endpoints:
/// `POST /api/orders`, `GET /api/orders`, `PATCH /api/orders/:id/cancel`.
/// Statuses here mirror what the backend returns.
class OrderRepository {
  const OrderRepository();

  List<Order> ongoing() => const [
        Order(
          id: "WD-00124",
          items: [
            OrderItem(
              productId: "wd-20l",
              name: "20L Drinking Water Jar",
              qty: 2,
              price: 60,
            ),
          ],
          address: defaultAddress,
          orderType: OrderType.oneTime,
          status: OrderStatus.scheduled,
          totalAmount: 130,
          deliverySlot: "Tomorrow • 8:00 AM",
          createdAt: "24 Sept • 7:30 AM",
        ),
        Order(
          id: "WD-00119",
          items: [
            OrderItem(
              productId: "wd-20l",
              name: "20L Drinking Water Jar",
              qty: 2,
              price: 60,
            ),
          ],
          address: defaultAddress,
          orderType: OrderType.regular,
          status: OrderStatus.active,
          totalAmount: 130,
          deliverySlot: "Every Day • 8:00 AM",
          createdAt: "20 Sept • 8:00 AM",
        ),
      ];

  List<Order> past() => const [
        Order(
          id: "WD-00110",
          items: [
            OrderItem(
              productId: "wd-10l",
              name: "10L Drinking Water Can",
              qty: 1,
              price: 40,
            ),
          ],
          address: defaultAddress,
          orderType: OrderType.oneTime,
          status: OrderStatus.delivered,
          totalAmount: 50,
          deliverySlot: "18 Sept • 8:00 AM",
          createdAt: "17 Sept • 6:10 PM",
        ),
        Order(
          id: "WD-00098",
          items: [
            OrderItem(
              productId: "wd-1l-12",
              name: "1L Bottles · Pack of 12",
              qty: 1,
              price: 120,
            ),
          ],
          address: defaultAddress,
          orderType: OrderType.oneTime,
          status: OrderStatus.cancelled,
          totalAmount: 130,
          deliverySlot: "10 Sept • 8:00 AM",
          createdAt: "9 Sept • 9:40 AM",
        ),
      ];

  Order? lastOrder() {
    final list = ongoing();
    return list.isEmpty ? null : list.first;
  }

  static int _counter = 125;

  /// Places an order locally; returns the confirmed order.
  Order placeOrder({
    required List<OrderItem> items,
    required double total,
    required OrderType orderType,
    required String deliverySlot,
  }) {
    return Order(
      id: "WD-${_counter++}",
      items: items,
      address: defaultAddress,
      orderType: orderType,
      status: OrderStatus.scheduled,
      totalAmount: total,
      deliverySlot: deliverySlot,
      createdAt: "Today",
    );
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
  /// Demo mode serves bundled seed instantly (no network attempted).
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
  /// Demo mode is a no-op (seed list is static).
  Future<void> cancelOrder(String id, {ApiClient? client}) async {
    if (AppConfig.demoMode && client == null) return;
    final api = await _client(client);
    await api.patch('/api/orders/$id/cancel');
  }
}
