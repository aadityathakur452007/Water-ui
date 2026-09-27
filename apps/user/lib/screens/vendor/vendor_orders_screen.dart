import 'package:flutter/material.dart';

import '../../components/network_image_with_loader.dart';
import '../../models/cart_model.dart';
import '../../repositories/product_repository.dart';
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
/// Thumbnails resolve locally via `ProductRepository.byId().image`
/// (fallback icon); amounts use `inr()`; status uses badge colors.
class VendorOrdersScreen extends StatefulWidget {
  const VendorOrdersScreen(
      {super.key, required this.service, this.onViewDashboard});

  final VendorService service;

  /// Empty-state CTA target (VendorHome switches to the Dashboard tab).
  final VoidCallback? onViewDashboard;

  @override
  State<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

Color _statusColor(String status) {
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
  final _products = const ProductRepository();

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
    // popped-context bug). List + KPIs re-fetch on return (shared
    // store/DB is the sync path — no push channel).
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
                onRefresh: () async {
                  _refresh();
                  await _future;
                },
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
                    final customerParts = [
                      if (o.customerName.isNotEmpty) o.customerName,
                      if (o.customerPhone.isNotEmpty) o.customerPhone,
                    ];
                    final thumbId = o.items.isNotEmpty
                        ? o.items.first.productId
                        : '';
                    final thumbImg = thumbId.isNotEmpty
                        ? _products.byId(thumbId).image
                        : '';
                    // Days chip: orders carry no `days` today — show the
                    // days value when present, else the frequency for
                    // regular orders when present, else nothing (never
                    // invent delivery days).
                    final daysChip = o.daysLabel.isNotEmpty
                        ? o.daysLabel
                        : o.frequency.isNotEmpty
                            ? o.frequency
                            : o.type == 'regular'
                                ? 'Regular'
                                : '';
                    return Card(
                      child: InkWell(
                        onTap: () => _openDetail(o),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (thumbImg.isNotEmpty)
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: NetworkImageWithLoader(thumbImg,
                                      radius: 8),
                                )
                              else
                                const SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(Icons.water_drop,
                                      color: Color(0xFF1B7BD6)),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                              '#${o.id} \u00B7 ${inr(o.total.toDouble())}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _statusColor(o.status)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            o.status.replaceAll('_', ' '),
                                            style: TextStyle(
                                                color:
                                                    _statusColor(o.status),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (customerParts.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Text(
                                            customerParts.join(' \u00B7 '),
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.w500)),
                                      ),
                                    const SizedBox(height: 2),
                                    for (final item in o.items)
                                      Text(
                                          '${item.qty} \u00D7 ${item.name}'),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Slot: ${o.slot}',
                                      style: const TextStyle(
                                          color: Color(0xFF6E6E73)),
                                    ),
                                    if (daysChip.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4),
                                        child: Chip(
                                          label: Text(daysChip,
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          visualDensity:
                                              VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
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
  }
}
