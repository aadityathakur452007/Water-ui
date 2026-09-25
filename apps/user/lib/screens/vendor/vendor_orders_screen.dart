import 'package:flutter/material.dart';

import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';
import 'vendor_order.dart';
import 'vendor_order_detail_screen.dart';

/// Orders list with status filter chips (ui-checklist Tabs pattern:
/// concise labels, clear active/inactive style).
///
/// Customer identity (name/phone/email from the approved nested `customer`
/// block) renders above the address; rows without it show address only.
class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen(
      {super.key, required this.service, this.onViewDashboard});

  final VendorService service;

  /// Empty-state CTA target (VendorHome switches to the Dashboard tab).
  final VoidCallback? onViewDashboard;

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends State<VendorOrdersScreen> {
  static const _filters = [
    'all',
    'scheduled',
    'preparing',
    'out_for_delivery',
    'delivered',
    'cancelled',
  ];

  String _status = 'all';
  late Future<List<VendorOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchOrders();
  }

  void _refresh() => setState(
      () => _future = widget.service.fetchOrders(status: _status));

  Future<void> _openDetail(VendorOrder order) async {
    // The detail pops the new status string; the SnackBar lives here so
    // it uses a live context (showing it after pop in the detail is a
    // popped-context bug).
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => VendorOrderDetailScreen(
            service: widget.service, initial: order),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Order marked ${updated.replaceAll('_', ' ')}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = _filters[i];
              final selected = f == _status;
              return ChoiceChip(
                label: Text(f.replaceAll('_', ' ')),
                selected: selected,
                onSelected: (_) {
                  setState(() => _status = f);
                  _refresh();
                },
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<VendorOrder>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading orders\u2026'),
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
                            : 'Could not load orders.'),
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
                                : _refresh,
                            child: Text(expired ? 'Log in' : 'Retry')),
                      ],
                    ),
                  ),
                );
              }
              final orders = snap.data!;
              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No orders for this filter.'),
                        if (widget.onViewDashboard != null) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: widget.onViewDashboard,
                            child: const Text('View dashboard'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                        child: Text(
                          '${orders.length} ${orders.length == 1 ? 'order' : 'orders'}',
                          style: const TextStyle(color: Color(0xFF6E6E73)),
                        ),
                      );
                    }
                    final o = orders[i - 1];
                    final itemsLabel = o.items
                        .map((e) => '${e.name} \u00D7${e.qty}')
                        .join(', ');
                    final customerParts = [
                      if (o.customerName.isNotEmpty) o.customerName,
                      if (o.customerPhone.isNotEmpty) o.customerPhone,
                      if (o.customerEmail.isNotEmpty) o.customerEmail,
                    ];
                    return Card(
                      child: ListTile(
                        title: Text(
                            '#${o.id} \u00B7 \u20B9${o.total}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${customerParts.isNotEmpty ? '${customerParts.join(' \u00B7 ')}\n' : ''}${o.addressLine}, ${o.addressCity}\n$itemsLabel\nSlot: ${o.slot} \u00B7 ${o.status.replaceAll('_', ' ')}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openDetail(o),
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
  }
}
