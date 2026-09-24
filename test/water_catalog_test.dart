import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/models/order_model.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/repositories/subscription_repository.dart';

void main() {
  const products = ProductRepository();
  const orders = OrderRepository();
  const subs = SubscriptionRepository();

  test('catalog has the 5 launch products with INR prices', () {
    final all = products.all();
    expect(all.length, greaterThanOrEqualTo(5));
    expect(
      all.map((p) => p.id),
      containsAll(['wd-20l', 'wd-15l', 'wd-10l', 'wd-1l-12', 'wd-500ml-12']),
    );
    expect(products.byId('wd-20l').price, 60);
    expect(products.byId('wd-20l').priceLabel, '₹60');
  });

  test('search finds water by capacity and type words', () {
    expect(products.search('20L').map((p) => p.id), contains('wd-20l'));
    expect(products.search('bottle').map((p) => p.id),
        containsAll(['wd-1l-12', 'wd-500ml-12']));
    expect(products.search('').length, products.all().length);
  });

  test('cart totals add the ₹10 delivery fee', () {
    final cart = Cart([
      CartItem(product: products.byId('wd-20l'), qty: 2),
    ]);
    expect(cart.subtotal, 120);
    expect(cart.total, 130);
    expect(inr(cart.total), '₹130');
  });

  test('ongoing and past orders exist with statuses', () {
    expect(orders.ongoing(), isNotEmpty);
    expect(orders.past(), isNotEmpty);
    expect(orders.lastOrder(), isNotNull);
  });

  test('active delivery subscription exists', () {
    final sub = subs.activeDelivery();
    expect(sub, isNotNull);
    expect(sub!.status, isNotNull);
  });
}
