import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';

/// Focused tests for the purchase-flow fixes:
/// demo order-book (create→listed, cancel→changed), displayLabel,
/// and OrderStatus granularity (preparing / out_for_delivery 1:1).
void main() {
  const orders = OrderRepository();

  test('demo create appends the order (WD- id, fee embedded) so it lists',
      () async {
    final before = await orders.fetchOrders();
    final created = await orders.createOrder(
      items: const [
        OrderItem(
          productId: 'wd-20l',
          name: '20L Drinking Water Jar',
          qty: 1,
          price: 60,
        ),
      ],
      slot: 'Today • 8:00 AM',
      orderType: OrderType.oneTime,
    );
    expect(created.id, startsWith('WD-'));
    expect(created.status, OrderStatus.scheduled);
    expect(created.totalAmount, 60 + Cart.deliveryFee);

    final after = await orders.fetchOrders();
    expect(after.length, before.length + 1);
    expect(after.map((o) => o.id), contains(created.id));
  });

  test('demo cancel changes the status everywhere', () async {
    final created = await orders.createOrder(
      items: const [
        OrderItem(
          productId: 'wd-10l',
          name: '10L Drinking Water Can',
          qty: 1,
          price: 40,
        ),
      ],
      slot: 'Today • 8:00 AM',
      orderType: OrderType.oneTime,
    );
    await orders.cancelOrder(created.id);

    final after = await orders.fetchOrders();
    final match = after.firstWhere((o) => o.id == created.id);
    expect(match.status, OrderStatus.cancelled);
  });

  test('displayLabel format is Order #<id> · <n> items · <slot>', () {
    const order = Order(
      id: 'WD-00124',
      items: [
        OrderItem(
          productId: 'wd-20l',
          name: '20L Drinking Water Jar',
          qty: 2,
          price: 60,
        ),
      ],
      address: defaultAddress,
      orderType: OrderType.oneTime,
      status: OrderStatus.scheduled,
      totalAmount: 130,
      deliverySlot: 'Tomorrow • 8:00 AM',
      createdAt: 'Today',
    );
    expect(order.displayLabel,
        'Order #WD-00124 · 2 items · Tomorrow • 8:00 AM');
  });

  test('status parsing maps preparing/out_for_delivery 1:1', () {
    expect(parseOrderStatus('scheduled'), OrderStatus.scheduled);
    expect(parseOrderStatus('preparing'), OrderStatus.preparing);
    expect(
        parseOrderStatus('out_for_delivery'), OrderStatus.outForDelivery);
    expect(parseOrderStatus('delivered'), OrderStatus.delivered);
    expect(parseOrderStatus('cancelled'), OrderStatus.cancelled);
    expect(parseOrderStatus('not_delivered'), OrderStatus.notDelivered);
    // Unknown future in-transit states still fall back to active.
    expect(parseOrderStatus('flying_drone'), OrderStatus.active);

    expect(orderStatusLabel(OrderStatus.preparing), 'Preparing');
    expect(
        orderStatusLabel(OrderStatus.outForDelivery), 'Out for delivery');
  });

  test('Order.fromJson keeps preparing/out_for_delivery granularity', () {
    Map<String, dynamic> jsonWith(String status) => {
          'id': 'WD-9',
          'type': 'one-time',
          'status': status,
          'total': 130,
          'slot': 'Today • 8:00 AM',
          'created_at': 'Today',
          'items': const [],
        };
    expect(Order.fromJson(jsonWith('preparing')).status,
        OrderStatus.preparing);
    expect(Order.fromJson(jsonWith('out_for_delivery')).status,
        OrderStatus.outForDelivery);
  });
}
