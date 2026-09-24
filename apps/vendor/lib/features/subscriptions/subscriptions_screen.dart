import 'package:flutter/material.dart';

import 'subscriptions_service.dart';

/// Subscriptions view — read-only list (contract exposes no vendor
/// mutation). Shows quantity/frequency/status/next delivery only.
class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, required this.service});

  final SubscriptionsService service;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late Future<List<VendorSubscription>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchSubscriptions();
  }

  void _refresh() =>
      setState(() => _future = widget.service.fetchSubscriptions());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VendorSubscription>>(
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load subscriptions.'),
                  const SizedBox(height: 4),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Color(0xFF6E6E73))),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final subs = snap.data!;
        if (subs.isEmpty) {
          return const Center(child: Text('No active subscriptions.'));
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: subs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = subs[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.repeat,
                      color: Color(0xFF1B7BD6)),
                  title: Text('Qty ${s.quantity} \u00B7 ${s.frequency}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Status: ${s.status}\nNext delivery: ${s.nextDelivery}'),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
