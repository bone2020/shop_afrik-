import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/delivery/data/delivery_repository.dart';
import 'package:shop_afrik/features/delivery/presentation/delivery_home_screen.dart';

import 'support/fixtures.dart';
import 'support/session.dart';

class _FakeDelivery implements DeliveryRepository {
  _FakeDelivery(this.orders);
  final List<ShopOrder> orders;
  @override
  Stream<List<ShopOrder>> watchAssignedDeliveries() => Stream.value(orders);
  @override
  Future<void> submitProof({
    required String orderId,
    required String barcode,
    String? photoUrl,
    double? latitude,
    double? longitude,
  }) async {}
}

void main() {
  testWidgets('delivery home lists shipped orders to drop off',
      (tester) async {
    final base = testOrder(
      id: 'orderX',
      settlement: SettlementStatus.notDue,
      items: [testItem(sellerId: 's1', unitPriceMinor: 5000, currency: 'NGN')],
    );
    final shipped = ShopOrder(
      id: base.id,
      buyerId: base.buyerId,
      items: base.items,
      subtotal: base.subtotal,
      paymentFee: base.paymentFee,
      total: base.total,
      status: OrderStatus.shipped,
      deliveryLocation: const DeliveryLocation(
        recipientName: 'Ada',
        phone: '+234800',
        addressLine: '1 Market Rd',
        city: 'Lagos',
        market: 'NG',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stubSession(),
          deliveryRepositoryProvider
              .overrideWithValue(_FakeDelivery([shipped])),
        ],
        child: const MaterialApp(home: DeliveryHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Scan & confirm delivery'), findsOneWidget);
  });

  testWidgets('empty pool shows a message', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stubSession(),
          deliveryRepositoryProvider.overrideWithValue(_FakeDelivery(const [])),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const DeliveryHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No deliveries'), findsOneWidget);
  });
}
