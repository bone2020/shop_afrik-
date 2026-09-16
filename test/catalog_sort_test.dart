import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/features/buyer/data/catalog_repository.dart';

import 'support/fixtures.dart';

void main() {
  test('price sort groups by currency, never compares across currencies', () {
    final list = [
      testProduct(id: 'ngn_hi', sellerId: 's', priceMinor: 900000, currency: 'NGN'),
      testProduct(id: 'ghs_lo', sellerId: 's', priceMinor: 500, currency: 'GHS'),
      testProduct(id: 'ngn_lo', sellerId: 's', priceMinor: 100000, currency: 'NGN'),
      testProduct(id: 'ghs_hi', sellerId: 's', priceMinor: 9000, currency: 'GHS'),
    ];

    sortProducts(list, ProductSort.priceLowToHigh);

    // Grouped by currency (GHS before NGN), ascending within each group — a raw
    // cross-currency minorUnits sort would have put GHS 500 next to NGN 100000.
    expect(list.map((p) => p.id).toList(),
        ['ghs_lo', 'ghs_hi', 'ngn_lo', 'ngn_hi']);

    sortProducts(list, ProductSort.priceHighToLow);
    expect(list.map((p) => p.id).toList(),
        ['ghs_hi', 'ghs_lo', 'ngn_hi', 'ngn_lo']);
  });
}
