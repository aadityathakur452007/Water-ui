import 'package:flutter/material.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/order_process.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const repo = OrderRepository();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Orders"),
          bottom: const TabBar(
            tabs: [Tab(text: "ONGOING"), Tab(text: "PAST")],
          ),
        ),
        body: TabBarView(
          children: [
            _OrderList(orders: repo.ongoing()),
            _OrderList(orders: repo.past()),
          ],
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
    final bool delivered = order.status == OrderStatus.delivered;
    final bool cancelled = order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.notDelivered;
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
          Text(
              "${inr(order.totalAmount)} · ${order.deliverySlot}"),
          const SizedBox(height: defaultPadding),
          OrderProgress(
            orderStatus: OrderProcessStatus.done,
            processingStatus: OrderProcessStatus.done,
            packedStatus: delivered || !cancelled
                ? OrderProcessStatus.done
                : OrderProcessStatus.notDoneYeat,
            shippedStatus: delivered
                ? OrderProcessStatus.done
                : cancelled
                    ? OrderProcessStatus.error
                    : OrderProcessStatus.processing,
            deliveredStatus: delivered
                ? OrderProcessStatus.done
                : OrderProcessStatus.notDoneYeat,
            isCanceled: cancelled,
          ),
          const SizedBox(height: defaultPadding),
        ],
      ),
    );
  }
}
