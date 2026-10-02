import 'package:flutter/material.dart';

import '../../models/cart_model.dart';
import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import 'vendor_customer_detail_screen.dart';
import 'vendor_order.dart';

/// Sitemap: `vendor_customers` (role:vendor, data: derived from
/// GET /api/vendor/orders — no new endpoint).
///
/// Flow: VendorHome tab → fetchOrders (existing) → group by customer key
/// → search → tap → detail. Every gesture continues: search filters,
/// tap pushes the detail, retry/error re-fetch, pull-refresh reloads.
///
/// Status badges live on the detail + earnings screens (copied
/// `_statusColor` logic); this list shows counts/totals only.

/// Grouping key — mirrors [withExtendedKpis] in vendor_service.dart exactly:
/// email (lowercased) wins, then phone, then name (lowercased), else order id.
String vendorCustomerKey(VendorOrder o) {
  if (o.customerEmail.isNotEmpty) return 'e:${o.customerEmail.toLowerCase()}';
  if (o.customerPhone.isNotEmpty) return 'p:${o.customerPhone}';
  if (o.customerName.isNotEmpty) return 'n:${o.customerName.toLowerCase()}';
  return 'id:${o.id}';
}

/// One customer bucket: identity from the first order + every order placed
/// under the same grouping key. Derived only — never invented.
class VendorCustomer {
  const VendorCustomer({
    required this.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.orders,
  });

  final String key;
  final String name;
  final String phone;
  final String email;
  final List<VendorOrder> orders;

  factory VendorCustomer.fromOrders(String key, List<VendorOrder> orders) {
    final first = orders.first;
    return VendorCustomer(
      key: key,
      name: first.customerName,
      phone: first.customerPhone,
      email: first.customerEmail,
      orders: List.of(orders),
    );
  }

  String get displayName =>
      name.isNotEmpty ? name : phone.isNotEmpty ? phone : email;

  int get orderCount => orders.length;

  num get totalSpent => orders.fold<num>(0, (s, o) => s + o.total);

  num get averageOrder => orderCount == 0 ? 0 : totalSpent / orderCount;
}

/// Groups orders with customer identity; rows without any customer field
/// are skipped (never invent a customer). Sorted by spend, descending.
List<VendorCustomer> groupVendorCustomers(List<VendorOrder> orders) {
  final buckets = <String, List<VendorOrder>>{};
  for (final o in orders) {
    if (!o.hasCustomer) continue;
    final key = vendorCustomerKey(o);
    (buckets[key] ??= []).add(o);
  }
  final out = [
    for (final e in buckets.entries)
      VendorCustomer.fromOrders(e.key, e.value),
  ];
  out.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
  return out;
}

/// Case-insensitive match on name/phone/email. Empty query returns all.
List<VendorCustomer> filterVendorCustomers(
    List<VendorCustomer> customers, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return customers;
  return customers
      .where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q))
      .toList();
}

class VendorCustomersScreen extends StatefulWidget {
  const VendorCustomersScreen(
      {super.key, required this.service, this.showAppBar = true});

  final VendorService service;

  /// False when embedded in the VendorHome tabs (it owns the AppBar).
  final bool showAppBar;

  @override
  State<VendorCustomersScreen> createState() => _VendorCustomersScreenState();
}

class _VendorCustomersScreenState extends State<VendorCustomersScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _offline = false;
  late Future<List<VendorOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<VendorOrder>> _load() async {
    try {
      final orders = await widget.service.fetchOrders();
      if (mounted) setState(() => _offline = false);
      return orders;
    } on AppException catch (e) {
      if (e.code == 'UNAUTHENTICATED' || e.status == 401) {
        await const AuthService().handleUnauthorized();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, logInScreenRoute, (_) => false);
        }
      } else if (e.code == 'NETWORK') {
        // NETWORK-only flag: the error+retry path below still shows, with
        // the offline chip visible in the header.
        if (mounted) setState(() => _offline = true);
      }
      rethrow;
    }
  }

  void _retry() => setState(() => _future = _load());

  void _openDetail(VendorCustomer customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VendorCustomerDetailScreen(
            customer: customer, offline: _offline),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                      labelText: 'Search customers'),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (_offline) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF4FC),
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 12, color: Color(0xFF1B7BD6)),
                      SizedBox(width: 4),
                      Text('Offline',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1B7BD6))),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<VendorOrder>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: 6,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, __) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                              backgroundColor: Color(0xFFE8E8E9)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _SkeletonBar(width: 140),
                                SizedBox(height: 8),
                                _SkeletonBar(width: 100),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              if (snap.hasError) {
                final err = snap.error;
                final expired = err is AppException &&
                    (err.code == 'UNAUTHENTICATED' || err.status == 401);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(expired
                            ? 'Session expired.'
                            : 'Could not load customers.'),
                        const SizedBox(height: 4),
                        Text(
                            expired
                                ? 'Please log in again.'
                                : '${snap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF6E6E73))),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: expired
                                ? () async {
                                    await const AuthService()
                                        .handleUnauthorized();
                                    if (context.mounted) {
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        logInScreenRoute,
                                        (_) => false,
                                      );
                                    }
                                  }
                                : _retry,
                            child:
                                Text(expired ? 'Log in' : 'Retry')),
                      ],
                    ),
                  ),
                );
              }
              final all =
                  groupVendorCustomers(snap.data!);
              if (all.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No customers yet.'),
                        SizedBox(height: 4),
                        Text(
                          'Customers appear here once orders are placed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6E6E73)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final shown = filterVendorCustomers(all, _query);
              if (shown.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No customers match "$_query".'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _query = '';
                            _search.clear();
                          }),
                          child: const Text('Clear search'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  _retry();
                  try {
                    await _future;
                  } catch (_) {}
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: shown.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding:
                            const EdgeInsets.fromLTRB(4, 0, 4, 4),
                        child: Text(
                          '${shown.length} ${shown.length == 1 ? 'customer' : 'customers'}',
                          style: const TextStyle(
                              color: Color(0xFF6E6E73)),
                        ),
                      );
                    }
                    final c = shown[i - 1];
                    final sub = [
                      if (c.phone.isNotEmpty) c.phone,
                      if (c.email.isNotEmpty) c.email,
                    ].join(' · ');
                    return Card(
                      child: InkWell(
                        onTap: () => _openDetail(c),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                child: Text(c.displayName.isEmpty
                                    ? '?'
                                    : c.displayName[0].toUpperCase()),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.displayName,
                                        style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w600)),
                                    if (sub.isNotEmpty)
                                      Text(sub,
                                          style: const TextStyle(
                                              color: Color(
                                                  0xFF6E6E73))),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${c.orderCount} ${c.orderCount == 1 ? 'order' : 'orders'} · ${inr(c.totalSpent.toDouble())}',
                                      style: const TextStyle(
                                          color:
                                              Color(0xFF6E6E73)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
    if (!widget.showAppBar) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: content,
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: const BoxDecoration(
        color: Color(0xFFE8E8E9),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );
  }
}
