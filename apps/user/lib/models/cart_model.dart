import 'product_model.dart';

class CartItem {
  final ProductModel product;
  int qty;

  CartItem({required this.product, this.qty = 1});

  double get lineTotal => product.price * qty;
}

class Cart {
  final List<CartItem> items;

  const Cart([this.items = const []]);

  double get subtotal =>
      items.fold(0, (sum, item) => sum + item.lineTotal);

  static const double deliveryFee = 10;

  double get total => subtotal + (items.isEmpty ? 0 : deliveryFee);
}

String inr(double value) =>
    "₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}";
