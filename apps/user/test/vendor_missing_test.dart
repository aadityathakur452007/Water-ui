import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/route/router.dart';
import 'package:shop/screens/vendor/vendor_customers_screen.dart';
import 'package:shop/screens/vendor/vendor_earnings_screen.dart';
import 'package:shop/screens/vendor/vendor_order.dart';
import 'package:shop/services/vendor_service.dart';

/// Agent C gate: customer grouping mirrors withExtendedKpis, earnings math
/// is exact, and the four new vendor routes resolve to their screens.
VendorOrder _order({
  required String id,
  required num total,
  required String status,
  String createdAt = 'Today',
  String name = '',
  String phone = '',
  String email = '',
}) =>
    VendorOrder.fromJson({
      'id': id,
      'type': 'one-time',
      'status': status,
      'total': total,
      'slot': 'Today • 8:00 AM',
      'created_at': createdAt,
      'items': [
        {
          'productId': 'wd-20l-refill',
          'name': '20L Water Refill (Own Container)',
          'qty': 1,
          'price': 28,
        },
      ],
      'address': {'label': 'Home', 'line': 'x', 'city': 'Bhopal'},
      'customer': {'name': name, 'phone': phone, 'email': email},
    });

List<VendorOrder> _orders() => [
      _order(
          id: 'WD-1',
          total: 100,
          status: 'delivered',
          name: 'Asha',
          phone: '9000000001',
          email: 'Asha@demo.local'),
      _order(
          id: 'WD-2',
          total: 50,
          status: 'scheduled',
          name: 'Asha',
          phone: '9000000001',
          email: 'asha@demo.local'),
      _order(
          id: 'WD-3',
          total: 70,
          status: 'delivered',
          createdAt: '19 Sept',
          name: 'Ravi',
          phone: '9000000002'),
      _order(id: 'WD-4', total: 40, status: 'cancelled', name: 'NoMail'),
      _order(id: 'WD-5', total: 30, status: 'delivered'),
    ];

void main() {
  test('grouping key matches withExtendedKpis (email > phone > name)', () {
    // Email case-insensitive: WD-1 + WD-2 share one bucket.
    expect(
        vendorCustomerKey(_orders()[0]), vendorCustomerKey(_orders()[1]));
    // Phone fallback when email empty.
    expect(vendorCustomerKey(_orders()[2]), 'p:9000000002');
    // Name fallback when email+phone empty.
    expect(vendorCustomerKey(_orders()[3]), 'n:nomail');
    // Rows without any customer field are skipped by grouping.
    final groups = groupVendorCustomers(_orders());
    expect(groups.length, 3);
    expect(groups.map((g) => g.key), contains('e:asha@demo.local'));
  });

  test('grouping count agrees with withExtendedKpis customerCount', () {
    final orders = _orders();
    final groups = groupVendorCustomers(orders);
    final base = withExtendedKpis(
      const VendorKpis(
          todayDeliveries: 0,
          todayRevenue: 0,
          activeSubscriptions: 0,
          pendingOrders: 0),
      orders,
    );
    expect(base.customerCount, groups.length);
  });

  test('search filters on name/phone/email, empty query returns all', () {
    final groups = groupVendorCustomers(_orders());
    expect(filterVendorCustomers(groups, '').length, groups.length);
    expect(filterVendorCustomers(groups, 'asha').length, 1);
    expect(filterVendorCustomers(groups, '9000000002').length, 1);
    expect(filterVendorCustomers(groups, 'ASHa@DEMO').length, 1);
    expect(filterVendorCustomers(groups, 'nobody'), isEmpty);
  });

  test('earnings math: gross/AOV/today/week exclude cancelled', () {
    final ref = DateTime(2026, 9, 27);
    final orders = [
      _order(
          id: 'W-1',
          total: 100,
          status: 'delivered',
          createdAt: 'Today',
          name: 'A'),
      _order(
          id: 'W-2',
          total: 60,
          status: 'scheduled',
          createdAt: '2026-09-27',
          name: 'B'),
      _order(
          id: 'W-3',
          total: 70,
          status: 'delivered',
          createdAt: '2026-09-20',
          name: 'C'),
      _order(
          id: 'W-4', total: 40, status: 'cancelled', createdAt: 'Today'),
    ];
    final s = summarizeVendorEarnings(orders, now: ref);
    expect(s.grossRevenue, 230);
    expect(s.billableCount, 3);
    expect(s.cancelledCount, 1);
    expect(s.aov, 230 / 3);
    expect(s.todayRevenue, 160);
    expect(s.todayCount, 2);
    // 2026-09-20 is exactly 7 days back: inside isWithinWeek (< 7)? no —
    // diff is 7, so week holds only the two 09-27 rows.
    expect(s.weekRevenue, 160);
    expect(s.weekCount, 2);
    expect(s.feeTotal, 3 * Cart.deliveryFee);
    expect(s.netRevenue, 230 - 3 * Cart.deliveryFee);
  });

  test('earnings empty list is zero, not NaN', () {
    final s = summarizeVendorEarnings(const []);
    expect(s.grossRevenue, 0);
    expect(s.aov, 0);
    expect(s.feeTotal, 0);
    expect(s.netRevenue, 0);
  });

  test('route constants are distinct deeplink names', () {
    final routes = {
      vendorCustomersScreenRoute,
      vendorCustomerDetailScreenRoute,
      vendorEarningsScreenRoute,
      vendorInventoryScreenRoute,
    };
    expect(routes.length, 4);
    for (final r in routes) {
      expect(r, isNotEmpty);
    }
  });

  testWidgets('vendor_customers route resolves to the customers screen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: generateRoute,
        initialRoute: vendorCustomersScreenRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Customers'), findsWidgets);
    expect(find.byType(VendorCustomersScreen), findsOneWidget);
  });

  testWidgets('vendor_earnings route resolves to the earnings screen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: generateRoute,
        initialRoute: vendorEarningsScreenRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VendorEarningsScreen), findsOneWidget);
    expect(find.text('Gross revenue'), findsOneWidget);
  });

  testWidgets('vendor_inventory route resolves to the inventory screen',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: generateRoute,
        initialRoute: vendorInventoryScreenRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Inventory'), findsWidgets);
    expect(find.text('In stock'), findsWidgets);
  });

  test('vendor_customer_detail route resolves with arguments', () {
    final customer = groupVendorCustomers(_orders()).first;
    final route = generateRoute(const RouteSettings(
        name: vendorCustomerDetailScreenRoute));
    expect(route, isA<MaterialPageRoute>());
    final withArgs = generateRoute(RouteSettings(
        name: vendorCustomerDetailScreenRoute, arguments: customer));
    expect(withArgs, isA<MaterialPageRoute>());
  });
}
