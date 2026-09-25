import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/vendor_service.dart';

void main() {
  test('status=all is omitted from the vendor orders query', () {
    expect(ordersQuery('all'), isNull);
    expect(ordersQuery(null), isNull);
    expect(ordersQuery(''), isNull);
    expect(ordersQuery('scheduled'), {'status': 'scheduled'});
  });

  test('demo treats status=all like no filter', () async {
    const service = VendorService();
    final all = await service.fetchOrders(status: 'all');
    final unfiltered = await service.fetchOrders();
    expect(all.map((o) => o.id), unfiltered.map((o) => o.id));
  });

  test('frequency once_a_week round-trips without silent rewrite', () {
    expect(parseFrequency('once_a_week'), Frequency.onceAWeek);
    expect(frequencyToWire(Frequency.onceAWeek), 'once_a_week');
    expect(parseFrequency('weekly'), Frequency.weekly);
    expect(frequencyToWire(Frequency.weekly), 'weekly');
  });

  test('vendor subscription parses nested product + humanized frequency',
      () {
    final s = VendorSubscription.fromJson({
      'product': {'id': 'wd-20l', 'name': '20L Drinking Water Jar'},
      'quantity': 2,
      'frequency': 'every_day',
      'status': 'active',
      'next_delivery': 'Tomorrow • 8:00 AM',
    });
    expect(s.productId, 'wd-20l');
    expect(s.productName, '20L Drinking Water Jar');
    expect(s.frequency, 'Every day');
  });

  test('demo rejects illegal status jumps like the live 409', () {
    const service = VendorService();
    // WD-00124 is scheduled: jumping straight to delivered is illegal.
    expect(
      service.updateStatus('WD-00124', 'delivered'),
      throwsA(isA<AppException>()),
    );
  });

  test('demo allows the legal next step and cancel', () async {
    const service = VendorService();
    // WD-00122 is preparing → out_for_delivery is the legal next step.
    await service.updateStatus('WD-00122', 'out_for_delivery');
    // WD-00119 is scheduled: cancel is always legal from non-final states.
    await service.updateStatus('WD-00119', 'cancelled');
  });
}
