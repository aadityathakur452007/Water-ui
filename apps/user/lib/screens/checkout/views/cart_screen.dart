import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';

enum _Payment { cod, upi }

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _products = const ProductRepository();
  final _orders = const OrderRepository();

  late List<CartItem> _items;
  bool _seeded = false;
  OrderType _orderType = OrderType.oneTime;
  _Payment _payment = _Payment.cod;
  Order? _placed;
  bool _placing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Order) {
      // Reorder: rebuild cart lines from the order via the catalog.
      _items = args.items
          .map((e) => CartItem(
              product: _products.byId(e.productId), qty: e.qty))
          .toList();
    } else if (args is Map) {
      // Fresh flow from order-type / subscription config.
      final map = Map<String, dynamic>.from(args);
      final product =
          _products.byId(map['productId'] as String? ?? "wd-20l");
      _items = [CartItem(product: product, qty: map['qty'] as int? ?? 1)];
      if (map['orderType'] == 'regular') {
        _orderType = OrderType.regular;
      }
    } else {
      _items = [
        CartItem(product: _products.byId("wd-20l"), qty: 2),
      ];
    }
  }

  double get _subtotal =>
      _items.fold(0, (sum, e) => sum + e.lineTotal);
  double get _total =>
      _subtotal + (_items.isEmpty ? 0 : Cart.deliveryFee);

  String get _slot => _orderType == OrderType.oneTime
      ? "Today • 8:00 AM"
      : "Every Day • 8:00 AM";

  Future<void> _placeOrder() async {
    if (_items.isEmpty || _placing) return;
    setState(() => _placing = true);
    final lines = _items
        .map((e) => OrderItem(
              productId: e.product.id,
              name: e.product.title,
              qty: e.qty,
              price: e.product.price,
            ))
        .toList();
    try {
      // Real API first (`POST /api/orders`); offline falls back to the
      // local confirmation so checkout still demonstrates the flow.
      final remote = await _orders.createOrder(
        items: lines,
        slot: _slot,
        orderType: _orderType,
      );
      if (mounted) setState(() => _placed = remote);
    } on AppException {
      if (mounted) {
        setState(() {
          _placed = _orders.placeOrder(
            items: lines,
            total: _total,
            orderType: _orderType,
            deliverySlot: _slot,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_placed != null) return _SuccessView(order: _placed!);
    return Scaffold(
      appBar: AppBar(title: const Text("Checkout")),
      bottomNavigationBar: CartButton(
        price: _total,
        title: _placing ? "Placing..." : "Place Order",
        subTitle: "Total amount",
        press: _items.isEmpty ? () {} : _placeOrder,
      ),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          _sectionTitle(context, "Order Summary"),
          ..._items.map(_cartRow),
          const Divider(height: defaultPadding * 2),
          _moneyRow(context, "Delivery Fee", inr(Cart.deliveryFee)),
          const SizedBox(height: 4),
          _moneyRow(
            context,
            "Total",
            inr(_total),
            isTotal: true,
          ),
          const SizedBox(height: defaultPadding),
          _sectionTitle(context, "Delivery"),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _typeCard(
                  context,
                  icon: "assets/icons/Delivery.svg",
                  title: "One Time",
                  subtitle: "Today • 8:00 AM",
                  selected: _orderType == OrderType.oneTime,
                  onTap: () =>
                      setState(() => _orderType = OrderType.oneTime),
                ),
              ),
              const SizedBox(width: defaultPadding / 2),
              Expanded(
                child: _typeCard(
                  context,
                  icon: "assets/icons/Calender.svg",
                  title: "Regular",
                  subtitle: "Every Day • 8:00 AM",
                  selected: _orderType == OrderType.regular,
                  onTap: () =>
                      setState(() => _orderType = OrderType.regular),
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          _sectionTitle(context, "Delivery Address"),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: const BorderRadius.all(
                  Radius.circular(defaultBorderRadious)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "${defaultAddress.label}\n${defaultAddress.line}\n${defaultAddress.city}",
                    style: const TextStyle(height: 1.5),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(
                      context, addressesScreenRoute),
                  child: const Text("Change"),
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultPadding),
          _sectionTitle(context, "Payment"),
          RadioGroup<_Payment>(
            groupValue: _payment,
            onChanged: (v) => setState(() => _payment = v ?? _Payment.cod),
            child: const Column(
              children: [
                RadioListTile<_Payment>(
                  value: _Payment.cod,
                  title: Text("Cash on Delivery"),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<_Payment>(
                  value: _Payment.upi,
                  title: Text("UPI"),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            height: 48,
            width: 48,
            child: NetworkImageWithLoader(
              item.product.image,
              radius: defaultBorderRadious / 2,
            ),
          ),
          const SizedBox(width: defaultPadding / 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  "${inr(item.product.price)} × ${item.qty}",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          _miniStepper(item),
          const SizedBox(width: defaultPadding / 2),
          SizedBox(
            width: 64,
            child: Text(
              inr(item.lineTotal),
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStepper(CartItem item) {
    return Row(
      children: [
        _stepBtn("assets/icons/Minus.svg", () {
          setState(() {
            if (item.qty > 1) {
              item.qty--;
            } else {
              _items.remove(item);
            }
          });
        }),
        SizedBox(
          width: 28,
          child: Center(child: Text("${item.qty}")),
        ),
        _stepBtn("assets/icons/Plus1.svg", () {
          setState(() => item.qty++);
        }),
      ],
    );
  }

  Widget _stepBtn(String icon, VoidCallback onTap) {
    return SizedBox(
      height: 28,
      width: 28,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(6),
            side: BorderSide(color: Theme.of(context).dividerColor)),
        child: SvgPicture.asset(
          icon,
          colorFilter: ColorFilter.mode(
              Theme.of(context).iconTheme.color!, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _typeCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF4FC) : Colors.transparent,
          border: Border.all(
              color: selected
                  ? primaryColor
                  : Theme.of(context).dividerColor),
          borderRadius: const BorderRadius.all(
              Radius.circular(defaultBorderRadious)),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              icon,
              height: 28,
              colorFilter: const ColorFilter.mode(
                  primaryColor, BlendMode.srcIn),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

Widget _sectionTitle(BuildContext context, String title) {
  return Text(title,
      style: Theme.of(context)
          .textTheme
          .titleSmall!
          .copyWith(fontWeight: FontWeight.w600));
}

Widget _moneyRow(BuildContext context, String label, String value,
    {bool isTotal = false}) {
  final style = isTotal
      ? Theme.of(context)
          .textTheme
          .titleSmall!
          .copyWith(fontWeight: FontWeight.w700)
      : Theme.of(context).textTheme.bodyLarge;
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(label, style: style), Text(value, style: style)],
  );
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding * 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 36,
                backgroundColor: successColor,
                child:
                    Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: defaultPadding),
              Text("Order Confirmed",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text("Order #${order.id}",
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: defaultPadding),
              Text(order.itemsSummary,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(inr(order.totalAmount),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text("Delivery: ${order.deliverySlot}",
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: defaultPadding * 1.5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                      context, ordersScreenRoute),
                  child: const Text("View Order"),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, entryPointScreenRoute, (_) => false),
                child: const Text("Back to Home"),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
