import 'package:flutter/material.dart';

import 'order_detail_screen.dart';
import 'order_model.dart';
import 'orders_service.dart';

/// Orders list with status filter chips (ui-checklist Tabs pattern:
/// concise labels, clear active/inactive style).
///
/// PII RULE: each row shows ONLY address + items/qty + amount + slot.
/// Never renders user name/phone/email (the model has no such fields).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.service, required this.onLogout});

  final OrdersService service;
  final VoidCallback onLogout;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
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
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
            service: widget.service, initial: order),
      ),
    );
    if (changed == true) _refresh();
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
            separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load orders.'),
                        const SizedBox(height: 4),
                        Text('${snap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF6E6E73))),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: _refresh,
                            child: const Text('Retry')),
                      ],
                    ),
                  ),
                );
              }
              final orders = snap.data!;
              if (orders.isEmpty) {
                return const Center(
                    child: Text('No orders for this filter.'));
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final o = orders[i];
                    final itemsLabel = o.items
                        .map((e) => '${e.name} \u00D7${e.qty}')
                        .join(', ');
                    return Card(
                      child: ListTile(
                        title: Text(
                            '#${o.id} \u00B7 \u20B9${o.total}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${o.addressLine}, ${o.addressCity}\n$itemsLabel\nSlot: ${o.slot} \u00B7 ${o.status.replaceAll('_', ' ')}',
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
