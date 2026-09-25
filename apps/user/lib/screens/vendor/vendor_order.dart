// PII RULE (contract, user-approved amendment): vendor order payloads MAY
// contain the customer identity as a nested `customer: {name, phone, email}`
// map. Absent/null-tolerant — old rows without it hide the customer card.
// No other user fields are expected; unknown extra keys are ignored.

/// Allowed PATCH transitions (contract):
/// scheduled -> preparing -> out_for_delivery -> delivered, any -> cancelled.
String? nextStatus(String status) => switch (status) {
      'scheduled' => 'preparing',
      'preparing' => 'out_for_delivery',
      'out_for_delivery' => 'delivered',
      _ => null,
    };

String nextStatusLabel(String status) => switch (status) {
      'scheduled' => 'Start preparing',
      'preparing' => 'Mark out for delivery',
      'out_for_delivery' => 'Mark delivered',
      _ => 'Advance',
    };

class VendorOrderItem {
  VendorOrderItem(
      {required this.name, required this.qty, required this.price});

  final String name;
  final int qty;
  final num price;

  factory VendorOrderItem.fromJson(Map<String, dynamic> json) =>
      VendorOrderItem(
        name: '${json['name'] ?? ''}',
        qty: (json['qty'] as num? ?? 0).toInt(),
        price: json['price'] as num? ?? 0,
      );
}

class VendorOrder {
  VendorOrder({
    required this.id,
    required this.items,
    required this.total,
    required this.addressLabel,
    required this.addressLine,
    required this.addressCity,
    required this.slot,
    required this.status,
    required this.type,
    required this.createdAt,
    this.customerName = '',
    this.customerPhone = '',
    this.customerEmail = '',
  });

  final String id;
  final List<VendorOrderItem> items;
  final num total;
  final String addressLabel;
  final String addressLine;
  final String addressCity;
  final String slot;
  final String status;
  final String type;
  final String createdAt;
  final String customerName;
  final String customerPhone;
  final String customerEmail;

  /// True when at least one customer field is present (controls whether
  /// the UI shows the customer card).
  bool get hasCustomer =>
      customerName.isNotEmpty ||
      customerPhone.isNotEmpty ||
      customerEmail.isNotEmpty;

  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    // Address may arrive flat or nested — accept both.
    final addr = json['address'];
    final Map<String, dynamic> a =
        addr is Map<String, dynamic> ? addr : json;
    // Customer is a nested map (absent/null-tolerant — old rows hide it).
    final cust = json['customer'];
    final Map<String, dynamic> c =
        cust is Map<String, dynamic> ? cust : const {};
    final items = json['items'];
    return VendorOrder(
      id: '${json['id'] ?? ''}',
      items: items is List
          ? items
              .whereType<Map>()
              .map((e) => VendorOrderItem.fromJson(
                  Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      total: json['total'] as num? ?? 0,
      addressLabel: '${a['label'] ?? ''}',
      addressLine: '${a['line'] ?? ''}',
      addressCity: '${a['city'] ?? ''}',
      slot: '${json['slot'] ?? ''}',
      status: '${json['status'] ?? ''}',
      type: '${json['type'] ?? ''}',
      createdAt: '${json['createdAt'] ?? json['created_at'] ?? ''}',
      customerName: '${c['name'] ?? ''}',
      customerPhone: '${c['phone'] ?? ''}',
      customerEmail: '${c['email'] ?? ''}',
    );
  }
}
