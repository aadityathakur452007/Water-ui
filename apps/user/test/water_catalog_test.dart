import 'package:flutter_test/flutter_test.dart';
import 'package:shop/models/cart_model.dart';
import 'package:shop/repositories/order_repository.dart';
import 'package:shop/repositories/product_repository.dart';
import 'package:shop/repositories/subscription_repository.dart';

void main() {
  const products = ProductRepository();
  const orders = OrderRepository();
  const subs = SubscriptionRepository();

  test('catalog has the Shodasha lineup with INR prices', () {
    final all = products.all();
    expect(all.map((p) => p.id),
        containsAll(['wd-20l-refill', 'wd-20l-jar', 'wd-1l']));
    expect(products.byId('wd-20l-refill').price, 28);
    expect(products.byId('wd-20l-refill').priceLabel, '₹28');
    expect(products.byId('wd-20l-jar').price, 30);
    expect(products.byId('wd-1l').available, isFalse);
  });

  test('search finds water by capacity and type words', () {
    expect(products.search('20L').map((p) => p.id),
        containsAll(['wd-20l-refill', 'wd-20l-jar']));
    expect(products.search('bottle').map((p) => p.id), contains('wd-1l'));
    expect(products.search('').length, products.all().length);
  });

  test('cart totals add the ₹10 delivery fee', () {
    final cart = Cart([
      CartItem(product: products.byId('wd-20l-jar'), qty: 2),
    ]);
    expect(cart.subtotal, 60);
    expect(cart.total, 70);
    expect(inr(cart.total), '₹70');
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
