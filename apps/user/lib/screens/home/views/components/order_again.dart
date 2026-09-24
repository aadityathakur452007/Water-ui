import 'package:flutter/material.dart';

import '../../../../constants.dart';
import '../../../../models/cart_model.dart';
import '../../../../models/order_model.dart';
import '../../../../repositories/order_repository.dart';
import '../../../../route/route_constants.dart';

/// "Order again" strip driven by the last order in [OrderRepository].
class OrderAgain extends StatelessWidget {
  const OrderAgain({super.key});

  @override
  Widget build(BuildContext context) {
    final Order? last = const OrderRepository().lastOrder();
    if (last == null || last.items.isEmpty) return const SizedBox.shrink();
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
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF4FC),
              borderRadius:
                  BorderRadius.all(Radius.circular(defaultBorderRadious)),
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
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
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
  }
}
