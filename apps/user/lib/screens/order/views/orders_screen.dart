import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/skleton/skelton.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/auth_service.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _repo = const OrderRepository();
  Future<({List<Order> ongoing, List<Order> past})>? _future;
  bool _offline = false;
  String? _openOrderId;
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Order id passed by the checkout success view (pushReplacement).
    // Read from the route itself so no router change is needed.
    if (_openOrderId == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.isNotEmpty) {
        _openOrderId = args;
      } else if (args is Map && args['orderId'] is String) {
        _openOrderId = args['orderId'] as String;
      }
    }
  }

  Future<({List<Order> ongoing, List<Order> past})> _load() async {
    try {
      final remote = await _repo.fetchOrders();
      if (mounted) setState(() => _offline = false);
      return _split(remote);
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
      // so the screen still demonstrates ongoing vs past.
      return (ongoing: _repo.ongoing(), past: _repo.past());
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {
      // Error surface stays with the FutureBuilder Retry path.
    }
  }

  static ({List<Order> ongoing, List<Order> past}) _split(List<Order> all) {
    final ongoing = <Order>[];
    final past = <Order>[];
    for (final o in all) {
      if (o.status == OrderStatus.scheduled ||
          o.status == OrderStatus.preparing ||
          o.status == OrderStatus.outForDelivery ||
          o.status == OrderStatus.active) {
        ongoing.add(o);
      } else {
        past.add(o);
      }
    }
    return (ongoing: ongoing, past: past);
  }

  /// Auto-opens the detail sheet for the just-placed order (id passed
  /// by the checkout success view). Runs once, after data arrives.
  void _maybeAutoOpen(List<Order> all) {
    if (_autoOpened || _openOrderId == null) return;
    Order? match;
    for (final o in all) {
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text("Orders"),
              if (_offline) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF4FC),
                    borderRadius:
                        BorderRadius.all(Radius.circular(30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 12, color: primaryColor),
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
          bottom: const TabBar(
            tabs: [Tab(text: "ONGOING"), Tab(text: "PAST")],
          ),
        ),
        body: FutureBuilder<({List<Order> ongoing, List<Order> past})>(
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
                        onPressed: () =>
                            setState(() => _future = _load()),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snap.data ??
                (ongoing: const <Order>[], past: const <Order>[]);
            _maybeAutoOpen([...data.ongoing, ...data.past]);
            return TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: _OrderList(
                    orders: data.ongoing,
                    onChanged: _refresh,
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: _OrderList(
                    orders: data.past,
                    onChanged: _refresh,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatefulWidget {
  const _OrderList({required this.orders, required this.onChanged});

  final List<Order> orders;
  final Future<void> Function() onChanged;

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
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

  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          const Center(child: Text("No orders yet")),
          const SizedBox(height: defaultPadding),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 36),
              ),
              onPressed: () => Navigator.pushNamed(
                  context, discoverScreenRoute),
              child: const Text("Order water"),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final cancelling = _busy.contains(order.id);
        return Container(
          margin: const EdgeInsets.only(bottom: defaultPadding),
          padding: const EdgeInsets.all(defaultPadding),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: const BorderRadius.all(
                Radius.circular(defaultBorderRadious)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(order.displayLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall!
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  _StatusDot(status: order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(order.itemsSummary,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 2),
              Text(
                "${inr(order.totalAmount)} · ${order.deliverySlot}",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (order.status == OrderStatus.scheduled)
                      TextButton(
                        onPressed:
                            cancelling ? null : () => _cancel(order),
                        child: Text(cancelling
                            ? "Cancelling..."
                            : "Cancel"),
                      ),
                    OutlinedButton(
                      onPressed: () => customModalBottomSheet(
                        context,
                        title: order.displayLabel,
                        showClose: true,
                        child: _OrderDetailSheet(order: order),
                      ),
                      child: const Text("View"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = status == OrderStatus.delivered ||
            status == OrderStatus.active ||
            status == OrderStatus.scheduled ||
            status == OrderStatus.preparing ||
            status == OrderStatus.outForDelivery
        ? successColor
        : errorColor;
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          orderStatusLabel(status),
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
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
          // Library timeline (water-blue UiTheme comes from the root in
          // main.dart) — replaces the bespoke dot-row so tracking stays
          // consistent.
          UiTimeline(items: _timelineItems(order)),
          const SizedBox(height: defaultPadding),
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
