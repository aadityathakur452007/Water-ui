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
