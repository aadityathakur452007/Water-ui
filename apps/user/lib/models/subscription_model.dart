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

  /// Parses the backend subscription row:
  /// `{id,product_id,quantity,frequency,start_date,delivery_time,
  /// status,next_delivery}`. No user-facing endpoint ships in the frozen
  /// contract yet — this exists so the repository can adopt one without
  /// touching call sites.
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ??
          json['productId']?.toString() ??
          '',
      productName: json['product_name']?.toString() ??
          json['productName']?.toString() ??
          json['product_id']?.toString() ??
          '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      frequency: parseFrequency(json['frequency']?.toString()),
      startDate: json['start_date']?.toString() ??
          json['startDate']?.toString() ??
          '',
      deliveryTime: json['delivery_time']?.toString() ??
          json['deliveryTime']?.toString() ??
          '',
      status: parseSubscriptionStatus(json['status']?.toString()),
      nextDelivery: json['next_delivery']?.toString() ??
          json['nextDelivery']?.toString() ??
          '',
    );
  }
}

Frequency parseFrequency(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'alternatedays':
    case 'alternate_days':
      return Frequency.alternateDays;
    case 'specificdays':
    case 'specific_days':
      return Frequency.specificDays;
    case 'weekly':
    case 'once_a_week':
      return Frequency.weekly;
    default:
      return Frequency.everyDay;
  }
}

SubscriptionStatus parseSubscriptionStatus(String? raw) {
  if (raw != null && raw.toLowerCase() == 'paused') {
    return SubscriptionStatus.paused;
  }
  return SubscriptionStatus.active;
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
