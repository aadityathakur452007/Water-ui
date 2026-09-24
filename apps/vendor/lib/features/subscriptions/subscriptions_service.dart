import '../../core/api_client.dart';
import '../../core/session.dart';

/// GET /api/vendor/subscriptions -> stripped list (no user PII).
/// Read-only: the contract exposes no vendor mutation for subscriptions.
class VendorSubscription {
  VendorSubscription({
    required this.id,
    required this.quantity,
    required this.frequency,
    required this.status,
    required this.nextDelivery,
  });

  final String id;
  final int quantity;
  final String frequency;
  final String status;
  final String nextDelivery;

  factory VendorSubscription.fromJson(Map<String, dynamic> json) =>
      VendorSubscription(
        id: '${json['id'] ?? ''}',
        quantity: (json['quantity'] as num? ?? 0).toInt(),
        frequency: '${json['frequency'] ?? ''}',
        status: '${json['status'] ?? ''}',
        nextDelivery:
            '${json['next_delivery'] ?? json['nextDelivery'] ?? ''}',
      );
}

class SubscriptionsService {
  SubscriptionsService(this._api, this._session);

  final ApiClient _api;
  final Session _session;

  Future<List<VendorSubscription>> fetchSubscriptions() async {
    final body =
        await _api.get('/api/vendor/subscriptions', token: _session.token);
    final list = body is List ? body : (body as Map)['subscriptions'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(VendorSubscription.fromJson)
        .toList();
  }
}
