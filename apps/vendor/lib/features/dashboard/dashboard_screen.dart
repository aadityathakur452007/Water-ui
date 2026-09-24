import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';

import 'dashboard_service.dart';

/// Dashboard: KPI cards from GET /api/vendor/kpis.
///
/// ui-checklist Card coverage: one base style, consistent spacing, clear
/// content hierarchy. Loading checklist: specific loading text + error
/// with retry. A small UiBarChart visualizes the two "today" counters
/// (pure CustomPaint, no extra deps); trend lines are omitted — the API
/// returns point-in-time counters, not history (no fake data).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.service});

  final DashboardService service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<VendorKpis> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchKpis();
  }

  void _retry() => setState(() => _future = widget.service.fetchKpis());

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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load KPIs.'),
                  const SizedBox(height: 4),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6E6E73))),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _retry, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final k = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => _retry(),
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
                    value: '\u20B9${k.todayRevenue}',
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
