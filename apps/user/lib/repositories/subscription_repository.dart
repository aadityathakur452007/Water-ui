import '../models/subscription_model.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

/// Subscription source for the Home "active delivery" card and
/// subscription management.
///
/// NOTE: the frozen contract + backend ship NO user-facing subscription
/// endpoints (only `GET /api/vendor/subscriptions`, role=vendor, PII
/// stripped). So this repository stays local-only on purpose — no
/// speculative endpoints are invented. [fetchSubscriptions] returns the
/// local list through the same async shape the UI uses, so adopting a
/// future `GET /api/subscriptions` is a one-body change.
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

  DeliveryProgress septemberProgress() => const DeliveryProgress(
        delivered: 18,
        scheduled: 10,
        skipped: 2,
        amountPaid: 1080,
      );

  /// Async accessor matching the UI's loading/error/empty pattern.
  /// Returns the local list; kept async so a future contract endpoint
  /// slots in without touching call sites.
  Future<List<Subscription>> fetchSubscriptions({ApiClient? client}) async {
    if (client?.token != null) {
      await const SessionStore().readToken();
    }
    return subscriptions();
  }
}
