import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/screens/order/views/order_grouping.dart';
import 'package:shop/screens/order/views/orders_screen.dart';

Order _order(String id, OrderStatus status,
    {OrderType type = OrderType.oneTime}) {
  return Order(
    id: id,
    items: const [
      OrderItem(
        productId: 'wd-20l-refill',
        name: '20L Water Refill (Own Container)',
        qty: 2,
        price: 28,
      ),
    ],
    address: defaultAddress,
    orderType: type,
    status: status,
    totalAmount: 66,
    deliverySlot: 'Today • 8:00 AM',
    createdAt: 'Today',
  );
}

void main() {
  group('grouping buckets', () {
    test('active/delivered/cancelled split on fixture', () {
      final all = [
        _order('A1', OrderStatus.scheduled),
        _order('A2', OrderStatus.preparing),
        _order('A3', OrderStatus.outForDelivery),
        _order('A4', OrderStatus.active),
        _order('D1', OrderStatus.delivered),
        _order('C1', OrderStatus.cancelled),
        _order('C2', OrderStatus.notDelivered),
      ];
      final grouped = splitGrouped(all);
      expect(
        grouped.active.map((o) => o.id),
        containsAll(['A1', 'A2', 'A3', 'A4']),
      );
      expect(grouped.active.length, 4);
      expect(grouped.delivered.map((o) => o.id), ['D1']);
      expect(
        grouped.cancelled.map((o) => o.id),
        containsAll(['C1', 'C2']),
      );
      expect(grouped.cancelled.length, 2);
    });

    test('empty fixture yields empty buckets', () {
      final grouped = splitGrouped(const []);
      expect(grouped.active, isEmpty);
      expect(grouped.delivered, isEmpty);
      expect(grouped.cancelled, isEmpty);
    });
  });

  group('recurrence line', () {
    test('includes frequency + days + continues this week', () {
      const sub = Subscription(
        id: 'SUB-1',
        productId: 'wd-20l-jar',
        productName: '20L Jar with Container',
        quantity: 2,
        frequency: Frequency.specificDays,
        startDate: '25 September 2026',
        deliveryTime: '8:00 AM',
        status: SubscriptionStatus.active,
        nextDelivery: 'Tomorrow • 8:00 AM',
        days: 'Mon,Wed,Fri',
      );
      final line = subscriptionRecurrenceLine(sub);
      expect(line, contains(sub.frequencyLabel));
      expect(line, contains(sub.daysLabel));
      expect(line, contains('continues this week'));
      expect(line,
          '${sub.frequencyLabel} · ${sub.daysLabel} · continues this week');
    });

    test('no days falls back honestly', () {
      const sub = Subscription(
        id: 'SUB-2',
        productId: 'wd-20l-jar',
        productName: '20L Jar with Container',
        quantity: 1,
        frequency: Frequency.everyDay,
        startDate: '',
        deliveryTime: '8:00 AM',
        status: SubscriptionStatus.active,
        nextDelivery: 'Tomorrow • 8:00 AM',
      );
      expect(subscriptionRecurrenceLine(sub),
          '${sub.frequencyLabel} · continues this week');
    });

    test('row status maps paused/skipped/active', () {
      const paused = Subscription(
        id: 'P',
        productId: 'wd-20l-jar',
        productName: 'x',
        quantity: 1,
        frequency: Frequency.everyDay,
        startDate: '',
        deliveryTime: '',
        status: SubscriptionStatus.paused,
        nextDelivery: '',
      );
      const skipped = Subscription(
        id: 'S',
        productId: 'wd-20l-jar',
        productName: 'x',
        quantity: 1,
        frequency: Frequency.everyDay,
        startDate: '',
        deliveryTime: '',
        status: SubscriptionStatus.active,
        nextDelivery: '',
        skipNext: true,
      );
      const active = Subscription(
        id: 'A',
        productId: 'wd-20l-jar',
        productName: 'x',
        quantity: 1,
        frequency: Frequency.everyDay,
        startDate: '',
        deliveryTime: '',
        status: SubscriptionStatus.active,
        nextDelivery: '',
      );
      expect(subscriptionRowStatus(paused), 'Paused');
      expect(subscriptionRowStatus(skipped), 'Next skipped');
      expect(subscriptionRowStatus(active), 'Active');
    });
  });

  group('reorder', () {
    test('one-time past rows allow reorder, regular/active do not', () {
      expect(canReorder(_order('D', OrderStatus.delivered)), isTrue);
      expect(canReorder(_order('C', OrderStatus.cancelled)), isTrue);
      expect(canReorder(_order('N', OrderStatus.notDelivered)), isTrue);
      expect(
        canReorder(_order('D', OrderStatus.delivered,
            type: OrderType.regular)),
        isFalse,
      );
      expect(canReorder(_order('A', OrderStatus.scheduled)), isFalse);
    });

    test('reorder seeds cart items (mirrors CartScreen mapping)', () {
      const order = Order(
        id: 'WD-00118',
        items: [
          OrderItem(
              productId: 'wd-20l-refill',
              name: '20L Water Refill (Own Container)',
              qty: 2,
              price: 28),
          OrderItem(
              productId: 'wd-20l-jar',
              name: '20L Jar with Container',
              qty: 1,
              price: 30),
        ],
        address: defaultAddress,
        orderType: OrderType.oneTime,
        status: OrderStatus.delivered,
        totalAmount: 96,
        deliverySlot: 'Today • 8:00 AM',
        createdAt: 'Today',
      );
      const products = ProductRepository();
      // Same mapping CartScreen uses for `arguments is Order`.
      final cartItems = order.items
          .map((e) =>
              CartItem(product: products.byId(e.productId), qty: e.qty))
          .toList();
      expect(cartItems.length, order.items.length);
      expect(cartItems[0].product.id, 'wd-20l-refill');
      expect(cartItems[0].qty, 2);
      expect(cartItems[1].product.id, 'wd-20l-jar');
      expect(cartItems[1].qty, 1);
    });
  });

  group('thumbnails', () {
    testWidgets('unknown productId renders placeholder, no throw',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderItemThumbnail(productId: 'no-such-product'),
          ),
        ),
      );
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('known productId renders image, no placeholder',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderItemThumbnail(productId: 'wd-20l-refill'),
          ),
        ),
      );
      expect(find.byIcon(Icons.water_drop_outlined), findsNothing);
    });
  });
}
