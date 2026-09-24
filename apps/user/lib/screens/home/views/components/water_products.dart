import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';

import '../../../../constants.dart';

/// Horizontal water product list with quantity steppers.
/// Quantities are local UI state; checkout reads them back via the cart.
class WaterProducts extends StatefulWidget {
  const WaterProducts({super.key});

  @override
  State<WaterProducts> createState() => _WaterProductsState();
}

class _WaterProductsState extends State<WaterProducts> {
  final _repo = const ProductRepository();
  final Map<String, int> _qty = {};

  @override
  Widget build(BuildContext context) {
    final List<ProductModel> products = _repo.all();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(
            "Water products",
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SizedBox(
          height: 264,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final qty = _qty[product.id] ?? 1;
              return Padding(
                padding: EdgeInsets.only(
                  left: defaultPadding,
                  right: index == products.length - 1 ? defaultPadding : 0,
                ),
                child: ProductCard(
                  image: product.image,
                  brandName: product.brandName,
                  title: product.title,
                  price: product.price,
                  priceAfetDiscount: product.priceAfetDiscount,
                  dicountpercent: product.dicountpercent,
                  showStepper: true,
                  quantity: qty,
                  onIncrement: () =>
                      setState(() => _qty[product.id] = qty + 1),
                  onDecrement: () => setState(
                      () => _qty[product.id] = qty > 1 ? qty - 1 : 1),
                  press: () {
                    Navigator.pushNamed(context, productDetailsScreenRoute,
                        arguments: product.id);
                  },
                ),
              );
            },
          ),
        )
      ],
    );
  }
}
