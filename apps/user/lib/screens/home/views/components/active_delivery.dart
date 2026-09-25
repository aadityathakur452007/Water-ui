import 'package:flutter/material.dart';

import '../../../../components/skleton/skelton.dart';
import '../../../../constants.dart';
import '../../../../models/subscription_model.dart';
import '../../../../repositories/subscription_repository.dart';
import '../../../../route/route_constants.dart';
import '../../../../services/api_client.dart';

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
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Subscription>> _load() async {
    try {
      final subs =
          await const SubscriptionRepository().fetchSubscriptions();
      if (mounted) setState(() => _offline = false);
      return subs;
    } on AppException catch (e) {
      // NETWORK-only fallback to the local seed; other errors rethrow
      // so the error card below explains instead of silently shrinking.
      if (e.code != 'NETWORK') rethrow;
      if (mounted) setState(() => _offline = true);
      return const SubscriptionRepository().subscriptions();
    }
  }

  void _retry() => setState(() => _future = _load());

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
        if (snap.hasError) {
          // Explain instead of shrinking: genuine-empty still hides
          // below, but a failed load gets a message + retry.
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
                        "Could not load your next delivery.",
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
              child: Row(
                children: [
                  Text(
                    "Your next delivery",
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
