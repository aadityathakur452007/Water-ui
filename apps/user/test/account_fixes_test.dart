import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/repositories/address_repository.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/auth_service.dart';

/// Account-fixes gate: address demo persistence round-trip, auth demo
/// gates (incl. role mismatch), and search parser edge cases.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('address demo persistence', () {
    test('fetch includes the seeded home address', () async {
      const repo = AddressRepository();
      final all = await repo.fetchAddresses();
      expect(all.map((a) => a.id), contains('home'));
    });

    test('createAddress round-trips into fetchAddresses', () async {
      const repo = AddressRepository();
      final label = 'Test-Home-${DateTime.now().millisecondsSinceEpoch}';
      final created = await repo.createAddress(
        label: label,
        line: '1 Test Lane',
        city: 'Bhopal',
      );
      expect(created.label, label);
      final all = await repo.fetchAddresses();
      expect(all.map((a) => a.label), contains(label));
      // Returned list is a copy: mutating it must not corrupt the store.
      all.clear();
      expect((await repo.fetchAddresses()).map((a) => a.label),
          contains(label));
    });
  });

  group('auth demo gates', () {
    const auth = AuthService();

    test('demo user login succeeds with user role', () async {
      final user = await auth.login(
        identifier: 'user@demo.local',
        password: 'demo123',
        role: 'user',
      );
      expect(user['role'], 'user');
    });

    test('demo vendor login succeeds with vendor role', () async {
      final user = await auth.login(
        identifier: 'vendor@demo.local',
        password: 'vendor123',
        role: 'vendor',
      );
      expect(user['role'], 'vendor');
    });

    test('wrong demo password is rejected', () async {
      expect(
        () => auth.login(
          identifier: 'user@demo.local',
          password: 'wrong',
          role: 'user',
        ),
        throwsA(isA<AppException>()
            .having((e) => e.code, 'code', 'UNAUTHENTICATED')),
      );
    });

    test('role mismatch is rejected (user creds as vendor)', () async {
      expect(
        () => auth.login(
          identifier: 'user@demo.local',
          password: 'demo123',
          role: 'vendor',
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('demo register returns a user session', () async {
      final user = await auth.register(
        name: 'Test User',
        phone: '9000000000',
        email: 'test@example.com',
        password: 'Test@1234',
      );
      expect(user['role'], 'user');
    });
  });

  group('search parser edge cases', () {
    const products = ProductRepository();

    test('empty and blank queries return the full catalog', () {
      expect(products.search('').length, products.all().length);
      expect(products.search('   ').length, products.all().length);
    });

    test('capacity matches with and without space/case', () {
      expect(products.search('20L').map((p) => p.id), contains('wd-20l'));
      expect(products.search('20 L').map((p) => p.id), contains('wd-20l'));
      expect(products.search('JAR').map((p) => p.id), contains('wd-20l'));
    });

    test('multi-word queries narrow (every word must match)', () {
      final both = products.search('20L jar');
      expect(both.map((p) => p.id), contains('wd-20l'));
      expect(
          both.length, lessThanOrEqualTo(products.search('20L').length));
      expect(products.search('bottle').map((p) => p.id),
          containsAll(['wd-1l-12', 'wd-500ml-12']));
    });

    test('unknown terms return empty, never throw', () {
      expect(products.search('zzz-no-such-water'), isEmpty);
      expect(products.search('  @@  '), isEmpty);
    });

    test('money stays in rupees', () {
      expect(inr(130), '₹130');
      expect(products.byId('wd-20l').priceLabel, '₹60');
    });
  });
}
