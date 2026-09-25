import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';

import 'components/active_delivery.dart';
import 'components/categories.dart';
import 'components/delivery_address_header.dart';
import 'components/order_again.dart';
import 'components/water_products.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: DeliveryAddressHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding, vertical: defaultPadding / 2),
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, searchScreenRoute),
                  child: const AbsorbPointer(
                    child: SearchForm(isEnabled: false),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Text(
                  "Get water delivered to your doorstep",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Categories()),
            const SliverToBoxAdapter(child: WaterProducts()),
            const SliverToBoxAdapter(child: OrderAgain()),
            const SliverToBoxAdapter(child: ActiveDelivery()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: _WaterPromoBanner(
                  press: () => Navigator.pushNamed(
                      context, discoverScreenRoute),
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: defaultPadding)),
          ],
        ),
      ),
    );
  }
}

/// One small informational banner — never dominates the screen.
class _WaterPromoBanner extends StatelessWidget {
  const _WaterPromoBanner({required this.press});

  final VoidCallback press;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: press,
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: const BoxDecoration(
          color: primaryColor,
          borderRadius:
              BorderRadius.all(Radius.circular(defaultBorderRadious)),
        ),
        child: Row(
          children: [
            const Icon(Icons.water_drop, color: Colors.white, size: 28),
            const SizedBox(width: defaultPadding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Free delivery on 20L jars",
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Order 2 or more jars · Bhopal",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
