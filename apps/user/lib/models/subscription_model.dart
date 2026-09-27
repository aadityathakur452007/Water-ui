enum Frequency { everyDay, alternateDays, specificDays, weekly, onceAWeek }

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
  final bool skipNext;
  final String days;

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
    this.skipNext = false,
    this.days = '',
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
        return "Weekly";
      case Frequency.onceAWeek:
        return "Once a Week";
    }
  }

  Subscription copyWith({
    int? quantity,
    Frequency? frequency,
    String? deliveryTime,
    SubscriptionStatus? status,
    String? nextDelivery,
    bool? skipNext,
    String? days,
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
      skipNext: skipNext ?? this.skipNext,
      days: days ?? this.days,
    );
  }

  /// Pretty display for the optional `days` wire value ("Mon,Wed,Fri" →
  /// "Mon, Wed, Fri"). Empty when no days are set — callers show nothing.
  String get daysLabel {
    final parts = days.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    return parts.map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase()).join(', ');
  }

  /// Wire map for POST/PATCH update paths (backend accepts snake/camel;
  /// `days` is the shared key, omitted when empty).
  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'frequency': frequencyToWire(frequency),
        'start_date': startDate,
        'delivery_time': deliveryTime,
        'status': status == SubscriptionStatus.paused ? 'paused' : 'active',
        'next_delivery': nextDelivery,
        'skip_next': skipNext,
        if (days.isNotEmpty) 'days': days,
      };

  /// Parses the backend subscription row:
  /// `{id,product_id,quantity,frequency,start_date,delivery_time,
  /// status,next_delivery,days}`. Served by GET/POST/PATCH /api/subscriptions
  /// (backend/src/app.ts; absent from the frozen contract doc).
  /// `days` is optional display text (wire key `days`, e.g. "Mon,Wed,Fri").
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
      skipNext: json['skip_next'] == 1 ||
          json['skip_next'] == true ||
          json['skipNext'] == true,
      days: (json['days'] ?? json['Days'])?.toString() ?? '',
    );
  }
}

/// Wire value for [Frequency] (backend `SUB_FREQUENCIES` set).
String frequencyToWire(Frequency f) {
  switch (f) {
    case Frequency.everyDay:
      return 'every_day';
    case Frequency.alternateDays:
      return 'alternate_days';
    case Frequency.specificDays:
      return 'specific_days';
    case Frequency.weekly:
      return 'weekly';
    case Frequency.onceAWeek:
      return 'once_a_week';
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
      return Frequency.weekly;
    case 'once_a_week':
      return Frequency.onceAWeek;
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
