enum OrderType { oneTime, regular }

enum OrderStatus {
  scheduled,
  preparing,
  outForDelivery,
  active,
  delivered,
  cancelled,
  notDelivered,
}

class DeliveryAddress {
  final String label;
  final String line;
  final String city;
  final String? house;
  final String? street;
  final String? area;
  final String? pincode;
  final String? phone;
  final double? lat;
  final double? lng;

  const DeliveryAddress({
    required this.label,
    required this.line,
    required this.city,
    this.house,
    this.street,
    this.area,
    this.pincode,
    this.phone,
    this.lat,
    this.lng,
  });

  /// Full address line: extended parts when present, else legacy [line].
  String get displayLine {
    final parts = [house, street, area]
        .where((e) => e?.trim().isNotEmpty ?? false)
        .map((e) => e!.trim())
        .toList();
    return parts.isEmpty ? line : parts.join(', ');
  }

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    double? numOrNull(dynamic v) {
      if (v == null || (v is String && v.trim().isEmpty)) return null;
      return (v as num?)?.toDouble() ?? double.tryParse(v.toString());
    }

    String? strOrNull(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return DeliveryAddress(
      label: json['label']?.toString() ?? 'Home',
      line: json['line']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      house: strOrNull(json['house']),
      street: strOrNull(json['street']),
      area: strOrNull(json['area']),
      pincode: strOrNull(json['pincode']),
      phone: strOrNull(json['phone']),
      lat: numOrNull(json['lat']),
      lng: numOrNull(json['lng']),
    );
  }
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

  /// Friendly one-line label used in the success view, order rows and
  /// the order detail sheet instead of a raw `#id`.
  /// Format: `Order #<id> · <n> items · <slot>` (n = total quantity).
  String get displayLabel {
    final count = items.fold<int>(0, (sum, e) => sum + e.qty);
    return "Order #$id · $count ${count == 1 ? 'item' : 'items'} · $deliverySlot";
  }

  /// Returns a copy with the given fields replaced (demo order-book
  /// uses this to mark orders cancelled without mutating seed data).
  Order copyWith({OrderStatus? status}) {
    return Order(
      id: id,
      items: items,
      address: address,
      orderType: orderType,
      status: status ?? this.status,
      totalAmount: totalAmount,
      deliverySlot: deliverySlot,
      createdAt: createdAt,
    );
  }

  /// Parses the backend order shape:
  /// `{id,type,status,total,slot,created_at,items,address}`.
  /// Vendor lifecycle maps 1:1 (`scheduled→preparing→out_for_delivery
  /// →delivered`); only unknown future in-transit states fall back to
  /// [OrderStatus.active]. (Vendor side uses a separate VendorOrder
  /// model — unaffected.)
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
        ? DeliveryAddress.fromJson(
            Map<String, dynamic>.from(rawAddress))
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
    case 'preparing':
      return OrderStatus.preparing;
    case 'out_for_delivery':
      return OrderStatus.outForDelivery;
    case 'active':
      return OrderStatus.active;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
    case 'canceled':
      return OrderStatus.cancelled;
    case 'not_delivered':
      return OrderStatus.notDelivered;
    default:
      // Unknown future in-transit state.
      return OrderStatus.active;
  }
}

String orderStatusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.scheduled:
      return "Scheduled";
    case OrderStatus.preparing:
      return "Preparing";
    case OrderStatus.outForDelivery:
      return "Out for delivery";
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
