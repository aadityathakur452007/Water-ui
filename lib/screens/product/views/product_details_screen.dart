import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shop/components/cart_button.dart';
import 'package:shop/components/custom_modal_bottom_sheet.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/product_repository.dart';

import 'package:shop/route/route_constants.dart';

import 'components/product_images.dart';
import 'components/product_info.dart';
import 'components/product_list_tile.dart';
import 'components/product_quantity.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    this.isProductAvailable = true,
    this.productId,
  });

  final bool isProductAvailable;
  final String? productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _qty = 1;
  late final ProductModel product;

  @override
  void initState() {
    super.initState();
    product =
        const ProductRepository().byId(widget.productId ?? "wd-20l");
  }

  @override
  Widget build(BuildContext context) {
    final bool available = product.available && widget.isProductAvailable;
    return Scaffold(
      bottomNavigationBar: available
          ? CartButton(
              price: product.price * _qty,
              title: "Continue",
              subTitle: "$_qty × ${product.priceLabel}",
              press: () {
                Navigator.pushNamed(context, cartScreenRoute);
              },
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              floating: true,
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: SvgPicture.asset("assets/icons/Bookmark.svg",
                      colorFilter: ColorFilter.mode(
                          Theme.of(context).textTheme.bodyLarge!.color!,
                          BlendMode.srcIn)),
                ),
              ],
            ),
            ProductImages(images: [product.image]),
            ProductInfo(
              brand: product.capacity.toUpperCase(),
              title: product.title,
              isAvailable: available,
              description:
                  "Purified ${product.waterType.toLowerCase()} in a ${product.container.toLowerCase()}. "
                  "Sealed, hygienic and delivered to your doorstep.",
              rating: 4.6,
              numOfReviews: 214,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: _SpecTable(product: product),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: ProductQuantity(
                  numOfItem: _qty,
                  onIncrement: () => setState(() => _qty++),
                  onDecrement: () => setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                ),
              ),
            ),
            ProductListTile(
              svgSrc: "assets/icons/Delivery.svg",
              title: "Delivery Information",
              press: () {
                customModalBottomSheet(
                  context,
                  child: Padding(
                    padding: const EdgeInsets.all(defaultPadding * 1.5),
                    child: Text(
                      "Same-day delivery across Bhopal. One-time orders arrive in the selected slot; regular deliveries follow your subscription schedule. Delivery fee ₹10 per order.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                );
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.all(defaultPadding),
              sliver: SliverToBoxAdapter(
                child: Text(
                  "You may also like",
                  style: Theme.of(context).textTheme.titleSmall!,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: demoPopularProducts.length,
                  itemBuilder: (context, index) {
                    final other = demoPopularProducts[index];
                    if (other.id == product.id) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: EdgeInsets.only(
                          left: defaultPadding,
                          right: index == demoPopularProducts.length - 1
                              ? defaultPadding
                              : 0),
                      child: ProductCard(
                        image: other.image,
                        title: other.title,
                        brandName: other.brandName,
                        price: other.price,
                        priceAfetDiscount: other.priceAfetDiscount,
                        dicountpercent: other.dicountpercent,
                        press: () {
                          Navigator.pushNamed(
                              context, productDetailsScreenRoute,
                              arguments: other.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: defaultPadding),
            )
          ],
        ),
      ),
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Product Details",
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: defaultPadding / 2),
        _row(context, "Capacity", product.capacity),
        _row(context, "Container", product.container),
        _row(context, "Water Type", product.waterType),
        const SizedBox(height: defaultPadding / 2),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
