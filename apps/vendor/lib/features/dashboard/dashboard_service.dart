import '../../core/api_client.dart';
import '../../core/session.dart';

/// GET /api/vendor/kpis -> {todayDeliveries, todayRevenue,
/// activeSubscriptions, pendingOrders}.
class VendorKpis {
  VendorKpis({
    required this.todayDeliveries,
    required this.todayRevenue,
    required this.activeSubscriptions,
    required this.pendingOrders,
  });

  final int todayDeliveries;
  final num todayRevenue;
  final int activeSubscriptions;
  final int pendingOrders;

  factory VendorKpis.fromJson(Map<String, dynamic> json) => VendorKpis(
        todayDeliveries: (json['todayDeliveries'] as num? ?? 0).toInt(),
        todayRevenue: json['todayRevenue'] as num? ?? 0,
        activeSubscriptions:
            (json['activeSubscriptions'] as num? ?? 0).toInt(),
        pendingOrders: (json['pendingOrders'] as num? ?? 0).toInt(),
      );
}

class DashboardService {
  DashboardService(this._api, this._session);

  final ApiClient _api;
  final Session _session;

  Future<VendorKpis> fetchKpis() async {
    final body = await _api.get('/api/vendor/kpis', token: _session.token);
    return VendorKpis.fromJson(body as Map<String, dynamic>);
  }
}
