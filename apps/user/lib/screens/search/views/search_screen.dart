import 'package:flutter/material.dart';
import 'package:shop/components/product/product_card.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';

/// Water search: matches "20L", "water", "jar", "bottle",
/// "mineral water", "drinking water". No fashion filters.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _repo = const ProductRepository();
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final List<ProductModel> results = _repo.search(_query);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: SearchForm(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v ?? ""),
              ),
            ),
            if (_query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "${results.length} result${results.length == 1 ? '' : 's'} for “$_query”",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text("No water products found"))
                  : GridView.builder(
                      padding:
                          const EdgeInsets.all(defaultPadding),
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
