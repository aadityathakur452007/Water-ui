import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';

enum DeliveryChoice { oneTime, regular }

/// "How would you like your water delivered?" — reached from product
/// details with `{productId, qty}` arguments.
class OrderTypeScreen extends StatefulWidget {
  const OrderTypeScreen({super.key, required this.productId, this.qty = 1});

  final String productId;
  final int qty;

  @override
  State<OrderTypeScreen> createState() => _OrderTypeScreenState();
}

class _OrderTypeScreenState extends State<OrderTypeScreen> {
  DeliveryChoice _choice = DeliveryChoice.oneTime;

  late final ProductModel product =
      const ProductRepository().byId(widget.productId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delivery Type")),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: ElevatedButton(
            onPressed: () {
              if (_choice == DeliveryChoice.oneTime) {
                Navigator.pushNamed(context, cartScreenRoute, arguments: {
                  'productId': product.id,
                  'qty': widget.qty,
                  'orderType': 'oneTime',
                });
              } else {
                Navigator.pushNamed(
                    context, subscriptionConfigScreenRoute,
                    arguments: {
                      'productId': product.id,
                      'qty': widget.qty,
                    });
              }
            },
            child: const Text("Continue"),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(defaultPadding),
        children: [
          Text(
            "How would you like your water delivered?",
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            "${widget.qty} × ${product.title} · ${inr(product.price * widget.qty)}",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: defaultPadding),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: "assets/icons/Delivery.svg",
                  title: "One Time",
                  subtitle: "Single delivery",
                  selected: _choice == DeliveryChoice.oneTime,
                  onTap: () =>
                      setState(() => _choice = DeliveryChoice.oneTime),
                ),
              ),
              const SizedBox(width: defaultPadding / 2),
              Expanded(
                child: _ChoiceCard(
                  icon: "assets/icons/Calender.svg",
                  title: "Regular",
                  subtitle: "Daily / weekly",
                  selected: _choice == DeliveryChoice.regular,
                  onTap: () =>
                      setState(() => _choice = DeliveryChoice.regular),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String icon, title, subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF4FC) : Colors.transparent,
          border: Border.all(
              color:
                  selected ? primaryColor : Theme.of(context).dividerColor),
          borderRadius: const BorderRadius.all(
              Radius.circular(defaultBorderRadious)),
        ),
        child: Column(
          children: [
            SvgPicture.asset(
              icon,
              height: 32,
              colorFilter:
                  const ColorFilter.mode(primaryColor, BlendMode.srcIn),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle,
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
