import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop/config/demo_store.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/screens/vendor/vendor_order.dart';
import 'package:shop/screens/vendor/vendor_settings_store.dart';
import 'package:shop/services/vendor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.reset();
  });

  group('subscription days', () {
    test('parses days wire key, defaults to empty', () {
      final s = Subscription.fromJson({
        'id': 'SUB-1',
        'product_id': 'wd-20l-jar',
        'quantity': 1,
        'frequency': 'every_day',
        'start_date': '25 September 2026',
        'delivery_time': '8:00 AM',
        'status': 'active',
        'next_delivery': 'Tomorrow',
        'days': 'Mon,Wed,Fri',
      });
      expect(s.days, 'Mon,Wed,Fri');
      expect(s.daysLabel, 'Mon, Wed, Fri');

      final missing = Subscription.fromJson({
        'id': 'SUB-2',
        'product_id': 'wd-20l-jar',
        'quantity': 1,
        'frequency': 'every_day',
        'start_date': 'x',
        'delivery_time': 'y',
        'status': 'active',
        'next_delivery': 'z',
      });
      expect(missing.days, '');
      expect(missing.daysLabel, '');
    });

    test('daysLabel prettifies mixed case/spacing', () {
      const s = Subscription(
        id: 'x',
        productId: 'p',
        productName: 'n',
        quantity: 1,
        frequency: Frequency.everyDay,
        startDate: 'a',
        deliveryTime: 'b',
        status: SubscriptionStatus.active,
        nextDelivery: 'c',
        days: 'mon, WED ,fri',
      );
      expect(s.daysLabel, 'Mon, Wed, Fri');
    });

    test('toJson round-trips days for update paths', () {
      const s = Subscription(
        id: 'x',
        productId: 'wd-20l-jar',
        productName: 'n',
        quantity: 2,
        frequency: Frequency.weekly,
        startDate: 'a',
        deliveryTime: 'b',
        status: SubscriptionStatus.active,
        nextDelivery: 'c',
        days: 'Mon,Wed,Fri',
      );
      expect(s.toJson()['days'], 'Mon,Wed,Fri');
      expect(s.copyWith(days: 'Tue,Thu').days, 'Tue,Thu');
      const empty = Subscription(
        id: 'x',
        productId: 'p',
        productName: 'n',
        quantity: 1,
        frequency: Frequency.everyDay,
        startDate: 'a',
        deliveryTime: 'b',
        status: SubscriptionStatus.active,
        nextDelivery: 'c',
      );
      expect(empty.toJson().containsKey('days'), isFalse);
    });

    test('vendor subscription parses days tolerantly', () {
      final s = VendorSubscription.fromJson({
        'product': {'id': 'p', 'name': 'n'},
        'quantity': 1,
        'frequency': 'every_day',
        'status': 'active',
        'next_delivery': 'x',
        'days': 'Mon,Wed,Fri',
      });
      expect(s.days, 'Mon,Wed,Fri');
      expect(s.daysLabel, 'Mon, Wed, Fri');
      final missing = VendorSubscription.fromJson({
        'quantity': 1,
        'frequency': 'every_day',
        'status': 'active',
        'nextDelivery': 'x',
      });
      expect(missing.days, '');
    });
  });

  group('extended KPI math', () {
    List<VendorOrder> fixture() => [
          VendorOrder(
            id: 'A',
            items: [
              VendorOrderItem(
                  name: 'Refill', qty: 2, price: 28, productId: 'wd-20l-refill'),
            ],
            total: 66,
            addressLabel: 'Home',
            addressLine: 'l',
            addressCity: 'c',
            slot: 'Today',
            status: 'delivered',
            type: 'one-time',
            createdAt: 'Today',
            customerName: 'Ann',
            customerEmail: 'ann@x.local',
          ),
          VendorOrder(
            id: 'B',
            items: [
              VendorOrderItem(
                  name: 'Jar', qty: 1, price: 30, productId: 'wd-20l-jar'),
            ],
            total: 40,
            addressLabel: 'Home',
            addressLine: 'l',
            addressCity: 'c',
            slot: 'x',
            status: 'delivered',
            type: 'one-time',
            createdAt: '20 Sept',
            customerName: 'Bob',
            customerEmail: 'bob@x.local',
          ),
          VendorOrder(
            id: 'C',
            items: [
              VendorOrderItem(
                  name: 'Jar', qty: 1, price: 30, productId: 'wd-20l-jar'),
            ],
            total: 40,
            addressLabel: 'Home',
            addressLine: 'l',
            addressCity: 'c',
            slot: 'x',
            status: 'cancelled',
            type: 'one-time',
            createdAt: '9 Sept',
            customerName: 'Ann',
            customerEmail: 'ann@x.local',
          ),
          VendorOrder(
            id: 'D',
            items: [
              VendorOrderItem(
                  name: 'Jar', qty: 1, price: 30, productId: 'wd-20l-jar'),
            ],
            total: 40,
            addressLabel: 'Home',
            addressLine: 'l',
            addressCity: 'c',
            slot: 'x',
            status: 'scheduled',
            type: 'regular',
            createdAt: 'Today',
            customerName: 'Cara',
            customerPhone: '9000000009',
          ),
        ];

    test('week/cancelled/AOV/mix derived honestly', () {
      final now = DateTime(2026, 9, 27);
      const base = VendorKpis(
        todayDeliveries: 1,
        todayRevenue: 66,
        activeSubscriptions: 2,
        pendingOrders: 1,
      );
      final k = withExtendedKpis(base, fixture(), now: now);
      // Only A (Today) is within 7 days of 27 Sept; B (20 Sept) is
      // exactly 7 days out (<7 boundary) and C (9 Sept) is older.
      expect(k.weekCompletions, 1);
      expect(k.cancelledCount, 1);
      // Distinct: ann, bob, cara(phone fallback).
      expect(k.customerCount, 3);
      // This week: ann (A Today) + cara (D Today) = 2.
      expect(k.newCustomersWeek, 2);
      // AOV over non-cancelled: (66+40+40)/3 = 146/3.
      expect(k.aov, closeTo(146 / 3, 0.001));
      expect(k.refillQty, 2);
      expect(k.jarQty, 3);
      // Base counters preserved.
      expect(k.todayDeliveries, 1);
      expect(k.todayRevenue, 66);
    });

    test('isWithinWeek never fakes unparseable dates', () {
      final now = DateTime(2026, 9, 27);
      expect(isWithinWeek('Today', now: now), isTrue);
      expect(isWithinWeek('20 Sept', now: now), isFalse);
      expect(isWithinWeek('21 Sept', now: now), isTrue);
      expect(isWithinWeek('9 Sept', now: now), isFalse);
      expect(isWithinWeek('not-a-date', now: now), isFalse);
      expect(isWithinWeek('', now: now), isFalse);
    });

    test('VendorKpis new fields default to 0 (old call sites compile)', () {
      const k = VendorKpis(
        todayDeliveries: 1,
        todayRevenue: 2,
        activeSubscriptions: 3,
        pendingOrders: 4,
      );
      expect(k.weekCompletions, 0);
      expect(k.cancelledCount, 0);
      expect(k.customerCount, 0);
      expect(k.newCustomersWeek, 0);
      expect(k.aov, 0);
      expect(k.refillQty, 0);
      expect(k.jarQty, 0);
      expect(k.refillShare, 0);
    });

    test('vendor order keeps days/frequency empty by default (no fake data)',
        () {
      final o = VendorOrder.fromJson({
        'id': 'WD-1',
        'items': [
          {
            'productId': 'wd-20l-jar',
            'name': 'Jar',
            'qty': 1,
            'price': 30
          },
        ],
        'total': 40,
        'address': {'label': 'H', 'line': 'l', 'city': 'c'},
        'slot': 's',
        'status': 'scheduled',
        'type': 'regular',
        'created_at': 'Today',
      });
      expect(o.items.first.productId, 'wd-20l-jar');
      expect(o.days, '');
      expect(o.daysLabel, '');
    });
  });

  group('vendor settings persist round-trip', () {
    test('profile/notifs/slots/days survive reload', () async {
      const store = VendorSettingsStore();
      await store.saveProfile(
          name: 'Shop', phone: '9000000001', address: 'Main Rd', hours: '8-8');
      await store.saveNotif('summary', true);
      await store.saveSlot('Morning \u2022 8:00 AM', false);
      await store.saveDay('Sun', false);

      final profile = await store.loadProfile();
      expect(profile['name'], 'Shop');
      expect(profile['hours'], '8-8');
      final notifs = await store.loadNotifs();
      expect(notifs['summary'], isTrue);
      final slots = await store.loadSlots();
      expect(slots['Morning \u2022 8:00 AM'], isFalse);
      final days = await store.loadDays();
      expect(days['Sun'], isFalse);
      expect(days['Mon'], isTrue);
    });
  });
}
