// PII RULE (contract, enforced server-side AND asserted here):
// Vendor order payloads NEVER contain user name/phone/email. This model
// deliberately has NO user fields — only order id, items (name/qty/price),
// totals, delivery address (label/line/city), slot, status, type,
// timestamps. The UI must never expect or render user PII; if the backend
// ever leaks extra keys, fromJson ignores them.

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

  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    // Address may arrive flat or nested — accept both, never user fields.
    final addr = json['address'];
    final Map<String, dynamic> a =
        addr is Map<String, dynamic> ? addr : json;
    final items = json['items'];
    return VendorOrder(
      id: '${json['id'] ?? ''}',
      items: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(VendorOrderItem.fromJson)
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
    );
  }
}
