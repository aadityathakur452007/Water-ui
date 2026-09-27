import '../config/app_config.dart';
import '../config/demo_store.dart';
import '../screens/vendor/vendor_order.dart';
import 'api_client.dart';
import 'session_store.dart';

/// Turns a wire enum (`every_day`) into a display label (`Every day`).
/// Never surfaces raw wire values in the UI.
String humanizeFrequency(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Query for `GET /api/vendor/orders`: 'all'/empty means "no filter"
/// (the backend has no `all` status — sending `?status=all` returns nothing).
Map<String, String>? ordersQuery(String? status) =>
    (status == null || status.isEmpty || status == 'all')
        ? null
        : {'status': status};

class VendorSubscription {
  final String productId;
  final String productName;
  final int quantity;
  final String frequency;
  final String status;
  final String nextDelivery;
  final String days;

  const VendorSubscription({
    this.productId = '',
    this.productName = '',
    required this.quantity,
    required this.frequency,
    required this.status,
    required this.nextDelivery,
    this.days = '',
  });

  factory VendorSubscription.fromJson(Map<String, dynamic> json) {
    // Live rows nest the product (`product: {id, name}`); user rows use
    // flat `product_id`/`product_name`. Accept both, never user PII.
    // `days` is the optional subscription days wire key (e.g. "Mon,Wed,Fri").
    final product = json['product'];
    final Map<String, dynamic> p =
        product is Map<String, dynamic> ? product : const {};
    return VendorSubscription(
      productId: '${json['product_id'] ?? json['productId'] ?? p['id'] ?? ''}',
      productName:
          '${p['name'] ?? json['product_name'] ?? json['productName'] ?? json['product_id'] ?? ''}',
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      frequency: humanizeFrequency('${json['frequency'] ?? ''}'),
      status: '${json['status'] ?? ''}',
      nextDelivery:
          '${json['nextDelivery'] ?? json['next_delivery'] ?? ''}',
      days: '${json['days'] ?? ''}',
    );
  }

  /// Pretty display for `days` ("Mon,Wed,Fri" → "Mon, Wed, Fri").
  String get daysLabel {
    final parts =
        days.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(', ');
  }
}

class VendorKpis {  final int todayDeliveries;
  final num todayRevenue;
  final int activeSubscriptions;
  final int pendingOrders;
  final int weekCompletions;
  final int cancelledCount;
  final int customerCount;
  final int newCustomersWeek;
  final num aov;
  final int refillQty;
  final int jarQty;

  const VendorKpis({
    required this.todayDeliveries,
    required this.todayRevenue,
    required this.activeSubscriptions,
    required this.pendingOrders,
    this.weekCompletions = 0,
    this.cancelledCount = 0,
    this.customerCount = 0,
    this.newCustomersWeek = 0,
    this.aov = 0,
    this.refillQty = 0,
    this.jarQty = 0,
  });

  /// Share of refill units in the refill/jar mix (0..1, 0 when empty).
  double get refillShare {
    final total = refillQty + jarQty;
    if (total <= 0) return 0;
    return refillQty / total;
  }

  factory VendorKpis.fromJson(Map<String, dynamic> json) => VendorKpis(
        todayDeliveries: (json['todayDeliveries'] as num? ?? 0).toInt(),
        todayRevenue: json['todayRevenue'] as num? ?? 0,
        activeSubscriptions:
            (json['activeSubscriptions'] as num? ?? 0).toInt(),
        pendingOrders: (json['pendingOrders'] as num? ?? 0).toInt(),
        weekCompletions: (json['weekCompletions'] as num? ?? 0).toInt(),
        cancelledCount: (json['cancelledCount'] as num? ?? 0).toInt(),
        customerCount: (json['customerCount'] as num? ?? 0).toInt(),
        newCustomersWeek: (json['newCustomersWeek'] as num? ?? 0).toInt(),
        aov: json['aov'] as num? ?? 0,
        refillQty: (json['refillQty'] as num? ?? 0).toInt(),
        jarQty: (json['jarQty'] as num? ?? 0).toInt(),
      );

  VendorKpis copyWith({
    int? todayDeliveries,
    num? todayRevenue,
    int? activeSubscriptions,
    int? pendingOrders,
    int? weekCompletions,
    int? cancelledCount,
    int? customerCount,
    int? newCustomersWeek,
    num? aov,
    int? refillQty,
    int? jarQty,
  }) =>
      VendorKpis(
        todayDeliveries: todayDeliveries ?? this.todayDeliveries,
        todayRevenue: todayRevenue ?? this.todayRevenue,
        activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
        pendingOrders: pendingOrders ?? this.pendingOrders,
        weekCompletions: weekCompletions ?? this.weekCompletions,
        cancelledCount: cancelledCount ?? this.cancelledCount,
        customerCount: customerCount ?? this.customerCount,
        newCustomersWeek: newCustomersWeek ?? this.newCustomersWeek,
        aov: aov ?? this.aov,
        refillQty: refillQty ?? this.refillQty,
        jarQty: jarQty ?? this.jarQty,
      );
}

/// True when a demo/live `created_at` falls in the last 7 days.
/// Demo uses display strings ('Today', '20 Sept'); live uses ISO.
/// Anything unparseable returns false (never fake history).
bool isWithinWeek(String createdAt, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final s = createdAt.trim();
  if (s.isEmpty) return false;
  if (s.toLowerCase() == 'today') return true;
  // Demo "20 Sept" / "19 Sept" / "9 Sept • 9:40 AM" → assume current year.
  final demo = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3,})').firstMatch(s);
  if (demo != null) {
    final day = int.tryParse(demo.group(1)!);
    final monStr = demo.group(2)!.substring(0, 3).toLowerCase();
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final mon = months[monStr];
    if (day != null && mon != null) {
      final d = DateTime(ref.year, mon, day);
      final diff = ref.difference(d).inDays;
      return diff >= 0 && diff < 7;
    }
    return false;
  }
  // ISO / date-parseable fallback.
  try {
    final d = DateTime.parse(s);
    final diff = ref.difference(d).inDays;
    return diff >= 0 && diff < 7;
  } catch (_) {
    return false;
  }
}

/// Client-side extended KPIs derived from the full vendor order list
/// (GET /api/vendor/orders; demo: DemoStore list). No new endpoints.
/// Base "today" counters come from the caller; everything else is
/// computed here honestly from the list (no fake history).
VendorKpis withExtendedKpis(VendorKpis base, List<VendorOrder> orders,
    {DateTime? now}) {
  final ref = now ?? DateTime.now();
  var weekDone = 0;
  var cancelled = 0;
  final customers = <String>{};
  final weekCustomers = <String>{};
  num billableTotal = 0;
  var billableCount = 0;
  var refill = 0;
  var jar = 0;
  for (final o in orders) {
    final key = o.customerEmail.isNotEmpty
        ? 'e:${o.customerEmail.toLowerCase()}'
        : o.customerPhone.isNotEmpty
            ? 'p:${o.customerPhone}'
            : o.customerName.isNotEmpty
                ? 'n:${o.customerName.toLowerCase()}'
                : 'id:${o.id}';
    if (o.hasCustomer) customers.add(key);
    final inWeek = isWithinWeek(o.createdAt, now: ref);
    if (o.status == 'cancelled') {
      cancelled++;
    } else {
      billableTotal += o.total;
      billableCount++;
    }
    if (o.status == 'delivered' && inWeek) weekDone++;
    if (inWeek && o.hasCustomer) weekCustomers.add(key);
    for (final it in o.items) {
      final hay = '${it.productId} ${it.name}'.toLowerCase();
      if (hay.contains('refill')) {
        refill += it.qty;
      } else if (hay.contains('jar')) {
        jar += it.qty;
      }
    }
  }
  return base.copyWith(
    weekCompletions: weekDone,
    cancelledCount: cancelled,
    customerCount: customers.length,
    newCustomersWeek: weekCustomers.length,
    aov: billableCount == 0 ? 0 : billableTotal / billableCount,
    refillQty: refill,
    jarQty: jar,
  );
}

/// Vendor data layer. Demo mode serves the shared [DemoStore] instantly
/// (the same order list the user repositories use); live mode hits the
/// PII-stripped vendor endpoints (contract) plus the approved nested
/// `customer: {name, phone, email}` identity block.
class VendorService {
  const VendorService({SessionStore? sessions, ApiClient? api})
      : _sessions = sessions ?? const SessionStore(),
        _api = api;

  final SessionStore _sessions;
  final ApiClient? _api;

  Future<ApiClient> _client() async {
    if (_api != null) return _api;
    return ApiClient(token: await _sessions.readToken());
  }

  static List<VendorOrder> get _demoOrders => DemoStore.orders
      .map((e) => VendorOrder.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  static VendorKpis get _demoKpis {
    final all = _demoOrders;
    final deliveredToday = all
        .where((o) => o.status == 'delivered' && o.createdAt == 'Today')
        .toList();
    final pending = all
        .where((o) =>
            o.status == 'scheduled' ||
            o.status == 'preparing' ||
            o.status == 'out_for_delivery')
        .length;
    final activeSubs = _demoSubs.where((s) => s.status == 'active').length;
    final revenue =
        deliveredToday.fold<num>(0, (sum, o) => sum + o.total);
    return withExtendedKpis(
      VendorKpis(
        todayDeliveries: deliveredToday.length,
        todayRevenue: revenue,
        activeSubscriptions: activeSubs,
        pendingOrders: pending,
      ),
      all,
    );
  }

  Future<VendorKpis> fetchKpis() async {
    if (AppConfig.demoMode) return _demoKpis;
    final api = await _client();
    final body = await api.get('/api/vendor/kpis');
    final base =
        VendorKpis.fromJson(Map<String, dynamic>.from(body as Map));
    // Extended KPIs are derived client-side from the full order list —
    // no new endpoints (contract frozen). Failure keeps the base counters.
    try {
      final orders = await fetchOrders();
      return withExtendedKpis(base, orders);
    } catch (_) {
      return base;
    }
  }

  Future<List<VendorOrder>> fetchOrders({String? status}) async {
    if (AppConfig.demoMode) {
      final all = _demoOrders;
      if (status == null || status.isEmpty || status == 'all') return all;
      return all.where((o) => o.status == status).toList();
    }
    final api = await _client();
    final body = await api.get('/api/vendor/orders',
        query: ordersQuery(status));
    final list = body is List ? body : (body as Map)['orders'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) =>
            VendorOrder.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> updateStatus(String id, String status) async {
    if (AppConfig.demoMode) {
      final i = DemoStore.orders.indexWhere((o) => '${o['id']}' == id);
      if (i == -1) throw const AppException('NOT_FOUND', 'Order not found');
      final o = VendorOrder.fromJson(
          Map<String, dynamic>.from(DemoStore.orders[i]));
      // Mirror the live guard (contract: forward-only, any→cancelled):
      // illegal jumps are rejected here just like the live 409.
      final isFinal = o.status == 'delivered' || o.status == 'cancelled';
      final legal =
          (status == 'cancelled' && !isFinal) || status == nextStatus(o.status);
      if (!legal) {
        throw AppException(
            'CONFLICT', 'Cannot move order from ${o.status} to $status');
      }
      DemoStore.orders[i] = {
        ...DemoStore.orders[i],
        'status': status,
      };
      return;
    }
    final api = await _client();
    await api.patch('/api/vendor/orders/$id', body: {'status': status});
  }

  static List<VendorSubscription> get _demoSubs => DemoStore
      .vendorSubscriptions
      .map((e) => VendorSubscription.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  Future<List<VendorSubscription>> fetchVendorSubscriptions() async {
    if (AppConfig.demoMode) return List.of(_demoSubs);
    final api = await _client();
    final body = await api.get('/api/vendor/subscriptions');
    final list = body is List ? body : (body as Map)['subscriptions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => VendorSubscription.fromJson(
            Map<String, dynamic>.from(e)))
        .toList();
  }
}
