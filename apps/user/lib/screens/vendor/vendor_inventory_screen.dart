import 'package:flutter/material.dart';

import '../../models/cart_model.dart';
import '../../models/product_model.dart';
import '../../repositories/product_repository.dart';
import '../../services/api_client.dart';

/// Sitemap: `vendor_inventory` (role:vendor, data: GET /api/products —
/// [ProductRepository.fetchAll]; no new backend).
///
/// Flow: VendorHome tab → fetch catalog → read-only stock view.
/// Availability renders from the existing `available` flag only; the
/// stepper is a read-only display (no PATCH exists in this pass), and
/// stock history cannot be derived, so the sample/read-only labels below
/// stay honest instead of inventing counts.
class VendorInventoryScreen extends StatefulWidget {
  const VendorInventoryScreen(
      {super.key,
      this.products = const ProductRepository(),
      this.showAppBar = true});

  final ProductRepository products;

  /// False when embedded in the VendorHome tabs (it owns the AppBar).
  final bool showAppBar;

  @override
  State<VendorInventoryScreen> createState() => _VendorInventoryScreenState();
}

class _VendorInventoryScreenState extends State<VendorInventoryScreen> {
  bool _offline = false;
  late Future<List<ProductModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProductModel>> _load() async {
    try {
      final list = await widget.products.fetchAll();
      if (mounted) setState(() => _offline = false);
      return list;
    } on AppException catch (e) {
      // NETWORK-only fallback to the bundled catalog; auth/validation
      // errors rethrow so the Retry path surfaces them honestly.
      if (e.code != 'NETWORK') rethrow;
      if (mounted) setState(() => _offline = true);
      return widget.products.all();
    }
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<ProductModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, __) => const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBar(width: 160),
                    SizedBox(height: 8),
                    _SkeletonBar(width: 100),
                  ],
                ),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load inventory.'),
                  const SizedBox(height: 4),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Color(0xFF6E6E73))),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _retry,
                      child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No products in the catalog.'),
                  SizedBox(height: 4),
                  Text(
                    'Products appear here once the catalog loads.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6E6E73)),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _retry();
            try {
              await _future;
            } catch (_) {}
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_offline)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF4FC),
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 12, color: Color(0xFF1B7BD6)),
                      SizedBox(width: 4),
                      Text('Offline — bundled catalog',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1B7BD6))),
                    ],
                  ),
                ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Sample read-only view: stock counts and history are unavailable until the server inventory lands. No changes are sent.',
                    style: TextStyle(color: Color(0xFF6E6E73)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final p in items) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.water_drop,
                              color: Color(0xFF1B7BD6)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(p.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${p.capacity.isEmpty ? p.unit : p.capacity} · ${inr(p.price)}',
                                style: const TextStyle(
                                    color: Color(0xFF6E6E73)),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (p.available
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF6E6E73))
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Text(
                                  p.available
                                      ? 'In stock'
                                      : 'Unavailable',
                                  style: TextStyle(
                                      color: p.available
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF6E6E73),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Read-only stepper display: disabled controls
                        // around a sample quantity. No PATCH exists.
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.remove_circle_outline,
                                  color: Color(0xFFA2A2A5)),
                            ),
                            Text('1',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.add_circle_outline,
                                  color: Color(0xFFA2A2A5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Text('Steppers are read-only previews.',
                  style: TextStyle(color: Color(0xFF6E6E73))),
            ],
          ),
        );
      },
    );
    if (!widget.showAppBar) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: content,
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: const BoxDecoration(
        color: Color(0xFFE8E8E9),
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );
  }
}
