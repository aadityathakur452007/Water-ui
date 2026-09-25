import '../config/app_config.dart';
import '../models/subscription_model.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

/// Subscription source for the Home "active delivery" card and
/// subscription management.
///
/// NOTE: the backend DOES ship user subscription endpoints
/// (`GET`/`POST`/`PATCH /api/subscriptions` — backend/src/index.ts:449-451),
/// so live mode talks HTTP; demo mode serves the bundled list (no network).
class SubscriptionRepository {
  const SubscriptionRepository();

  Subscription? activeDelivery() => const Subscription(
        id: "SUB-042",
        productId: "wd-20l",
        productName: "20L Drinking Water Jar",
        quantity: 2,
        frequency: Frequency.everyDay,
        startDate: "25 September 2026",
        deliveryTime: "8:00 AM",
        status: SubscriptionStatus.active,
        nextDelivery: "Tomorrow • 8:00 AM",
      );

  List<Subscription> subscriptions() => [
        if (activeDelivery() != null) activeDelivery()!,
      ];

  DeliveryProgress septemberProgress() => const DeliveryProgress(
        delivered: 18,
        scheduled: 10,
        skipped: 2,
        amountPaid: 1080,
      );

  /// Async accessor matching the UI's loading/error/empty pattern.
  /// Demo mode serves the bundled list (no network); live mode reads
  /// `GET /api/subscriptions` (own rows, empty list is valid).
  Future<List<Subscription>> fetchSubscriptions({ApiClient? client}) async {
    if (AppConfig.demoMode && client == null) return subscriptions();
    final api = await _client(client);
    final body = await api.get('/api/subscriptions');
    final list = body is List ? body : (body as Map)['subscriptions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) =>
            Subscription.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ApiClient> _remote() async {
    final token = await const SessionStore().readToken();
    return ApiClient(token: token);
  }

  /// `POST /api/subscriptions` — live mode only (demo seed covers demo).
  Future<Subscription> createRemote({
    required String productId,
    required int quantity,
    required Frequency frequency,
    required String startDate,
    required String deliveryTime,
    ApiClient? client,
  }) {
    return createRemoteRaw(
      productId: productId,
      quantity: quantity,
      frequency: frequencyToWire(frequency),
      startDate: startDate,
      deliveryTime: deliveryTime,
      client: client,
    );
  }

  /// Raw-string variant for callers holding wire values (e.g. cart args).
  Future<Subscription> createRemoteRaw({
    required String productId,
    required int quantity,
    required String frequency,
    required String startDate,
    required String deliveryTime,
    ApiClient? client,
  }) async {
    final api = client ?? await _remote();
    final body = await api.post('/api/subscriptions', body: {
      'productId': productId,
      'quantity': quantity,
      'frequency': frequency,
      'startDate': startDate,
      'deliveryTime': deliveryTime,
    });
    return Subscription.fromJson(
        Map<String, dynamic>.from(body as Map));
  }

  /// `PATCH /api/subscriptions/:id` — live mode only.
  Future<Subscription> updateRemote(
    String id, {
    int? quantity,
    Frequency? frequency,
    String? deliveryTime,
    SubscriptionStatus? status,
    bool? skipNext,
    ApiClient? client,
  }) async {
    final api = client ?? await _remote();
    final body = await api.patch('/api/subscriptions/$id', body: {
      if (quantity != null) 'quantity': quantity,
      if (frequency != null) 'frequency': frequencyToWire(frequency),
      if (deliveryTime != null) 'deliveryTime': deliveryTime,
      if (status != null)
        'status': status == SubscriptionStatus.paused ? 'paused' : 'active',
      if (skipNext != null) 'skipNext': skipNext,
    });
    return Subscription.fromJson(
        Map<String, dynamic>.from(body as Map));
  }

  Future<ApiClient> _client(ApiClient? client) async {
    if (client != null) return client;
    final token = await const SessionStore().readToken();
    return ApiClient(token: token);
  }
}
