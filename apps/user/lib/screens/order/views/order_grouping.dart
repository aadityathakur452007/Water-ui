import 'package:shop/models/order_model.dart';
import 'package:shop/models/subscription_model.dart';

/// Grouping helpers for the single grouped orders list.
///
/// Buckets (by status only — order type never affects the bucket):
/// - active: scheduled, preparing, outForDelivery, active
/// - delivered: delivered
/// - cancelled: cancelled + notDelivered (failed deliveries live here
///   with a distinct card treatment + Reorder).
({List<Order> active, List<Order> delivered, List<Order> cancelled})
    splitGrouped(List<Order> all) {
  final active = <Order>[];
  final delivered = <Order>[];
  final cancelled = <Order>[];
  for (final o in all) {
    switch (o.status) {
      case OrderStatus.scheduled:
      case OrderStatus.preparing:
      case OrderStatus.outForDelivery:
      case OrderStatus.active:
        active.add(o);
        break;
      case OrderStatus.delivered:
        delivered.add(o);
        break;
      case OrderStatus.cancelled:
      case OrderStatus.notDelivered:
        cancelled.add(o);
        break;
    }
  }
  return (active: active, delivered: delivered, cancelled: cancelled);
}

bool isActiveOrderStatus(OrderStatus s) =>
    s == OrderStatus.scheduled ||
    s == OrderStatus.preparing ||
    s == OrderStatus.outForDelivery ||
    s == OrderStatus.active;

/// One-time past rows get a Reorder action (seeds cart via the existing
/// `Navigator.pushNamed(cart, arguments: order)` pattern — no new cart APIs).
bool canReorder(Order order) {
  final past = order.status == OrderStatus.delivered ||
      order.status == OrderStatus.cancelled ||
      order.status == OrderStatus.notDelivered;
  return past && order.orderType == OrderType.oneTime;
}

/// Recurrence line for the Repeating block, built from the existing
/// [Subscription.frequencyLabel] + [Subscription.daysLabel].
/// e.g. "Every Day · Mon, Wed, Fri · continues this week" or
/// "Every Day · continues this week" when no days are set.
String subscriptionRecurrenceLine(Subscription sub) {
  final days = sub.daysLabel;
  if (days.isEmpty) return '${sub.frequencyLabel} · continues this week';
  return '${sub.frequencyLabel} · $days · continues this week';
}

/// Row status for the Repeating block: Paused / Next skipped / Active.
String subscriptionRowStatus(Subscription sub) {
  if (sub.status == SubscriptionStatus.paused) return 'Paused';
  if (sub.skipNext) return 'Next skipped';
  return 'Active';
}
