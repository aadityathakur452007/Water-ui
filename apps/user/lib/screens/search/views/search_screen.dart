import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shop/components/network_image_with_loader.dart';
import 'package:shop/constants.dart';
import 'package:shop/models/cart_model.dart' show inr;
import 'package:shop/models/product_model.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/route/route_constants.dart';
import 'package:shop/screens/search/views/components/search_form.dart';
import 'package:shop/services/api_client.dart';

/// Water search: matches "20L", "water", "jar", "bottle",
/// "mineral water", "drinking water". Server-side via
/// `GET /api/products/search?q=`; falls back to the bundled catalog
/// when the API is unreachable.
///
/// Typing is debounced (300ms) and the field owns a
/// [TextEditingController] so rebuilds never move the caret.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ""});

  /// Deep link from Shop categories (e.g. "20L Drinking Water Jar").
  final String initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _sortLabels = {
    'relevance': 'Relevance',
    'price_asc': 'Price: low to high',
    'price_desc': 'Price: high to low',
  };

  final _repo = const ProductRepository();
  final _controller = TextEditingController();
  Timer? _debounce;
  late String _query;
  String _sort = 'relevance';
  Future<List<ProductModel>>? _future;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _controller.text = widget.initialQuery;
    _future = _load(_query);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = _controller.text;
      if (!mounted || q == _query) return;
      setState(() {
        _query = q;
        _future = _load(q);
      });
    });
  }

  List<ProductModel> _applySort(List<ProductModel> list) {
    final sorted = List<ProductModel>.of(list);
    if (_sort == 'price_asc') {
      sorted.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == 'price_desc') {
      sorted.sort((a, b) => b.price.compareTo(a.price));
    }
    return sorted;
  }

  Future<List<ProductModel>> _load(String q) async {
    try {
      if (q.trim().isEmpty) return _applySort(await _repo.fetchAll());
      return _applySort(await _repo.searchRemote(q));
    } on AppException {
      // Offline / backend down: fall back to the bundled catalog so the
      // screen still works; remote errors for a typed query surface
      // through the local search instead of a dead end.
      if (q.trim().isEmpty) return _applySort(_repo.all());
      return _applySort(_repo.search(q));
    }
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => RadioGroup<String>(
        groupValue: _sort,
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _sort = v;
            _future = _load(_query);
          });
          Navigator.pop(sheetContext);
        },
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    defaultPadding * 1.5,
                    defaultPadding * 1.5,
                    defaultPadding * 1.5,
                    defaultPadding / 2),
                child: Text("Sort by",
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              for (final entry in _sortLabels.entries)
                RadioListTile<String>(
                  value: entry.key,
                  activeColor: primaryColor,
                  title: Text(entry.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Highlights query words inside [title] (no new deps — RichText).
  RichText _highlightedTitle(
      BuildContext context, String title, String query) {
    final base =
        Theme.of(context).textTheme.titleSmall!.copyWith(fontSize: 14);
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return RichText(text: TextSpan(text: title, style: base));
    final lower = title.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < title.length) {
      String? hit;
      for (final w in words) {
        if (lower.startsWith(w, i)) {
          if (hit == null || w.length > hit.length) hit = w;
        }
      }
      if (hit == null) {
        final start = i;
        while (i < title.length) {
          var found = false;
          for (final w in words) {
            if (lower.startsWith(w, i)) {
              found = true;
              break;
            }
          }
          if (found) break;
          i++;
        }
        spans.add(TextSpan(text: title.substring(start, i)));
      } else {
        spans.add(TextSpan(
          text: title.substring(i, i + hit.length),
          style: const TextStyle(
              color: primaryColor, fontWeight: FontWeight.w700),
        ));
        i += hit.length;
      }
    }
    return RichText(
        text: TextSpan(style: base, children: spans),
        maxLines: 2,
        overflow: TextOverflow.ellipsis);
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
                autofocus: _query.isEmpty,
                controller: _controller,
                onTabFilter: _openSortSheet,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ProductModel>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: defaultPadding / 2),
                          Text("Searching water products"),
                        ],
                      ),
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
                  final count = results.length;
                  final header = _query.trim().isEmpty
                      ? "$count result${count == 1 ? '' : 's'}"
                      : "$count result${count == 1 ? '' : 's'} for “${_query.trim()}”";
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: defaultPadding),
                        child: Text(
                          _sort == 'relevance'
                              ? header
                              : "$header · ${_sortLabels[_sort]}",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.all(defaultPadding),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final p = results[index];
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: defaultPadding / 2),
                              leading: SizedBox(
                                width: 56,
                                height: 56,
                                child: NetworkImageWithLoader(
                                  p.image,
                                  radius: defaultBorderRadious / 2,
                                ),
                              ),
                              title: _highlightedTitle(
                                  context, p.title, _query),
                              subtitle: Text(
                                  "${p.brandName} · ${inr(p.price)}"),
                              trailing: const Icon(
                                  Icons.chevron_right, size: 20),
                              onTap: () => Navigator.pushNamed(
                                  context, productDetailsScreenRoute,
                                  arguments: p.id),
                            );
                          },
                        ),
                      ),
                    ],
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
