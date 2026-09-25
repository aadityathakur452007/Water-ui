import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';
import 'package:shop/config/demo_store.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/screens/vendor/vendor_dashboard_screen.dart';
import 'package:shop/services/vendor_service.dart';
import 'package:shop/theme/water_ui_theme.dart';

/// Crash-fix gate: the dashboard renders its KPI labels under the shared
/// root [UiTheme] (main.dart provides the same ancestor in production).
/// Without the ancestor, `UiTheme.of` throws (`widget!.data`) and the
/// release screen blanks.
void main() {
  setUp(DemoStore.reset);

  testWidgets('dashboard renders KPI labels under the shared UiTheme',
      (tester) async {
    await tester.pumpWidget(
      UiTheme(
        data: waterUiThemeData(),
        child: const MaterialApp(
          home: VendorDashboardScreen(service: VendorService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today deliveries'), findsOneWidget);
    expect(find.text('Today revenue'), findsOneWidget);
    expect(find.text('Active subscriptions'), findsOneWidget);
    expect(find.text('Pending orders'), findsOneWidget);
  });

  test('demo cross-role sync: user order → vendor → vendor advance → user',
      () async {
    const userRepo = OrderRepository();
    const vendor = VendorService();

    final created = await userRepo.createOrder(
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

    final vendorOrders = await vendor.fetchOrders();
    expect(vendorOrders.map((o) => o.id), contains(created.id));
    final vendorRow =
        vendorOrders.firstWhere((o) => o.id == created.id);
    expect(vendorRow.customerName, isNotEmpty);

    await vendor.updateStatus(created.id, 'preparing');

    final userAfter = await userRepo.fetchOrders();
    final match = userAfter.firstWhere((o) => o.id == created.id);
    expect(match.status, OrderStatus.preparing);
  });
}
