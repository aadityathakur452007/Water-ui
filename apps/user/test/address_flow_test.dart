import 'package:flutter_test/flutter_test.dart';
import 'package:shop/config/demo_seed.dart';
import 'package:shop/config/demo_store.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/address_repository.dart';

void main() {
  test('old address rows parse with line fallback (back-compat)', () {
    final a = Address.fromJson({
      'id': '1',
      'label': 'Home',
      'line': '123, Example Colony',
      'city': 'Bhopal',
    });
    expect(a.house, isNull);
    expect(a.pincode, isNull);
    expect(a.lat, isNull);
    expect(a.displayLine, '123, Example Colony');
  });

  test('full address rows parse with extended fields', () {
    final a = Address.fromJson({
      'id': '2',
      'label': 'Home',
      'line': 'legacy line',
      'city': 'Bhopal',
      'house': '123',
      'street': 'Example Colony',
      'area': 'Arera Colony',
      'pincode': '462016',
      'phone': '9000000001',
      'lat': 23.2599,
      'lng': 77.4126,
    });
    expect(a.displayLine, '123, Example Colony, Arera Colony');
    expect(a.pincode, '462016');
    expect(a.lat, 23.2599);
  });

  test('pincode allowlist: 6 digits starting 1-9, empty OK', () {
    expect(validatePincode(null), isNull);
    expect(validatePincode(''), isNull);
    expect(validatePincode('462016'), isNull);
    expect(validatePincode('062016'), isNotNull);
    expect(validatePincode('46201'), isNotNull);
    expect(validatePincode('4620167'), isNotNull);
    expect(validatePincode('abc'), isNotNull);
  });

  test('phone allowlist: 10 digits, empty OK', () {
    expect(validatePhone(null), isNull);
    expect(validatePhone(''), isNull);
    expect(validatePhone('9000000001'), isNull);
    expect(validatePhone('900000001'), isNotNull);
    expect(validatePhone('90000000011'), isNotNull);
    expect(validatePhone('abcdefghij'), isNotNull);
  });

  test('lat/lng range validation, empty OK', () {
    expect(validateLat(''), isNull);
    expect(validateLat('23.2599'), isNull);
    expect(validateLat('-90'), isNull);
    expect(validateLat('90.1'), isNotNull);
    expect(validateLat('abc'), isNotNull);
    expect(validateLng('77.4126'), isNull);
    expect(validateLng('-180'), isNull);
    expect(validateLng('180.5'), isNotNull);
  });

  test('DeliveryAddress region: extended fields with line fallback', () {
    const legacy = DeliveryAddress(label: 'Home', line: 'old line', city: 'X');
    expect(legacy.displayLine, 'old line');
    const full = DeliveryAddress(
      label: 'Home',
      line: 'old line',
      city: 'Bhopal',
      house: '123',
      street: 'Main St',
      area: 'Arera',
      pincode: '462016',
    );
    expect(full.displayLine, '123, Main St, Arera');
    final parsed = DeliveryAddress.fromJson({
      'label': 'Home',
      'line': 'old line',
      'city': 'Bhopal',
      'pincode': '462016',
      'lat': 23.5,
    });
    expect(parsed.pincode, '462016');
    expect(parsed.lat, 23.5);
    expect(parsed.house, isNull);
  });

  test('demo seed address carries the full format', () {
    DemoStore.reset();
    expect(demoAddresses.first['pincode'], '462016');
    final parsed = Address.fromJson(
        Map<String, dynamic>.from(DemoStore.addresses.first));
    expect(parsed.displayLine, isNotEmpty);
  });
}
