import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/address_repository.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/config/app_config.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/repositories/subscription_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';
import 'package:shop/services/auth_service.dart';

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
  Map<String, dynamic> _subConfig = {};
  _Payment _payment = _Payment.cod;
  Order? _placed;
  bool _placing = false;
  // Honest offline state: set when the order could NOT be sent.
  // The success view only ever renders for a truly placed order.
  String? _orderError;

  List<Address> _addresses = [];
  String? _selectedAddressId;
  bool _loadingAddresses = true;
  bool _addrOffline = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await const AddressRepository().fetchAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _selectedAddressId = list.isEmpty ? null : list.first.id;
        _loadingAddresses = false;
      });
    } on AppException catch (e) {
      if (e.code == 'UNAUTHENTICATED') {
        await const AuthService().handleUnauthorized();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, logInScreenRoute, (_) => false);
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _addresses = [];
        _selectedAddressId = null;
        _loadingAddresses = false;
        _addrOffline = e.code == 'NETWORK';
      });
    }
  }

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
        _subConfig = {
          'frequency': map['frequency'] as String? ?? 'every_day',
          'startDate': map['startDate'] as String? ?? '',
          'deliveryTime': map['deliveryTime'] as String? ?? '',
        };
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
    setState(() {
      _placing = true;
      _orderError = null;
    });
    final lines = _items
        .map((e) => OrderItem(
              productId: e.product.id,
              name: e.product.title,
              qty: e.qty,
              price: e.product.price,
            ))
        .toList();
    try {
      // `POST /api/orders` with the selected address (contract requires
      // addressId|address). Falls back to the default address only when
      // the address list is empty.
      final remote = await _orders.createOrder(
        items: lines,
        slot: _slot,
        orderType: _orderType,
        addressId: _selectedAddressId,
        address: _selectedAddressId == null
            ? {
                'label': defaultAddress.label,
                'line': defaultAddress.line,
                'city': defaultAddress.city,
              }
            : null,
      );
      if (!AppConfig.demoMode &&
          _orderType == OrderType.regular &&
          _subConfig.isNotEmpty &&
          _items.isNotEmpty) {
        // Persist the recurring schedule; the order itself is the source
        // of truth, so a sub failure only surfaces a retry note.
        try {
          await const SubscriptionRepository().createRemoteRaw(
            productId: _items.first.product.id,
            quantity: _items.first.qty,
            frequency:
                _subConfig['frequency'] as String? ?? 'every_day',
            startDate: _subConfig['startDate'] as String? ?? '',
            deliveryTime:
                _subConfig['deliveryTime'] as String? ?? '',
          );
        } on AppException catch (e) {
          if (e.code == 'UNAUTHENTICATED') {
            await const AuthService().handleUnauthorized();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, logInScreenRoute, (_) => false);
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Order placed. Recurring setup needs a retry in My Deliveries.'),
              ),
            );
          }
        }
      }
      if (mounted) setState(() => _placed = remote);
    } on AppException catch (e) {
      if (e.code == 'UNAUTHENTICATED') {
        await const AuthService().handleUnauthorized();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, logInScreenRoute, (_) => false);
        }
        return;
      }
      if (e.code != 'NETWORK') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
        return;
      }
      // NETWORK: never show the success view for an unsent order.
      // The cart is kept intact with an explicit not-sent state + retry.
      if (mounted) {
        setState(() {
          _orderError =
              "Could not reach the server — your order was NOT sent. "
              "It is still in your cart. Check your connection and try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// Opens the payment-methods screen and syncs the local selection
  /// with the popped String result ('cod'|'upi'). A null result (back
  /// without choosing) leaves the local selection unchanged.
  Future<void> _pickPaymentMethod() async {
    final result = await Navigator.pushNamed(
      context,
      paymentMethodsScreenRoute,
      arguments: _payment == _Payment.upi ? 'upi' : 'cod',
    );
    if (!mounted) return;
    if (result == 'upi') {
      setState(() => _payment = _Payment.upi);
    } else if (result == 'cod') {
      setState(() => _payment = _Payment.cod);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_placed != null) return _SuccessView(order: _placed!);
    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Checkout")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding * 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.water_drop_outlined,
                    size: 56, color: primaryColor),
                const SizedBox(height: defaultPadding),
                Text(
                  "Your cart is empty",
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Add some water to get started.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: defaultPadding),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(
                      context, discoverScreenRoute),
                  child: const Text("Browse water"),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
          if (_orderError != null) ...[
            Container(
              padding: const EdgeInsets.all(defaultPadding),
              decoration: BoxDecoration(
                border: Border.all(color: errorColor),
                borderRadius: const BorderRadius.all(
                    Radius.circular(defaultBorderRadious)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order not sent",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _orderError!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _placeOrder,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: defaultPadding),
          ],
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
          if (_loadingAddresses)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text("Loading addresses..."),
            )
          else if (_addresses.isEmpty)
            _fallbackAddressBox(context)
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: const BorderRadius.all(
                    Radius.circular(defaultBorderRadious)),
              ),
              child: Column(
                children: [
                  if (_addrOffline)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                          defaultPadding, 8, defaultPadding, 0),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off,
                              size: 12, color: primaryColor),
                          SizedBox(width: 4),
                          Text(
                            "Offline — showing saved addresses",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  RadioGroup<String>(
                    groupValue: _selectedAddressId,
                    onChanged: (v) =>
                        setState(() => _selectedAddressId = v),
                    child: Column(
                      children: [
                        for (final a in _addresses)
                          RadioListTile<String>(
                            value: a.id,
                            title: Text(
                                "${a.label} · ${a.line}, ${a.city}"),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8),
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(
                          context, addressesScreenRoute),
                      child: const Text("Add / Change"),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: defaultPadding),
          _sectionTitle(context, "Payment"),
          Text(
            "Pay on delivery",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _pickPaymentMethod,
              child: const Text("Choose in Payment Methods"),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown only when the address list is empty (genuine-empty or
  /// load failure) — keeps the contract-required address fallback.
  Widget _fallbackAddressBox(BuildContext context) {
    return Container(
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
            onPressed: () =>
                Navigator.pushNamed(context, addressesScreenRoute),
            child: const Text("Change"),
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
              Text("Thanks! Your water is on its way.",
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(order.displayLabel,
                  textAlign: TextAlign.center,
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
                  // Replacement (no back-stack pile-up) + the real order
                  // id so Orders auto-opens this order's detail sheet.
                  onPressed: () => Navigator.pushReplacementNamed(
                      context, ordersScreenRoute,
                      arguments: order.id),
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
