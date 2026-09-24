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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Order?> _load() async {
    try {
      final remote = await _repo.fetchOrders();
      final ongoing = remote.where((o) =>
          o.status == OrderStatus.scheduled ||
          o.status == OrderStatus.active);
      if (ongoing.isNotEmpty) return ongoing.first;
      return _repo.lastOrder();
    } on AppException {
      return _repo.lastOrder();
    }
  }

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
        if (snap.hasError) return const SizedBox.shrink();
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
              child: Text(
                "Order again",
                style: Theme.of(context).textTheme.titleSmall,
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
