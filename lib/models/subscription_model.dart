enum Frequency { everyDay, alternateDays, specificDays, weekly }

enum SubscriptionStatus { active, paused }

class Subscription {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final Frequency frequency;
  final String startDate;
  final String deliveryTime;
  final SubscriptionStatus status;
  final String nextDelivery;

  const Subscription({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.frequency,
    required this.startDate,
    required this.deliveryTime,
    required this.status,
    required this.nextDelivery,
  });

  String get frequencyLabel {
    switch (frequency) {
      case Frequency.everyDay:
        return "Every Day";
      case Frequency.alternateDays:
        return "Alternate Days";
      case Frequency.specificDays:
        return "Specific Days";
      case Frequency.weekly:
        return "Once a Week";
    }
  }
}
