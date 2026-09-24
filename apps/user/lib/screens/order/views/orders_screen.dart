import 'package:flutter/material.dart';
import 'package:flutter_ui_collection/flutter_ui_collection.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/skleton/skelton.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/services/api_client.dart';

/// Water-blue tokens scoped ONLY to the library timeline widget.
/// The app keeps its Material theme; this wrapper just satisfies
/// `UiTheme.of` with flat, glow-free, gradient-free values.
UiThemeData _waterUiTheme() {
  final base = MinimalTheme.light;
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: primaryColor,
      success: successColor,
      error: errorColor,
    ),
    useGlow: false,
    useGradients: false,
    useShadows: false,
  );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _repo = const OrderRepository();
  Future<({List<Order> ongoing, List<Order> past})>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({List<Order> ongoing, List<Order> past})> _load() async {
    try {
      final remote = await _repo.fetchOrders();
      return _split(remote);
    } on AppException {
      // Backend unreachable / logged out: show the bundled demo orders
      // so the screen still demonstrates ongoing vs past.
      return (ongoing: _repo.ongoing(), past: _repo.past());
    }
  }

  static ({List<Order> ongoing, List<Order> past}) _split(List<Order> all) {
    final ongoing = <Order>[];
    final past = <Order>[];
    for (final o in all) {
      if (o.status == OrderStatus.scheduled ||
          o.status == OrderStatus.active) {
        ongoing.add(o);
      } else {
        past.add(o);
      }
    }
    return (ongoing: ongoing, past: past);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Orders"),
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
            return TabBarView(
              children: [
                _OrderList(orders: data.ongoing),
                _OrderList(orders: data.past),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(child: Text("No orders yet"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
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
                  Text("#${order.id}",
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(fontWeight: FontWeight.w600)),
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
                child: OutlinedButton(
                  onPressed: () => customModalBottomSheet(
                    context,
                    child: _OrderDetailSheet(order: order),
                  ),
                  child: const Text("View"),
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
            status == OrderStatus.scheduled
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
          Text("Order #${order.id}",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(order.itemsSummary),
          Text("${inr(order.totalAmount)} · ${order.deliverySlot}"),
          const SizedBox(height: defaultPadding),
          // Library timeline (water-blue tokens above) — replaces the
          // bespoke dot-row so tracking stays consistent.
          UiTheme(
            data: _waterUiTheme(),
            child: UiTimeline(items: _timelineItems(order)),
          ),
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
    const steps = ['Ordered', 'Packed', 'Shipped', 'Delivered'];
    final doneThrough = switch (order.status) {
      OrderStatus.delivered => 4,
      OrderStatus.active => 2,
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
