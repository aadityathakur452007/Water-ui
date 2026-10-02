import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop/screens/vendor/vendor_settings_screen.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/vendor_service.dart';

/// Slice 1 gate: profile/ticket model parsing, validation mapping, and
/// the demo dirty/save flow (save-then-toast, device-local intact).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('VendorProfile model', () {
    test('parses tolerantly, missing keys default to empty', () {
      final p = VendorProfile.fromJson({'name': 'Shodasha'});
      expect(p.name, 'Shodasha');
      expect(p.phone, '');
      expect(p.address, '');
      expect(p.hours, '');
    });

    test('toJson round-trips all four fields', () {
      const p = VendorProfile(
          name: 'n', phone: 'p', address: 'a', hours: 'h');
      final back = VendorProfile.fromJson(
          Map<String, dynamic>.from(p.toJson()));
      expect(back.toJson(), p.toJson());
    });

    test('copyWith replaces only given fields', () {
      const p = VendorProfile(name: 'n', phone: 'p');
      final c = p.copyWith(phone: 'q');
      expect(c.name, 'n');
      expect(c.phone, 'q');
    });
  });

  group('validateVendorProfile mapping', () {
    test('empty name maps to the name field', () {
      final errors =
          validateVendorProfile(name: '  ', phone: '9000000001');
      expect(errors['name'], isNotEmpty);
      expect(errors.containsKey('phone'), isFalse);
    });

    test('short phone maps to the phone field', () {
      final errors =
          validateVendorProfile(name: 'Shop', phone: '123');
      expect(errors['phone'], isNotEmpty);
      expect(errors.containsKey('name'), isFalse);
    });

    test('valid profile yields no errors', () {
      expect(
          validateVendorProfile(
              name: 'Shodasha', phone: '+91 90000 00001'),
          isEmpty);
    });
  });

  group('parseVendorSlots', () {
    test('list shape maps slot_key/enabled', () {
      expect(
          parseVendorSlots({
            'slots': [
              {'slot_key': 'Morning', 'enabled': true},
              {'slot_key': 'Noon', 'enabled': false},
            ]
          }),
          {'Morning': true, 'Noon': false});
    });

    test('map shape passes booleans through', () {
      expect(parseVendorSlots({'Morning': true, 'Noon': false}),
          {'Morning': true, 'Noon': false});
    });

    test('unknown shape yields empty, never fake state', () {
      expect(parseVendorSlots(null), isEmpty);
      expect(parseVendorSlots('nope'), isEmpty);
    });
  });

  group('VendorTicket model', () {
    test('list row parses without replies', () {
      final t = VendorTicket.fromJson({
        'id': 'T-1',
        'subject': 'Payout missing',
        'status': 'open',
        'created_at': '2026-10-02',
      });
      expect(t.id, 'T-1');
      expect(t.subject, 'Payout missing');
      expect(t.replies, isEmpty);
    });

    test('detail parses the reply thread', () {
      final t = VendorTicket.fromJson({
        'id': 'T-2',
        'subject': 's',
        'status': 'open',
        'replies': [
          {
            'id': 'R-1',
            'ticket_id': 'T-2',
            'author': 'vendor',
            'body': 'hello',
            'created_at': '2026-10-02',
          },
        ],
      });
      expect(t.replies.length, 1);
      expect(t.replies.first.body, 'hello');
      expect(t.replies.first.author, 'vendor');
    });
  });

  group('demo service branches stay honest', () {
    test('fetchProfile/fetchTickets return empty, no fake rows',
        () async {
      const service = VendorService();
      expect((await service.fetchProfile()).toJson(),
          VendorProfile.empty.toJson());
      expect(await service.fetchTickets(), isEmpty);
    });

    test('openTicket in demo refuses honestly', () {
      const service = VendorService();
      expect(
        service.openTicket(subject: 's', message: 'm'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('demo dirty/save flow (device-local intact)', () {
    testWidgets('save button enabled, save shows device toast',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VendorSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Demo keeps the always-enabled save (live gates on dirty).
      final save = find.text('Save profile');
      expect(save, findsOneWidget);
      expect(tester.widget<ElevatedButton>(
          find.ancestor(of: save, matching: find.byType(ElevatedButton))),
          isA<ElevatedButton>());

      await tester.enterText(
          find.byType(TextField).first, 'Shodasha');
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Business profile saved on this device.'),
          findsOneWidget);
    });

    testWidgets('support section links to the tickets route',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: VendorSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Support tickets'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Support tickets'), findsOneWidget);
    });
  });
}
