import '../models/subscription_model.dart';

/// Local/mock subscription source for the Home "active delivery"
/// card and (Phase 2) subscription management.
class SubscriptionRepository {
  const SubscriptionRepository();

  Subscription? activeDelivery() => const Subscription(
        id: "SUB-042",
        productId: "wd-20l",
        productName: "20L Drinking Water Jar",
        quantity: 2,
        frequency: Frequency.everyDay,
        startDate: "25 September 2026",
        deliveryTime: "8:00 AM",
        status: SubscriptionStatus.active,
        nextDelivery: "Tomorrow • 8:00 AM",
      );

  List<Subscription> subscriptions() => [
        if (activeDelivery() != null) activeDelivery()!,
      ];
}
