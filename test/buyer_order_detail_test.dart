import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/buyer/presentation/buyer_order_detail_screen.dart';
import 'package:shop_afrik/features/orders/data/orders_repository.dart';

import 'support/fixtures.dart';

class _FakeOrders implements OrdersRepository {
  _FakeOrders(this.order);
  final ShopOrder order;
  @override
  Stream<ShopOrder?> watchOrder(String id) => Stream.value(order);
  @override
  Stream<List<ShopOrder>> watchBuyerOrders(String b) => const Stream.empty();
  @override
  Stream<List<ShopOrder>> watchSellerOrders(String s) => const Stream.empty();
}

Widget _wrap(ShopOrder order) => ProviderScope(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(_FakeOrders(order)),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: BuyerOrderDetailScreen(orderId: order.id),
      ),
    );

void main() {
  testWidgets('awaitingPayment shows pay options and cancel', (tester) async {
    // Tall surface so the lazily-built list lays out all action buttons.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = testOrder(
      id: 'order1',
      settlement: SettlementStatus.notDue,
      items: [testItem(sellerId: 's1', unitPriceMinor: 5000, currency: 'NGN')],
    );
    final awaitingPay = ShopOrder(
      id: order.id,
      buyerId: order.buyerId,
      items: order.items,
      subtotal: order.subtotal,
      paymentFee: order.paymentFee,
      total: order.total,
      deliveryFee: order.subtotal, // some quoted delivery
      status: OrderStatus.awaitingPayment,
    );

    await tester.pumpWidget(_wrap(awaitingPay));
    await tester.pumpAndSettle();

    expect(find.text('Pay now'), findsOneWidget);
    expect(find.text('Pay on delivery'), findsOneWidget);
    expect(find.text('Cancel order'), findsOneWidget);
  });

  testWidgets('shipped order hides pay and cancel (past cutoff)',
      (tester) async {
    final base = testOrder(
      id: 'order2',
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
    );

    await tester.pumpWidget(_wrap(shipped));
    await tester.pumpAndSettle();

    expect(find.text('Pay now'), findsNothing);
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('delivered order shows tracking and proof of delivery',
      (tester) async {
    final base = testOrder(
      id: 'order3',
      settlement: SettlementStatus.scheduled,
      items: [testItem(sellerId: 's1', unitPriceMinor: 5000, currency: 'NGN')],
    );
    final delivered = ShopOrder(
      id: base.id,
      buyerId: base.buyerId,
      items: base.items,
      subtotal: base.subtotal,
      paymentFee: base.paymentFee,
      total: base.total,
      status: OrderStatus.delivered,
      deliveryProof: DeliveryProof(
        deliveryPersonId: 'd1',
        barcode: 'order3',
        photoUrl: 'https://example.com/p.jpg',
        latitude: 6.5,
        longitude: 3.3,
        capturedAt: DateTime(2026, 6, 1),
      ),
    );

    await tester.pumpWidget(_wrap(delivered));
    await tester.pumpAndSettle();

    expect(find.text('Tracking'), findsOneWidget);
    expect(find.text('Proof of delivery'), findsOneWidget);
    // Past the cutoff: no cancel.
    expect(find.text('Cancel order'), findsNothing);
  });
}
