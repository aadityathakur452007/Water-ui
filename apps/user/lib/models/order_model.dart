enum OrderType { oneTime, regular }

enum OrderStatus {
  scheduled,
  active,
  delivered,
  cancelled,
  notDelivered,
}

class DeliveryAddress {
  final String label;
  final String line;
  final String city;

  const DeliveryAddress({
    required this.label,
    required this.line,
    required this.city,
  });
}

const defaultAddress = DeliveryAddress(
  label: "Home",
  line: "123, Example Colony",
  city: "Bhopal",
);

class OrderItem {
  final String productId;
  final String name;
  final int qty;
  final double price;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
  });

  double get lineTotal => price * qty;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId']?.toString() ??
          json['product_id']?.toString() ??
          '',
      name: json['name']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Order {
  final String id;
  final List<OrderItem> items;
  final DeliveryAddress address;
  final OrderType orderType;
  final OrderStatus status;
  final double totalAmount;
  final String deliverySlot;
  final String createdAt;

  const Order({
    required this.id,
    required this.items,
    required this.address,
    required this.orderType,
    required this.status,
    required this.totalAmount,
    required this.deliverySlot,
    required this.createdAt,
  });

  String get itemsSummary =>
      items.map((e) => "${e.qty} × ${e.name}").join(", ");

  String get statusLabel => orderStatusLabel(status);

  /// Parses the backend order shape:
  /// `{id,type,status,total,slot,created_at,items,address}`.
  /// Unknown in-transit statuses (`preparing`, `out_for_delivery`)
  /// collapse to [OrderStatus.active] — the app only tracks
  /// scheduled / active / delivered / cancelled.
  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OrderItem>[];
    final rawAddress = json['address'];
    final address = rawAddress is Map
        ? DeliveryAddress(
            label: rawAddress['label']?.toString() ?? 'Home',
            line: rawAddress['line']?.toString() ?? '',
            city: rawAddress['city']?.toString() ?? '',
          )
        : defaultAddress;
    return Order(
      id: json['id']?.toString() ?? '',
      items: items,
      address: address,
      orderType: parseOrderType(json['type']?.toString()),
      status: parseOrderStatus(json['status']?.toString()),
      totalAmount: (json['total'] as num?)?.toDouble() ??
          (json['totalAmount'] as num?)?.toDouble() ??
          0,
      deliverySlot:
          json['slot']?.toString() ?? json['deliverySlot']?.toString() ?? '',
      createdAt:
          json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '',
    );
  }
}

OrderType parseOrderType(String? raw) {
  if (raw != null && raw.toLowerCase() == 'regular') {
    return OrderType.regular;
  }
  return OrderType.oneTime;
}

OrderStatus parseOrderStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'scheduled':
      return OrderStatus.scheduled;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
    case 'canceled':
      return OrderStatus.cancelled;
    case 'not_delivered':
      return OrderStatus.notDelivered;
    default:
      // preparing, out_for_delivery and any future in-transit state.
      return OrderStatus.active;
  }
}

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.scheduled:
      return "Scheduled";
    case OrderStatus.active:
      return "Active";
    case OrderStatus.delivered:
      return "Delivered";
    case OrderStatus.cancelled:
      return "Cancelled";
    case OrderStatus.notDelivered:
      return "Not Delivered";
  }
}
