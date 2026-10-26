import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/data/platform_settings_repository.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/money.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/models/platform_settings.dart';
import 'package:shop_afrik/core/models/refund_request.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/buyer/data/refund_service.dart';
import 'package:shop_afrik/features/buyer/presentation/buyer_order_detail_screen.dart';
import 'package:shop_afrik/features/buyer/presentation/refund_request_screen.dart';
import 'package:shop_afrik/features/orders/data/orders_repository.dart';

class _FakeRefunds implements RefundService {
  Map<String, int>? sentQuantities;
  String? sentReason;

  @override
  Future<String> requestRefund({
    required String orderId,
    required Map<String, int> quantities,
    required String reason,
    List<String> evidenceUrls = const [],
  }) async {
    sentQuantities = Map.of(quantities)..removeWhere((_, q) => q == 0);
    sentReason = reason;
    return 'r1';
  }

  @override
  Stream<List<RefundRequest>> watchForOrder({
    required String buyerId,
    required String orderId,
  }) =>
      const Stream.empty();

  @override
  Future<String?> pickAndUploadEvidence(String buyerId) async => null;
}

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

Money _ghs(int minor) => Money(minorUnits: minor, currency: 'GHS');

ShopOrder _delivered({DateTime? deliveredAt}) {
  const items = [
    OrderItem(
        productId: 'p1',
        sellerId: 's1',
        title: 'Kente cloth',
        unitPrice: Money(minorUnits: 5000, currency: 'GHS'),
        quantity: 2),
    OrderItem(
        productId: 'p2',
        sellerId: 's1',
        title: 'Shea butter',
        unitPrice: Money(minorUnits: 2000, currency: 'GHS'),
        quantity: 1),
  ];
  return ShopOrder(
    id: 'order1',
    buyerId: 'buyer1',
    items: items,
    subtotal: _ghs(12000),
    paymentFee: _ghs(0),
    total: _ghs(12000),
    status: OrderStatus.delivered,
    deliveryConfirmedAt:
        deliveredAt ?? DateTime.now().subtract(const Duration(days: 2)),
  );
}

RefundRequest _refund(RefundStatus status) => RefundRequest(
      id: 'r1',
      orderId: 'order1',
      buyerId: 'buyer1',
      lines: const [],
      amount: _ghs(5000),
      reason: 'Torn',
      tier: RefundTier.tier1,
      status: status,
    );

Widget _detail(ShopOrder order, {List<RefundRequest> refunds = const []}) =>
    ProviderScope(
      overrides: [
        ordersRepositoryProvider.overrideWithValue(_FakeOrders(order)),
        orderRefundsProvider.overrideWith((ref, id) => Stream.value(refunds)),
        platformSettingsProvider
            .overrideWith((ref) => Stream.value(const PlatformSettings())),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: BuyerOrderDetailScreen(orderId: order.id),
      ),
    );

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('delivered order inside the window offers a refund',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(_detail(_delivered()));
    await tester.pumpAndSettle();
    expect(find.text('Request a refund'), findsOneWidget);
  });

  testWidgets('no refund button after the window closes', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_detail(_delivered(
        deliveredAt: DateTime.now().subtract(const Duration(days: 8)))));
    await tester.pumpAndSettle();
    expect(find.text('Request a refund'), findsNothing);
  });

  testWidgets('a pending refund shows its status instead of the button',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(
        _detail(_delivered(), refunds: [_refund(RefundStatus.requested)]));
    await tester.pumpAndSettle();
    expect(find.text('Refund under review'), findsOneWidget);
    expect(find.text('Request a refund'), findsNothing);
  });

  testWidgets('a declined refund is shown and a new request is allowed',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(
        _detail(_delivered(), refunds: [_refund(RefundStatus.rejected)]));
    await tester.pumpAndSettle();
    expect(find.text('Refund declined'), findsOneWidget);
    expect(find.text('Request a refund'), findsOneWidget);
  });

  testWidgets('buyer picks a line, gives a reason and submits',
      (tester) async {
    _tall(tester);
    final fake = _FakeRefunds();
    await tester.pumpWidget(ProviderScope(
      overrides: [refundServiceProvider.overrideWithValue(fake)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RefundRequestScreen(order: _delivered()))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Nothing selected yet: submit is disabled.
    final submit = find.widgetWithText(ElevatedButton, 'Submit request');
    expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('Refund amount: GHS 50.00'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Torn on arrival');
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(fake.sentQuantities, {'p1': 1});
    expect(fake.sentReason, 'Torn on arrival');
    expect(find.byType(RefundRequestScreen), findsNothing);
  });
}
