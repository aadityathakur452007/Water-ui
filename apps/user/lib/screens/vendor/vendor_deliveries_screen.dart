import 'package:flutter/material.dart';

import '../../route/route_constants.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/vendor_service.dart';

/// Vendor deliveries (subscriptions) — read-only list. Shows
/// quantity/frequency/status/next delivery only, never user PII.
class VendorDeliveriesScreen extends StatefulWidget {
  const VendorDeliveriesScreen({super.key, required this.service});

  final VendorService service;

  @override
  State<VendorDeliveriesScreen> createState() =>
      _VendorDeliveriesScreenState();
}

class _VendorDeliveriesScreenState
    extends State<VendorDeliveriesScreen> {
  static const _filters = ['all', 'active', 'paused'];

  String _filter = 'all';
  late Future<List<VendorSubscription>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchVendorSubscriptions();
  }

  void _refresh() =>
      setState(() => _future = widget.service.fetchVendorSubscriptions());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = _filters[i];
              return ChoiceChip(
                label: Text(f[0].toUpperCase() + f.substring(1)),
                selected: f == _filter,
                onSelected: (_) => setState(() => _filter = f),
              );
            },
          ),
        ),
        Expanded(
          child: FutureBuilder<List<VendorSubscription>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Loading subscriptions\u2026'),
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
                      : 'Could not load subscriptions.'),
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
                          : _refresh,
                      child: Text(expired ? 'Log in' : 'Retry')),
                ],
              ),
            ),
          );
        }
        final all = snap.data!;
        if (all.isEmpty) {
          return const Center(child: Text('No subscriptions yet.'));
        }
        final subs = _filter == 'all'
            ? all
            : all
                .where((s) => s.status.toLowerCase() == _filter)
                .toList();
        if (subs.isEmpty) {
          return Center(
              child: Text('No $_filter subscriptions yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: subs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = subs[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.repeat,
                      color: Color(0xFF1B7BD6)),
                  title: Text(
                      s.productName.isEmpty
                          ? 'Qty ${s.quantity} \u00B7 ${s.frequency}'
                          : '${s.productName} \u00D7${s.quantity}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${s.frequency} \u00B7 Status: ${s.status}\nNext delivery: ${s.nextDelivery}'),
                  isThreeLine: true,
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
