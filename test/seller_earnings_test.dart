import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/money.dart';
import 'package:shop_afrik/core/models/platform_settings.dart';
import 'package:shop_afrik/core/models/settlement.dart';
import 'package:shop_afrik/core/models/user_role.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/seller/application/seller_earnings.dart';
import 'package:shop_afrik/features/seller/data/settlement_repository.dart';
import 'package:shop_afrik/features/seller/presentation/seller_earnings_tab.dart';

import 'support/fixtures.dart';
import 'support/session.dart';

class _FakeSettlements implements SettlementRepository {
  _FakeSettlements(this.list);
  final List<Settlement> list;
  String? askedFor;

  @override
  Stream<List<Settlement>> watchSellerSettlements(String sellerId,
      {int limit = 50}) {
    askedFor = sellerId;
    return Stream.value(list);
  }
}

Money _ghs(int minor) => Money(minorUnits: minor, currency: 'GHS');

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

  testWidgets('payout history lists settled and held payouts (SA-066)',
      (tester) async {
    final repo = _FakeSettlements([
      Settlement(
        id: 'order0001_s1',
        orderId: 'order0001',
        sellerId: 'test-uid',
        gross: _ghs(10000),
        commissionRate: 0.15,
        commission: _ghs(1500),
        net: _ghs(8500),
        status: SettlementStatus.settled,
        qrWalletPayoutId: 'PAY-123',
        settledAt: DateTime(2026, 11, 3, 12),
      ),
      Settlement(
        id: 'order0002_s1',
        orderId: 'order0002',
        sellerId: 'test-uid',
        gross: _ghs(2000),
        commissionRate: 0.15,
        commission: _ghs(300),
        net: _ghs(1700),
        status: SettlementStatus.onHold,
        holdReason: 'sellerSuspended',
      ),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        stubSession(authedSession(UserRole.seller)),
        sellerPayableProvider.overrideWith((ref) => const AsyncData({})),
        settlementRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
          theme: AppTheme.dark, home: const Scaffold(body: SellerEarningsTab())),
    ));
    await tester.pumpAndSettle();

    expect(repo.askedFor, 'test-uid');
    expect(find.text('Order ORDER000'), findsNWidgets(2));
    expect(find.text('GHS 85.00'), findsOneWidget);
    expect(find.text('Sales GHS 100.00 · commission 15% GHS 15.00'),
        findsOneWidget);
    expect(find.text('2026-11-03 · Ref PAY-123'), findsOneWidget);
    expect(find.text('On hold while your store is suspended'), findsOneWidget);
  });
}
