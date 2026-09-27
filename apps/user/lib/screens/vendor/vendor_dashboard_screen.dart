import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';

import '../../models/cart_model.dart';
import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';

/// Dashboard: today KPIs from GET /api/vendor/kpis + extended KPIs
/// derived client-side from GET /api/vendor/orders (see
/// [VendorService.fetchKpis] / [withExtendedKpis] — no new endpoints).
///
/// Layout: 4 hero KPIs + 4 secondary KPIs, bar chart (deliveries/pending),
/// refill-vs-jar mix row, honest week-trend text. No fake history: every
/// number comes from the order/subscription lists; empty stays explicit.
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key, required this.service});

  final VendorService service;

  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  late Future<VendorKpis> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchKpis();
  }

  void _retry() => setState(() => _future = widget.service.fetchKpis());

  /// Pull-refresh awaits the real fetch (not just the setState rebuild).
  Future<void> _reload() async {
    setState(() => _future = widget.service.fetchKpis());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VendorKpis>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading today\u2019s summary\u2026'),
              ],
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
                      : 'Could not load KPIs.'),
                  const SizedBox(height: 4),
                  Text(
                      expired
                          ? 'Please log in again.'
                          : '${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6E6E73))),
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
        final k = snap.data!;
        final isEmpty = k.todayDeliveries == 0 &&
            k.todayRevenue == 0 &&
            k.activeSubscriptions == 0 &&
            k.pendingOrders == 0 &&
            k.weekCompletions == 0 &&
            k.cancelledCount == 0 &&
            k.customerCount == 0;
        const blue = Color(0xFF1B7BD6);
        const grey = Color(0xFF6E6E73);
        final mixTotal = k.refillQty + k.jarQty;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              UiKpiRow(kpis: [
                UiKpiData(
                    label: 'Today revenue',
                    value: inr(k.todayRevenue.toDouble()),
                    icon: UiIcons.cart,
                    color: blue),
                UiKpiData(
                    label: 'Today deliveries',
                    value: '${k.todayDeliveries}',
                    icon: UiIcons.shipping,
                    color: blue),
                UiKpiData(
                    label: 'Pending orders',
                    value: '${k.pendingOrders}',
                    icon: UiIcons.clock,
                    color: blue),
                UiKpiData(
                    label: 'Active subscriptions',
                    value: '${k.activeSubscriptions}',
                    icon: UiIcons.refresh,
                    color: blue),
              ]),
              const SizedBox(height: 12),
              UiKpiRow(kpis: [
                UiKpiData(
                    label: 'Week completions',
                    value: '${k.weekCompletions}',
                    icon: UiIcons.check,
                    color: blue),
                UiKpiData(
                    label: 'Cancelled',
                    value: '${k.cancelledCount}',
                    icon: UiIcons.close,
                    color: grey),
                UiKpiData(
                    label: 'Customers',
                    value: '${k.customerCount}',
                    icon: UiIcons.group,
                    color: blue),
                UiKpiData(
                    label: 'Avg order',
                    value: inr(k.aov.toDouble()),
                    icon: UiIcons.payment,
                    color: blue),
              ]),
              const SizedBox(height: 16),
              const Text('Today at a glance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No activity yet',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text(
                            'New orders will appear here once customers book.'),
                      ],
                    ),
                  ),
                )
              else ...[
                UiBarChart(
                  data: [
                    UiBarChartData(
                        label: 'Deliveries',
                        value: k.todayDeliveries.toDouble(),
                        color: blue),
                    UiBarChartData(
                        label: 'Pending',
                        value: k.pendingOrders.toDouble(),
                        color: grey),
                  ],
                  height: 180,
                  showValues: true,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Refill vs jar mix',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (mixTotal == 0)
                          const Text('No jar/refill units in orders yet.',
                              style: TextStyle(color: grey))
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: k.refillQty,
                                child: Container(
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: blue,
                                    borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(4)),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: k.jarQty,
                                child: Container(
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4E9F8),
                                    borderRadius: BorderRadius.horizontal(
                                        right: Radius.circular(4)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Refill ${k.refillQty} · Jar ${k.jarQty} '
                              '(${(k.refillShare * 100).toStringAsFixed(0)}% refill)',
                              style: const TextStyle(color: grey)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${k.weekCompletions} completed this week · '
                  '${k.customerCount} customers '
                  '(${k.newCustomersWeek} active this week) · '
                  '${k.cancelledCount} cancelled overall.',
                  style: const TextStyle(color: grey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
