import 'package:flutter/material.dart';

import '../../../../components/skleton/skelton.dart';
import '../../../../constants.dart';
import '../../../../models/subscription_model.dart';
import '../../../../repositories/subscription_repository.dart';
import '../../../../route/route_constants.dart';

/// Next-delivery card driven by [SubscriptionRepository].
/// Shows a skeleton while loading; hides on error/empty so Home
/// never breaks.
class ActiveDelivery extends StatefulWidget {
  const ActiveDelivery({super.key});

  @override
  State<ActiveDelivery> createState() => _ActiveDeliveryState();
}

class _ActiveDeliveryState extends State<ActiveDelivery> {
  Future<List<Subscription>>? _future;

  @override
  void initState() {
    super.initState();
    _future = const SubscriptionRepository().fetchSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Subscription>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Skeleton(height: 16, width: 140),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Skeleton(height: 76),
              ),
            ],
          );
        }
        if (snap.hasError) return const SizedBox.shrink();
        final subs = snap.data ?? const <Subscription>[];
        final active = subs.where(
            (s) => s.status == SubscriptionStatus.active);
        final sub = active.isNotEmpty
            ? active.first
            : const SubscriptionRepository().activeDelivery();
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
              padding:
                  const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: const BorderRadius.all(
                      Radius.circular(defaultBorderRadious)),
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
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(
                          context, subscriptionsScreenRoute),
                      child: const Text("View"),
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
