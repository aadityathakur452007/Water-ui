import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/components/skleton/skelton.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/models/subscription_model.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/repositories/subscription_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/order/views/order_grouping.dart';
import 'package:shop/screens/order/views/order_tracking_screen.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/auth_service.dart';

/// Product thumbnail for an order line. Unknown productIds render a
/// water-drop placeholder instead of throwing.
class OrderItemThumbnail extends StatelessWidget {
  const OrderItemThumbnail({super.key, required this.productId, this.size = 48});

  final String productId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final product = const ProductRepository().tryById(productId);
    if (product == null) {
      return Container(
        height: size,
        width: size,
        decoration: const BoxDecoration(
          color: Color(0xFFEAF4FC),
          borderRadius:
              BorderRadius.all(Radius.circular(defaultBorderRadious / 2)),
        ),
        child: const Icon(Icons.water_drop_outlined,
            color: primaryColor, size: 24),
      );
    }
    return SizedBox(
      height: size,
      width: size,
      child: NetworkImageWithLoader(
        product.image,
        radius: defaultBorderRadious / 2,
      ),
    );
  }
}

class _OrdersPageData {
  const _OrdersPageData({
    required this.active,
    required this.delivered,
    required this.cancelled,
    required this.repeating,
  });

  final List<Order> active;
  final List<Order> delivered;
  final List<Order> cancelled;
  final List<Subscription> repeating;
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen(
      {super.key, this.initialOpenOrderId, this.showPlacedToast = false});

  /// Forwarded by EntryPoint when it consumes route args
  /// `{tab, openOrderId, showPlacedToast}` (parallel owner implements
  /// EntryPoint; this keeps the existing auto-open contract working
  /// whether the id arrives via constructor or via ModalRoute args).
  final String? initialOpenOrderId;
  final bool showPlacedToast;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _repo = const OrderRepository();
  final _subsRepo = const SubscriptionRepository();
  Future<_OrdersPageData>? _future;
  bool _offline = false;
  String? _openOrderId;
  bool _showToast = false;
  bool _autoOpened = false;
  bool _toastShown = false;

  @override
  void initState() {
    super.initState();
    _openOrderId = widget.initialOpenOrderId;
    _showToast = widget.showPlacedToast;
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Order id passed by the checkout success view via entry_point args
    // `{tab, openOrderId, showPlacedToast}` — when embedded in EntryPoint,
    // ModalRoute here IS the entry_point route, so its arguments carry
    // the forwarded id. Legacy `orderId` String/Map shapes still work.
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _openOrderId ??= args;
    } else if (args is Map) {
      final map = Map<String, dynamic>.from(args);
      if (_openOrderId == null) {
        final id = map['openOrderId'] ?? map['orderId'];
        if (id is String && id.isNotEmpty) _openOrderId = id;
      }
      if (!_showToast && map['showPlacedToast'] == true) {
        _showToast = true;
      }
    }
  }

  Future<_OrdersPageData> _load() async {
    List<Order> all;
    try {
      all = await _repo.fetchOrders();
      if (mounted) setState(() => _offline = false);
    } on AppException catch (e) {
      if (e.code == 'UNAUTHENTICATED') {
        await const AuthService().handleUnauthorized();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, logInScreenRoute, (_) => false);
        }
        rethrow;
      }
      // NETWORK-only fallback: other errors rethrow so the Retry
      // path surfaces them honestly.
      if (e.code != 'NETWORK') rethrow;
      if (mounted) setState(() => _offline = true);
      // Backend unreachable: show the bundled demo orders
      // so the screen still demonstrates the grouped list.
      all = [..._repo.ongoing(), ..._repo.past()];
    }
    List<Subscription> subs = const [];
    try {
      subs = await _subsRepo.fetchSubscriptions();
    } catch (_) {
      // Repeating block is additive — orders still render when
      // subscriptions fail.
      subs = const [];
    }
    final grouped = splitGrouped(all);
    return _OrdersPageData(
      active: grouped.active,
      delivered: grouped.delivered,
      cancelled: grouped.cancelled,
      repeating: subs,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {
      // Error surface stays with the FutureBuilder Retry path.
    }
  }

  /// Auto-opens the detail sheet for the just-placed order + shows the
  /// "Order placed" toast once. Runs after data arrives.
  void _maybeAutoOpenAndToast(_OrdersPageData data) {
    if (_showToast && !_toastShown) {
      _toastShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed — track it here')),
        );
      });
    }
    if (_autoOpened || _openOrderId == null) return;
    Order? match;
    for (final o in [...data.active, ...data.delivered, ...data.cancelled]) {
      if (o.id == _openOrderId) {
        match = o;
        break;
      }
    }
    _autoOpened = true;
    if (match == null || !mounted) return;
    final order = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      customModalBottomSheet(
        context,
        title: order.displayLabel,
        showClose: true,
        child: _OrderDetailSheet(order: order),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Orders"),
            if (_offline) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF4FC),
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, size: 12, color: primaryColor),
                    SizedBox(width: 4),
                    Text(
                      "Offline",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      body: FutureBuilder<_OrdersPageData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(defaultPadding),
              itemCount: 3,
              itemBuilder: (context, _) => const Padding(
                padding: EdgeInsets.only(bottom: defaultPadding),
                child: Skeleton(height: 120),
              ),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding * 1.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Could not load orders.",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Check your connection and try again.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: defaultPadding),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              ),
            );
          }
          final data = snap.data ??
              const _OrdersPageData(
                active: [],
                delivered: [],
                cancelled: [],
                repeating: [],
              );
          _maybeAutoOpenAndToast(data);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _GroupedOrdersList(data: data, onChanged: _refresh),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall!
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF4FC),
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedOrdersList extends StatefulWidget {
  const _GroupedOrdersList({required this.data, required this.onChanged});

  final _OrdersPageData data;
  final Future<void> Function() onChanged;

  @override
  State<_GroupedOrdersList> createState() => _GroupedOrdersListState();
}

class _GroupedOrdersListState extends State<_GroupedOrdersList> {
  final _repo = const OrderRepository();
  final _busy = <String>{};

  Future<void> _cancel(Order order) async {
    if (_busy.contains(order.id)) return;
    setState(() => _busy.add(order.id));
    try {
      await _repo.cancelOrder(order.id);
      await widget.onChanged();
    } on AppException catch (e) {
      if (e.code == 'UNAUTHENTICATED') {
        await const AuthService().handleUnauthorized();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, logInScreenRoute, (_) => false);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(order.id));
    }
  }

  void _openDetail(Order order) {
    customModalBottomSheet(
      context,
      title: order.displayLabel,
      showClose: true,
      child: _OrderDetailSheet(order: order),
    );
  }

  void _reorder(Order order) {
    // Reuses the existing cart-seeding contract: CartScreen rebuilds
    // lines from `Order.items` via the catalog (same as OrderAgain).
    Navigator.pushNamed(context, cartScreenRoute, arguments: order);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final allEmpty = data.active.isEmpty &&
        data.delivered.isEmpty &&
        data.cancelled.isEmpty &&
        data.repeating.isEmpty;
    if (allEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          const Center(child: Text("No orders yet")),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              "Active, delivered and cancelled orders will appear here.",
            ),
          ),
          const SizedBox(height: defaultPadding),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, discoverScreenRoute),
              child: const Text("Order water"),
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(defaultPadding),
      children: [
        _SectionHeader(
          title: 'Active & scheduled',
          count: data.active.length + data.repeating.length,
        ),
        if (data.repeating.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Text(
              'Repeating',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
          for (final sub in data.repeating) _RepeatingRow(sub: sub),
        ],
        if (data.active.isEmpty && data.repeating.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text("No active orders — you're all caught up."),
          )
        else
          for (final order in data.active)
            _OrderCard(
              order: order,
              cancelling: _busy.contains(order.id),
              onCancel: () => _cancel(order),
              onOpen: () => _openDetail(order),
              onReorder: null,
            ),
        _SectionHeader(title: 'Delivered', count: data.delivered.length),
        if (data.delivered.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text("Delivered orders will appear here."),
          )
        else
          for (final order in data.delivered)
            _OrderCard(
              order: order,
              cancelling: false,
              onCancel: null,
              onOpen: () => _openDetail(order),
              onReorder:
                  canReorder(order) ? () => _reorder(order) : null,
            ),
        _SectionHeader(title: 'Cancelled', count: data.cancelled.length),
        if (data.cancelled.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text("No cancelled orders."),
          )
        else
          for (final order in data.cancelled)
            _OrderCard(
              order: order,
              cancelling: false,
              onCancel: null,
              onOpen: () => _openDetail(order),
              onReorder:
                  canReorder(order) ? () => _reorder(order) : null,
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RepeatingRow extends StatelessWidget {
  const _RepeatingRow({required this.sub});

  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final paused = sub.status == SubscriptionStatus.paused;
    final status = subscriptionRowStatus(sub);
    final muted = paused;
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, subscriptionsScreenRoute),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: muted ? blackColor5 : Colors.white,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: const BorderRadius.all(
              Radius.circular(defaultBorderRadious)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderItemThumbnail(productId: sub.productId, size: 48),
            const SizedBox(width: defaultPadding / 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          sub.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall!
                              .copyWith(
                                fontWeight: FontWeight.w600,
                                color: muted ? blackColor60 : null,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SubStatusChip(label: status, paused: paused),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subscriptionRecurrenceLine(sub),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: muted ? blackColor60 : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Next: ${sub.nextDelivery.isEmpty ? sub.deliveryTime : sub.nextDelivery}',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: muted ? blackColor60 : null,
                        ),
                  ),
                  if (paused) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Paused — Resume in Regular Deliveries',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(
                            fontSize: 12,
                            color: blackColor60,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubStatusChip extends StatelessWidget {
  const _SubStatusChip({required this.label, required this.paused});

  final String label;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: paused ? blackColor10 : const Color(0xFFEAF4FC),
        borderRadius:
            const BorderRadius.all(Radius.circular(30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: paused ? blackColor60 : primaryColor,
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.cancelling,
    required this.onCancel,
    required this.onOpen,
    required this.onReorder,
  });

  final Order order;
  final bool cancelling;
  final VoidCallback? onCancel;
  final VoidCallback onOpen;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final failed = order.status == OrderStatus.notDelivered;
    final firstId = order.items.isEmpty ? '' : order.items.first.productId;
    final firstName =
        order.items.isEmpty ? order.displayLabel : order.items.first.name;
    final hasMore = order.items.length > 1;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: defaultPadding),
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: failed ? const Color(0xFFFFF5F5) : Colors.white,
          border: Border.all(
            color: failed ? errorColor : Theme.of(context).dividerColor,
          ),
          borderRadius: const BorderRadius.all(
              Radius.circular(defaultBorderRadious)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderItemThumbnail(productId: firstId, size: 56),
            const SizedBox(width: defaultPadding / 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          hasMore
                              ? '$firstName +${order.items.length - 1} more'
                              : firstName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall!
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusChip(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.itemsSummary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.deliverySlot,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        inr(order.totalAmount),
                        textAlign: TextAlign.right,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall!
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  if (failed) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Delivery failed — try reorder.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(
                            fontSize: 12,
                            color: const Color(0xFF8B1A1A),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onCancel != null)
                          TextButton(
                            onPressed:
                                cancelling ? null : onCancel,
                            child: Text(cancelling
                                ? "Cancelling..."
                                : "Cancel"),
                          ),
                        if (onReorder != null)
                          TextButton(
                            onPressed: onReorder,
                            child: const Text("Reorder"),
                          ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderTrackingScreen(order: order),
                            ),
                          ),
                          child: const Text("Track"),
                        ),
                        OutlinedButton(
                          onPressed: onOpen,
                          child: const Text("View"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      OrderStatus.scheduled => (
          blackColor5,
          blackColor60,
        ),
      OrderStatus.preparing => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      OrderStatus.outForDelivery || OrderStatus.active => (
          const Color(0xFFEAF4FC),
          primaryColor,
        ),
      OrderStatus.delivered => (
          const Color(0xFFE6F7ED),
          const Color(0xFF1B8C4A),
        ),
      OrderStatus.cancelled => (
          const Color(0xFFFDECEC),
          errorColor,
        ),
      OrderStatus.notDelivered => (
          const Color(0xFFF8D7D7),
          const Color(0xFF8B1A1A),
        ),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.all(Radius.circular(30)),
      ),
      child: Text(
        orderStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  const _OrderDetailSheet({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding * 1.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order.itemsSummary),
          Text("${inr(order.totalAmount)} · ${order.deliverySlot}"),
          const SizedBox(height: defaultPadding),
          for (final item in order.items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  OrderItemThumbnail(productId: item.productId, size: 40),
                  const SizedBox(width: defaultPadding / 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall!
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${item.qty} × ${inr(item.price)}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    inr(item.lineTotal),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: defaultPadding),
          // Library timeline (water-blue UiTheme comes from the root in
          // main.dart) — replaces the bespoke dot-row so tracking stays
          // consistent.
          UiTimeline(items: _timelineItems(order)),
          const SizedBox(height: defaultPadding),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(order: order),
                ),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Track on map'),
            ),
          ),
          const SizedBox(height: defaultPadding / 2),
          _PairFooter(order: order),
        ],
      ),
    );
  }

  static List<UiTimelineItem> _timelineItems(Order order) {
    final cancelled = order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.notDelivered;
    if (cancelled) {
      return const [
        UiTimelineItem(title: 'Ordered', subtitle: 'Confirmed'),
        UiTimelineItem(
          title: 'Cancelled',
          subtitle: 'This order was cancelled',
          color: errorColor,
        ),
      ];
    }
    const steps = ['Ordered', 'Preparing', 'Out for delivery', 'Delivered'];
    final doneThrough = switch (order.status) {
      OrderStatus.delivered => 4,
      OrderStatus.outForDelivery || OrderStatus.active => 3,
      OrderStatus.preparing => 2,
      _ => 1,
    };
    return [
      for (int i = 0; i < steps.length; i++)
        UiTimelineItem(
          title: steps[i],
          subtitle: i < doneThrough ? 'Done' : 'Pending',
          color: i < doneThrough ? primaryColor : blackColor20,
        ),
    ];
  }
}

/// Compact cross-sell footer inside the auto-opened detail sheet.
/// Moved here from the cart success view so the refill↔jar pair stays
/// reachable after the success view pushes straight to tabs.
class _PairFooter extends StatelessWidget {
  const _PairFooter({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final firstId = order.items.isEmpty ? '' : order.items.first.productId;
    final sibling = const ProductRepository().crossSellSibling(firstId);
    if (sibling == null) return const SizedBox.shrink();
    final needJar = sibling.unit == 'jar';
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4FC),
        borderRadius: BorderRadius.all(
            Radius.circular(defaultBorderRadious)),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 40,
            width: 40,
            child: NetworkImageWithLoader(
              sibling.image,
              radius: defaultBorderRadious / 2,
            ),
          ),
          const SizedBox(width: defaultPadding / 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needJar ? "Need the container?" : "Just need a refill?",
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  "${sibling.title} · ${inr(sibling.price)}",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              productDetailsScreenRoute,
              arguments: sibling.id,
            ),
            child: const Text("View"),
          ),
        ],
      ),
    );
  }
}
