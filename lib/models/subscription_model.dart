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

  Subscription copyWith({
    int? quantity,
    Frequency? frequency,
    String? deliveryTime,
    SubscriptionStatus? status,
    String? nextDelivery,
  }) {
    return Subscription(
      id: id,
      productId: productId,
      productName: productName,
      quantity: quantity ?? this.quantity,
      frequency: frequency ?? this.frequency,
      startDate: startDate,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      status: status ?? this.status,
      nextDelivery: nextDelivery ?? this.nextDelivery,
    );
  }
}

class DeliveryProgress {
  final int delivered;
  final int scheduled;
  final int skipped;
  final double amountPaid;

  const DeliveryProgress({
    required this.delivered,
    required this.scheduled,
    required this.skipped,
    required this.amountPaid,
  });

  int get total => delivered + scheduled + skipped;
}
