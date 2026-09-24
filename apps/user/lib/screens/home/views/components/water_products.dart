import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/components/skleton/product/product_card_skelton.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/services/api_client.dart';

import '../../../../constants.dart';

/// Horizontal water product list with quantity steppers.
/// Loads the catalog via `GET /api/products` (falls back to the bundled
/// catalog offline). Quantities are local UI state.
class WaterProducts extends StatefulWidget {
  const WaterProducts({super.key});

  @override
  State<WaterProducts> createState() => _WaterProductsState();
}

class _WaterProductsState extends State<WaterProducts> {
  final _repo = const ProductRepository();
  final Map<String, int> _qty = {};
  Future<List<ProductModel>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProductModel>> _load() async {
    try {
      return await _repo.fetchAll();
    } on AppException {
      return _repo.all();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: FutureBuilder<List<ProductModel>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.only(left: defaultPadding),
                    child: ProductCardSkelton(),
                  ),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text("Could not load products. Retry"),
                  ),
                );
              }
              final products = snap.data ?? const <ProductModel>[];
              if (products.isEmpty) {
                return const Center(
                    child: Text("No water products right now"));
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final qty = _qty[product.id] ?? 1;
                  return Padding(
                    padding: EdgeInsets.only(
                      left: defaultPadding,
                      right:
                          index == products.length - 1 ? defaultPadding : 0,
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
                        Navigator.pushNamed(
                            context, productDetailsScreenRoute,
                            arguments: product.id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}
