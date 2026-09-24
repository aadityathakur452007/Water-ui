import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/components/skleton/product/product_card_skelton.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';
import 'package:shop/services/api_client.dart';

/// Water search: matches "20L", "water", "jar", "bottle",
/// "mineral water", "drinking water". Server-side via
/// `GET /api/products/search?q=`; falls back to the bundled catalog
/// when the API is unreachable.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _repo = const ProductRepository();
  String _query = "";
  Future<List<ProductModel>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load("");
  }

  Future<List<ProductModel>> _load(String q) async {
    try {
      if (q.trim().isEmpty) {
        return await _repo.fetchAll();
      }
      return await _repo.searchRemote(q);
    } on AppException {
      // Offline / backend down: fall back to the bundled catalog so the
      // screen still works; remote errors for a typed query surface
      // through the local search instead of a dead end.
      if (q.trim().isEmpty) return _repo.all();
      return _repo.search(q);
    }
  }

  void _onQuery(String? v) {
    final q = v ?? "";
    setState(() {
      _query = q;
      _future = _load(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: SearchForm(
                autofocus: true,
                onChanged: _onQuery,
              ),
            ),
            if (_query.trim().isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Results for “$_query”",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            Expanded(
              child: FutureBuilder<List<ProductModel>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(defaultPadding),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200.0,
                        mainAxisSpacing: defaultPadding,
                        crossAxisSpacing: defaultPadding,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, _) =>
                          const ProductCardSkelton(),
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
                              "Could not load water products.",
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
                              onPressed: () => setState(
                                  () => _future = _load(_query)),
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final results = snap.data ?? const <ProductModel>[];
                  if (results.isEmpty) {
                    return Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(defaultPadding * 1.5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "No water products found",
                              style:
                                  Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Try “20L”, “jar” or “bottle”.",
                              style:
                                  Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(defaultPadding),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200.0,
                      mainAxisSpacing: defaultPadding,
                      crossAxisSpacing: defaultPadding,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final p = results[index];
                      return ProductCard(
                        image: p.image,
                        brandName: p.brandName,
                        title: p.title,
                        price: p.price,
                        press: () => Navigator.pushNamed(
                            context, productDetailsScreenRoute,
                            arguments: p.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
