import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/platform_settings.dart';
import 'package:shop_afrik/features/seller/application/seller_earnings.dart';

import 'support/fixtures.dart';

void main() {
  const settings = PlatformSettings(commissionRate: 0.15);

  test('payable nets commission and groups by currency, never blended', () {
    final orders = [
      // Pending settlement in GHS: gross 10000 -> net 8500.
      testOrder(
        id: 'o1',
        settlement: SettlementStatus.scheduled,
        items: [
          testItem(sellerId: 's1', unitPriceMinor: 5000, currency: 'GHS', quantity: 2),
        ],
      ),
      // Pending settlement in NGN: gross 20000 -> net 17000.
      testOrder(
        id: 'o2',
        settlement: SettlementStatus.onHold,
        items: [
          testItem(sellerId: 's1', unitPriceMinor: 20000, currency: 'NGN'),
        ],
      ),
      // Already settled -> excluded.
      testOrder(
        id: 'o3',
        settlement: SettlementStatus.settled,
        items: [
          testItem(sellerId: 's1', unitPriceMinor: 9999, currency: 'GHS'),
        ],
      ),
    ];

    final payable =
        computeSellerPayable(orders: orders, sellerId: 's1', settings: settings);

    expect(payable.keys.toSet(), {'GHS', 'NGN'});
    expect(payable['GHS']!.minorUnits, 8500);
    expect(payable['NGN']!.minorUnits, 17000);
  });

  test('excludes other sellers and refunded units', () {
    final orders = [
      testOrder(
        id: 'o1',
        settlement: SettlementStatus.scheduled,
        items: [
          testItem(sellerId: 's1', unitPriceMinor: 1000, currency: 'GHS', quantity: 3, refundedQuantity: 1),
          testItem(sellerId: 'other', unitPriceMinor: 9999, currency: 'GHS'),
        ],
      ),
    ];

    final payable =
        computeSellerPayable(orders: orders, sellerId: 's1', settings: settings);

    // 2 remaining units * 1000 = 2000 gross -> 1700 net.
    expect(payable['GHS']!.minorUnits, 1700);
  });
}
