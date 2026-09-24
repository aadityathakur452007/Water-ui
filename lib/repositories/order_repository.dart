import '../models/order_model.dart';

/// Local/mock order source. Statuses here mirror what the backend
/// will eventually return — widgets never hardcode progression.
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
}
