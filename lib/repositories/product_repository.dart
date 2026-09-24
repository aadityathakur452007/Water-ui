import '../models/product_model.dart';

/// Local/mock product source. Backend integration later replaces
/// the body of these methods — widgets never hold hardcoded products.
class ProductRepository {
  const ProductRepository();

  List<ProductModel> all() => demoPopularProducts;

  ProductModel byId(String id, {ProductModel? fallback}) =>
      demoPopularProducts.firstWhere(
        (p) => p.id == id,
        orElse: () => fallback ?? demoPopularProducts.first,
      );

  List<ProductModel> byCategory(String query) {
    final q = query.toLowerCase();
    if (q.contains("jar")) {
      return demoPopularProducts.where((p) => p.unit == "jar").toList();
    }
    if (q.contains("can")) {
      return demoPopularProducts.where((p) => p.unit == "can").toList();
    }
    if (q.contains("bottle") || q.contains("packaged")) {
      return demoPopularProducts.where((p) => p.unit == "pack").toList();
    }
    return all();
  }

  List<ProductModel> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all();
    return demoPopularProducts.where((p) {
      final haystack =
          "${p.title} ${p.capacity} ${p.container} ${p.waterType} water jar bottle mineral drinking"
              .toLowerCase();
      return q.split(" ").every((word) => haystack.contains(word));
    }).toList();
  }
}
