import 'package:flutter/material.dart';

import '../../models/cart_model.dart';
import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import 'vendor_order.dart';

/// Sitemap: `vendor_earnings` (role:vendor, derived ledger from
/// GET /api/vendor/orders — no new endpoint).
///
/// Flow: VendorHome tab → fetchOrders (existing) → summarize → ledger.
/// Totals exclude cancelled orders (same rule as [withExtendedKpis] AOV).
/// Each order total embeds a ₹10 delivery fee (see OrderRepository:
/// `subtotal + Cart.deliveryFee`) — the fee split below is derived
/// client-side from that contract, never fetched.
Color _vendorStatusColor(String status) {
  switch (status) {
    case 'delivered':
      return const Color(0xFF2E7D32);
    case 'cancelled':
      return const Color(0xFFD32F2F);
    case 'out_for_delivery':
      return const Color(0xFF1B7BD6);
    case 'preparing':
      return const Color(0xFFEF6C00);
    default:
      return const Color(0xFF6E6E73);
  }
}

class EarningsSummary {
  const EarningsSummary({
    required this.grossRevenue,
    required this.todayRevenue,
    required this.weekRevenue,
    required this.billableCount,
    required this.cancelledCount,
    required this.aov,
    required this.todayCount,
    required this.weekCount,
  });

  final num grossRevenue;
  final num todayRevenue;
  final num weekRevenue;
  final int billableCount;
  final int cancelledCount;
  final num aov;
  final int todayCount;
  final int weekCount;

  /// Derived fee estimate: one ₹10 fee embedded per billable order.
  num get feeTotal => billableCount * Cart.deliveryFee;

  num get netRevenue => grossRevenue - feeTotal;
}

bool _isToday(String createdAt, DateTime ref) {
  final s = createdAt.trim();
  if (s.isEmpty) return false;
  if (s.toLowerCase() == 'today') return true;
  try {
    final d = DateTime.parse(s);
    return d.year == ref.year && d.month == ref.month && d.day == ref.day;
  } catch (_) {
    return false;
  }
}

/// Pure ledger math over the vendor order list. Cancelled orders count
/// separately and never enter revenue/AOV.
EarningsSummary summarizeVendorEarnings(List<VendorOrder> orders,
    {DateTime? now}) {
  final ref = now ?? DateTime.now();
  num gross = 0;
  num today = 0;
  num week = 0;
  var billable = 0;
  var cancelled = 0;
  var todayN = 0;
  var weekN = 0;
  for (final o in orders) {
    if (o.status == 'cancelled') {
      cancelled++;
      continue;
    }
    gross += o.total;
    billable++;
    if (_isToday(o.createdAt, ref)) {
      today += o.total;
      todayN++;
    }
    if (isWithinWeek(o.createdAt, now: ref)) {
      week += o.total;
      weekN++;
    }
  }
  return EarningsSummary(
    grossRevenue: gross,
    todayRevenue: today,
    weekRevenue: week,
    billableCount: billable,
    cancelledCount: cancelled,
    aov: billable == 0 ? 0 : gross / billable,
    todayCount: todayN,
    weekCount: weekN,
  );
}

class VendorEarningsScreen extends StatefulWidget {
  const VendorEarningsScreen(
      {super.key, required this.service, this.showAppBar = true});

  final VendorService service;

  /// False when embedded in the VendorHome tabs (it owns the AppBar).
  final bool showAppBar;

  @override
  State<VendorEarningsScreen> createState() => _VendorEarningsScreenState();
}

class _VendorEarningsScreenState extends State<VendorEarningsScreen> {
  bool _offline = false;
  late Future<List<VendorOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
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
        // NETWORK-only flag: the error+retry path still shows, with the
        // offline chip visible in the header.
        if (mounted) setState(() => _offline = true);
      }
      rethrow;
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<VendorOrder>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, __) => const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBar(width: 120),
                    SizedBox(height: 8),
                    _SkeletonBar(width: 200),
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
                      : 'Could not load earnings.'),
                  const SizedBox(height: 4),
                  Text(
                      expired ? 'Please log in again.' : '${snap.error}',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Color(0xFF6E6E73))),
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
                      child: Text(expired ? 'Log in' : 'Retry')),
                ],
              ),
            ),
          );
        }
        final orders = snap.data!;
        if (orders.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No earnings yet.'),
                  SizedBox(height: 4),
                  Text(
                    'Revenue appears here once billable orders arrive.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6E6E73)),
                  ),
                ],
              ),
            ),
          );
        }
        final s = summarizeVendorEarnings(orders);
        final billable =
            orders.where((o) => o.status != 'cancelled').toList();
        return RefreshIndicator(
          onRefresh: () async {
            _retry();
            try {
              await _future;
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_offline)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
              Row(
                children: [
                  Expanded(
                      child: _Kpi('Gross revenue',
                          inr(s.grossRevenue.toDouble()))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Kpi(
                          'Today', inr(s.todayRevenue.toDouble()))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _Kpi(
                          'This week', inr(s.weekRevenue.toDouble()))),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          _Kpi('Avg order', inr(s.aov.toDouble()))),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fee split',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Gross ${inr(s.grossRevenue.toDouble())} − '
                        'Delivery fees (${s.billableCount} × ${inr(Cart.deliveryFee)}) = '
                        'Net ${inr(s.netRevenue.toDouble())}',
                        style:
                            const TextStyle(color: Color(0xFF6E6E73)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Each order total embeds a ₹10 delivery fee; the split is derived client-side. Cancelled orders never enter revenue.',
                        style: TextStyle(color: Color(0xFF6E6E73)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.billableCount} billable · ${s.todayCount} today · '
                '${s.weekCount} this week · ${s.cancelledCount} cancelled.',
                style: const TextStyle(color: Color(0xFF6E6E73)),
              ),
              const SizedBox(height: 16),
              const Text('Ledger',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final o in billable) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              '#${o.id} · ${o.createdAt.isEmpty ? '—' : o.createdAt}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _vendorStatusColor(o.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            o.status.replaceAll('_', ' '),
                            style: TextStyle(
                                color: _vendorStatusColor(o.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(inr(o.total.toDouble()),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
    if (!widget.showAppBar) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: content,
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF6E6E73))),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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
