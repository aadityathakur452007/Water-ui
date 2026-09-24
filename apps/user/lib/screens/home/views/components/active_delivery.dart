import 'package:flutter/material.dart';

import '../../../../constants.dart';
import '../../../../repositories/subscription_repository.dart';
import '../../../../route/route_constants.dart';

/// Next-delivery card driven by [SubscriptionRepository].
class ActiveDelivery extends StatelessWidget {
  const ActiveDelivery({super.key});

  @override
  Widget build(BuildContext context) {
    final sub = const SubscriptionRepository().activeDelivery();
    if (sub == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(
            "Your next delivery",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius:
                  const BorderRadius.all(Radius.circular(defaultBorderRadious)),
            ),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF4FC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop,
                      color: primaryColor, size: 22),
                ),
                const SizedBox(width: defaultPadding),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${sub.quantity} × ${sub.productName}",
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub.nextDelivery,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, ordersScreenRoute),
                  child: const Text("View"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
