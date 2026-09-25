import 'package:flutter/material.dart';

import '../../../../components/skleton/skelton.dart';
import '../../../../constants.dart';
import '../../../../models/cart_model.dart';
import '../../../../models/order_model.dart';
import '../../../../repositories/order_repository.dart';
import '../../../../route/route_constants.dart';
import '../../../../services/api_client.dart';

/// "Order again" card driven by the newest ongoing order.
///
/// Plain water-blue tint (#EAF4FC) + [defaultBorderRadious] + existing
/// text styles. No gradients, glows, or pill shapes. Shows a skeleton
/// while loading; hides on error/empty so Home never breaks.
class OrderAgain extends StatefulWidget {
  const OrderAgain({super.key});

  @override
  State<OrderAgain> createState() => _OrderAgainState();
}

class _OrderAgainState extends State<OrderAgain> {
  final _repo = const OrderRepository();
  Future<Order?>? _future;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  static bool _isOngoing(Order o) =>
      o.status == OrderStatus.scheduled ||
      o.status == OrderStatus.preparing ||
      o.status == OrderStatus.outForDelivery ||
      o.status == OrderStatus.active;

  Future<Order?> _load() async {
    try {
      final remote = await _repo.fetchOrders();
      if (mounted) setState(() => _offline = false);
      final ongoing = remote.where(_isOngoing);
      if (ongoing.isNotEmpty) return ongoing.first;
      return _repo.lastOrder();
    } on AppException catch (e) {
      // NETWORK-only fallback: other errors rethrow so the error
      // card below explains instead of silently shrinking.
      if (e.code != 'NETWORK') rethrow;
      if (mounted) setState(() => _offline = true);
      return _repo.lastOrder();
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Order?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Skeleton(height: 16, width: 110),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Skeleton(height: 76),
              ),
            ],
          );
        }
        if (snap.hasError) {
          // Explain instead of shrinking: genuine-empty still hides
          // below, but a failed load gets a message + retry.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Text(
                  "Order again",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: const BorderRadius.all(
                        Radius.circular(defaultBorderRadious)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Could not load your last order.",
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Check your connection and try again.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _retry,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        final last = snap.data;
        if (last == null || last.items.isEmpty) {
          return const SizedBox.shrink();
        }
        final item = last.items.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Row(
                children: [
                  Text(
                    "Order again",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (_offline) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF4FC),
                        borderRadius:
                            BorderRadius.all(Radius.circular(30)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off,
                              size: 12, color: primaryColor),
                          SizedBox(width: 4),
                          Text(
                            "Offline",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF4FC),
                  borderRadius: BorderRadius.all(
                      Radius.circular(defaultBorderRadious)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            "${item.qty} × ${inr(item.price)} · ${inr(item.lineTotal)}",
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: defaultPadding),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: defaultPadding,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () => Navigator.pushNamed(
                          context, cartScreenRoute,
                          arguments: last),
                      child: const Text("Reorder"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
