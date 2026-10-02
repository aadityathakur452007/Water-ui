import 'package:flutter/material.dart';

import '../../models/cart_model.dart';
import 'vendor_customers_screen.dart';

/// Sitemap: `vendor_customer_detail` (role:vendor, data: passed from the
/// customers list — derived from GET /api/vendor/orders, no new endpoint).
///
/// Flow: customers list tap → detail (orders + totals) → back. Sync view:
/// no fetch happens here, so there is no loading/error state to fake —
/// an empty order list renders the genuine-empty card instead.
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

class VendorCustomerDetailScreen extends StatelessWidget {
  const VendorCustomerDetailScreen(
      {super.key, required this.customer, this.offline = false});

  final VendorCustomer customer;

  /// Set by the customers list when it is showing the offline flag.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(customer.displayName)),
            if (offline) ...[
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    child: Text(customer.displayName.isEmpty
                        ? '?'
                        : customer.displayName[0].toUpperCase()),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.displayName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        if (customer.phone.isNotEmpty)
                          Text(customer.phone),
                        if (customer.email.isNotEmpty)
                          Text(customer.email,
                              style: const TextStyle(
                                  color: Color(0xFF6E6E73))),
                        const SizedBox(height: 8),
                        Text(
                          '${customer.orderCount} ${customer.orderCount == 1 ? 'order' : 'orders'} · '
                          'Total ${inr(customer.totalSpent.toDouble())} · '
                          'Avg ${inr(customer.averageOrder.toDouble())}',
                          style: const TextStyle(
                              color: Color(0xFF6E6E73)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Orders (${customer.orders.length})',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (customer.orders.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text('No orders for this customer.',
                    style: TextStyle(color: Color(0xFF6E6E73))),
              ),
            )
          else
            for (final o in customer.orders) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                      '#${o.id} · ${inr(o.total.toDouble())}',
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
                                        color:
                                            _vendorStatusColor(o.status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            for (final item in o.items)
                              Text('${item.qty} × ${item.name}'),
                            const SizedBox(height: 2),
                            Text('Slot: ${o.slot}',
                                style: const TextStyle(
                                    color: Color(0xFF6E6E73))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}
