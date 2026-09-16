import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/features/buyer/application/cart_controller.dart';

import 'support/fixtures.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  CartController cart() => container.read(cartProvider.notifier);

  test('adds and merges quantities, computes subtotal', () {
    final p = testProduct(
        id: 'a', sellerId: 's1', priceMinor: 1000, currency: 'GHS');
    cart().add(p, quantity: 2);
    cart().add(p); // merges to 3

    expect(container.read(cartProvider).single.quantity, 3);
    expect(container.read(cartCountProvider), 3);
    expect(container.read(cartSubtotalProvider)!.minorUnits, 3000);
    expect(container.read(cartSubtotalProvider)!.currency, 'GHS');
  });

  test('refuses to add a different currency (never blends)', () {
    final ghs = testProduct(
        id: 'a', sellerId: 's1', priceMinor: 1000, currency: 'GHS');
    final ngn = testProduct(
        id: 'b', sellerId: 's2', priceMinor: 5000, currency: 'NGN');
    cart().add(ghs);
    expect(cart().canAdd(ngn), isFalse);
    cart().add(ngn); // no-op
    expect(container.read(cartProvider).length, 1);
    expect(container.read(cartProvider).single.product.id, 'a');
  });

  test('setQuantity to zero removes the line', () {
    final p = testProduct(
        id: 'a', sellerId: 's1', priceMinor: 1000, currency: 'GHS');
    cart().add(p);
    cart().setQuantity('a', 0);
    expect(container.read(cartProvider), isEmpty);
    expect(container.read(cartSubtotalProvider), isNull);
  });
}
