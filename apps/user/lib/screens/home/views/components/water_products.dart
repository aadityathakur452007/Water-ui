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
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProductModel>> _load() async {
    try {
      final products = await _repo.fetchAll();
      if (mounted) setState(() => _offline = false);
      return products;
    } on AppException catch (e) {
      // NETWORK-only fallback: auth/validation/server errors rethrow
      // so the Retry path surfaces them honestly.
      if (e.code != 'NETWORK') rethrow;
      if (mounted) setState(() => _offline = true);
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
          child: Row(
            children: [
              Text(
                "Water products",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (_offline) ...[
                const SizedBox(width: 8),
                const _OfflineChip(),
              ],
            ],
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
                      onDecrement: qty <= 1
                          ? null
                          : () => setState(
                              () => _qty[product.id] = qty - 1),
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

/// Small "offline" hint shown when fallback demo data renders
/// because the network was unreachable.
class _OfflineChip extends StatelessWidget {
  const _OfflineChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4FC),
        borderRadius: BorderRadius.all(Radius.circular(30)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 12, color: primaryColor),
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
    );
  }
}
