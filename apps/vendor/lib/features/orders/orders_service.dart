import '../../core/api_client.dart';
import '../../core/session.dart';
import 'order_model.dart';

/// GET /api/vendor/orders?status= and PATCH /api/vendor/orders/:id {status}.
class OrdersService {
  OrdersService(this._api, this._session);

  final ApiClient _api;
  final Session _session;

  Future<List<VendorOrder>> fetchOrders({String? status}) async {
    final path =
        status == null || status.isEmpty || status == 'all'
            ? '/api/vendor/orders'
            : '/api/vendor/orders?status=$status';
    final body = await _api.get(path, token: _session.token);
    final list = body is List ? body : (body as Map<String, dynamic>)['orders'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(VendorOrder.fromJson)
        .toList();
  }

  Future<void> updateStatus(String id, String status) async {
    await _api.patch('/api/vendor/orders/$id', {'status': status},
        token: _session.token);
  }
}
