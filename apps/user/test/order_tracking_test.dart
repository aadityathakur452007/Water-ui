import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/components/order_process.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/screens/order/views/order_tracking_screen.dart';

/// Slice 3 gate: tracking renders the map pin when coords exist, stays
/// honest (no 0,0 pin) when they don't, and the status→timeline mapping
/// covers every [OrderStatus].
Order _order({
  double? lat,
  double? lng,
  OrderStatus status = OrderStatus.outForDelivery,
}) {
  return Order(
    id: 'WD-42',
    items: const [
      OrderItem(
        productId: 'wd-20l-refill',
        name: '20L Water Refill (Own Container)',
        qty: 1,
        price: 28,
      ),
    ],
    address: DeliveryAddress(
      label: 'Home',
      line: '123, Example Colony',
      city: 'Bhopal',
      lat: lat,
      lng: lng,
    ),
    orderType: OrderType.oneTime,
    status: status,
    totalAmount: 38,
    deliverySlot: 'Today · 8:00 AM',
    createdAt: 'Today',
  );
}

void main() {
  group('orderTrackingProgress mapping', () {
    test('delivered marks every step done', () {
      final p = orderTrackingProgress(OrderStatus.delivered);
      expect(p.deliveredStatus, OrderProcessStatus.done);
      expect(p.shippedStatus, OrderProcessStatus.done);
      expect(p.isCanceled, isFalse);
    });

    test('out-for-delivery is mid-shipment', () {
      final p = orderTrackingProgress(OrderStatus.outForDelivery);
      expect(p.packedStatus, OrderProcessStatus.done);
      expect(p.shippedStatus, OrderProcessStatus.processing);
      expect(p.deliveredStatus, OrderProcessStatus.notDoneYeat);
    });

    test('scheduled keeps later steps pending', () {
      final p = orderTrackingProgress(OrderStatus.scheduled);
      expect(p.orderStatus, OrderProcessStatus.done);
      expect(p.processingStatus, OrderProcessStatus.processing);
      expect(p.packedStatus, OrderProcessStatus.notDoneYeat);
    });

    test('cancelled renders the canceled branch', () {
      final p = orderTrackingProgress(OrderStatus.cancelled);
      expect(p.isCanceled, isTrue);
    });

    test('not-delivered renders the canceled branch too', () {
      final p = orderTrackingProgress(OrderStatus.notDelivered);
      expect(p.isCanceled, isTrue);
    });
  });

  group('OrderTrackingScreen', () {
    testWidgets('shows map pin + coords when they exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderTrackingScreen(
            order: _order(lat: 23.2599, lng: 77.4126),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Track order #WD-42'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.textContaining('23.2599'), findsOneWidget);
      expect(find.textContaining('77.4126'), findsOneWidget);
      expect(find.byType(OrderProgress), findsOneWidget);
      expect(
        find.text('No location saved for this order'),
        findsNothing,
      );
    });

    testWidgets('honest empty state when coords are null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OrderTrackingScreen(order: _order())),
      );
      await tester.pump();

      expect(
        find.text('No location saved for this order'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.location_on), findsNothing);
      // Timeline still renders — status is known even without a pin.
      expect(find.byType(OrderProgress), findsOneWidget);
    });
  });
}
