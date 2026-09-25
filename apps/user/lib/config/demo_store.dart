import 'demo_seed.dart';

/// In-memory demo backend (demo mode only). Single source of truth for
/// demo users, addresses, orders and subscriptions — both the user-side
/// repositories and the vendor-side service read/write the same lists,
/// so a user-placed order appears in the vendor fetch and a vendor status
/// advance reflects in the user fetch after refresh.
///
/// Live paths never touch this file. Call [reset] in tests to restore
/// the seed.
class DemoStore {
  DemoStore._();

  static List<Map<String, dynamic>> _users = [];
  static List<Map<String, dynamic>> _addresses = [];
  static List<Map<String, dynamic>> _orders = [];
  static List<Map<String, dynamic>> _userSubs = [];
  static List<Map<String, dynamic>> _vendorSubs = [];
  static int _orderCounter = 125;
  static bool _seeded = false;

  static void _ensureSeeded() {
    if (!_seeded) reset();
  }

  /// Restores every list to a deep copy of [demo_seed.dart].
  static void reset() {
    _users = [for (final u in demoUsers) Map<String, dynamic>.from(u)];
    _addresses = [
      for (final a in demoAddresses) Map<String, dynamic>.from(a),
    ];
    _orders = [for (final o in demoOrders) _copyOrder(o)];
    _userSubs = [
      for (final s in demoUserSubscriptions) Map<String, dynamic>.from(s),
    ];
    _vendorSubs = [
      for (final s in demoVendorSubscriptions) Map<String, dynamic>.from(s),
    ];
    _orderCounter = 125;
    _seeded = true;
  }

  static Map<String, dynamic> _copyOrder(Map<String, dynamic> o) {
    final copy = Map<String, dynamic>.from(o);
    final items = o['items'];
    if (items is List) {
      copy['items'] = [
        for (final e in items)
          e is Map ? Map<String, dynamic>.from(e) : e,
      ];
    }
    final address = o['address'];
    if (address is Map) {
      copy['address'] = Map<String, dynamic>.from(address);
    }
    final customer = o['customer'];
    if (customer is Map) {
      copy['customer'] = Map<String, dynamic>.from(customer);
    }
    return copy;
  }

  static List<Map<String, dynamic>> get users {
    _ensureSeeded();
    return _users;
  }

  static List<Map<String, dynamic>> get addresses {
    _ensureSeeded();
    return _addresses;
  }

  static List<Map<String, dynamic>> get orders {
    _ensureSeeded();
    return _orders;
  }

  static List<Map<String, dynamic>> get userSubscriptions {
    _ensureSeeded();
    return _userSubs;
  }

  static List<Map<String, dynamic>> get vendorSubscriptions {
    _ensureSeeded();
    return _vendorSubs;
  }

  /// Next `WD-` counter value for user-placed demo orders.
  static int nextOrderNumber() {
    _ensureSeeded();
    return _orderCounter++;
  }
}
