import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';

import '../../models/cart_model.dart';
import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';

/// Dashboard: KPI cards from GET /api/vendor/kpis.
///
/// ui-checklist Card coverage: one base style, consistent spacing, clear
/// content hierarchy. Loading checklist: specific loading text + error
/// with retry. A small UiBarChart visualizes the two "today" counters
/// (pure CustomPaint, no extra deps); trend lines are omitted — the API
/// returns point-in-time counters, not history (no fake data).
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
            k.pendingOrders == 0;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              UiKpiRow(kpis: [
                UiKpiData(
                    label: 'Today deliveries',
                    value: '${k.todayDeliveries}',
                    icon: UiIcons.shipping,
                    color: const Color(0xFF1B7BD6)),
                UiKpiData(
                    label: 'Today revenue',
                    value: inr(k.todayRevenue.toDouble()),
                    icon: UiIcons.cart,
                    color: const Color(0xFF1B7BD6)),
                UiKpiData(
                    label: 'Active subscriptions',
                    value: '${k.activeSubscriptions}',
                    icon: UiIcons.refresh,
                    color: const Color(0xFF1B7BD6)),
                UiKpiData(
                    label: 'Pending orders',
                    value: '${k.pendingOrders}',
                    icon: UiIcons.clock,
                    color: const Color(0xFF1B7BD6)),
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
              else
                UiBarChart(
                  data: [
                    UiBarChartData(
                        label: 'Deliveries',
                        value: k.todayDeliveries.toDouble(),
                        color: const Color(0xFF1B7BD6)),
                    UiBarChartData(
                        label: 'Pending',
                        value: k.pendingOrders.toDouble(),
                        color: const Color(0xFF6E6E73)),
                  ],
                  height: 180,
                  showValues: true,
                ),
            ],
          ),
        );
      },
    );
  }
}
