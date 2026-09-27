import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/repositories/subscription_repository.dart';
import 'package:shop/screens/order/views/orders_screen.dart';
import 'package:shop/screens/subscription/views/subscription_config_screen.dart';

/// Water-experience gate: custom-days summary/wire string, order
/// thumbnail fallback, refill↔jar cross-sell mapping.
void main() {
  group('custom-days schedule', () {
    test('wire string is ordered Mon–Sun regardless of tap order', () {
      expect(
        daysWireString(
            Frequency.specificDays, ['Fri', 'Mon', 'Wed']),
        'Mon,Wed,Fri',
      );
    });

    test('wire string is empty for other frequencies and empty picks', () {
      expect(daysWireString(Frequency.everyDay, ['Mon']), '');
      expect(
          daysWireString(Frequency.alternateDays, ['Mon']), '');
      expect(daysWireString(Frequency.weekly, ['Mon']), '');
      expect(daysWireString(Frequency.specificDays, []), '');
      expect(daysWireString(Frequency.specificDays, ['Tue']), 'Tue');
    });

    test('summary matches "Every Mon, Wed, Fri · from 12 Jun · 8:00 AM"',
        () {
      expect(
        scheduleSummary(
          frequency: Frequency.specificDays,
          days: const ['Wed', 'Fri', 'Mon'],
          startLabel: '12 Jun',
          timeLabel: '8:00 AM',
        ),
        'Every Mon, Wed, Fri · from 12 Jun · 8:00 AM',
      );
    });

    test('summary falls back honestly without days', () {
      expect(
        scheduleSummary(
          frequency: Frequency.specificDays,
          days: const [],
          startLabel: '12 Jun',
          timeLabel: '8:00 AM',
        ),
        'Specific days · from 12 Jun · 8:00 AM',
      );
      expect(
        scheduleSummary(
          frequency: Frequency.everyDay,
          days: const [],
          startLabel: '12 Jun',
          timeLabel: '8:00 AM',
        ),
        'Every day · from 12 Jun · 8:00 AM',
      );
    });

    test('days json reads defensively (missing key → empty)', () {
      expect(subscriptionDaysFromJson({'days': 'Mon,Wed'}), 'Mon,Wed');
      expect(subscriptionDaysFromJson({}), '');
    });
  });

  group('order thumbnails', () {
    test('tryById resolves known ids and nulls unknown ones', () {
      const repo = ProductRepository();
      expect(repo.tryById('wd-20l-refill')!.id, 'wd-20l-refill');
      expect(repo.tryById('no-such-product'), isNull);
      expect(repo.tryById(''), isNull);
    });

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
  });

  group('refill↔jar cross-sell', () {
    const repo = ProductRepository();

    test('refill detail links the jar', () {
      expect(
          repo.crossSellSibling('wd-20l-refill')!.id, 'wd-20l-jar');
    });

    test('jar detail links the refill', () {
      expect(
          repo.crossSellSibling('wd-20l-jar')!.id, 'wd-20l-refill');
    });

    test('1L (unavailable) and unknown ids get no cross-sell', () {
      expect(repo.crossSellSibling('wd-1l'), isNull);
      expect(repo.crossSellSibling('no-such-product'), isNull);
      expect(repo.crossSellSibling(''), isNull);
    });
  });
}
