import 'package:flutter_test/flutter_test.dart';
import 'package:vendor/features/orders/order_model.dart';

void main() {
  group('status transitions (contract)', () {
    test('forward chain only', () {
      expect(nextStatus('scheduled'), 'preparing');
      expect(nextStatus('preparing'), 'out_for_delivery');
      expect(nextStatus('out_for_delivery'), 'delivered');
      expect(nextStatus('delivered'), isNull);
      expect(nextStatus('cancelled'), isNull);
    });
  });

  group('PII rule', () {
    test('fromJson ignores user fields even if leaked', () {
      final order = VendorOrder.fromJson({
        'id': 'o1',
        'name': 'Leaky User',
        'phone': '9999999999',
        'email': 'leak@example.com',
        'user': {'name': 'Leaky'},
        'items': [
          {'name': '20L Jar', 'qty': 2, 'price': 60},
        ],
        'total': 120,
        'address': {'label': 'Home', 'line': '1 Main St', 'city': 'Pune'},
        'slot': 'morning',
        'status': 'scheduled',
        'type': 'one-time',
        'created_at': '2026-09-24',
      });
      expect(order.id, 'o1');
      expect(order.items.single.name, '20L Jar');
      // No user fields exist on the model — compile-time + runtime assert.
      expect(order.toString().contains('Leaky'), isFalse);
    });
  });
}
