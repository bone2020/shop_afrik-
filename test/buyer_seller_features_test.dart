import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/money.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/models/product.dart';
import 'package:shop_afrik/core/models/refund_request.dart';
import 'package:shop_afrik/core/models/user_role.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/buyer/application/cart_controller.dart';
import 'package:shop_afrik/features/buyer/application/cart_sync.dart';
import 'package:shop_afrik/features/orders/presentation/order_receipt.dart';
import 'package:shop_afrik/features/seller/data/seller_refunds_repository.dart';
import 'package:shop_afrik/features/seller/presentation/seller_refunds_tab.dart';

import 'support/fixtures.dart';
import 'support/session.dart';

class _FakeCartStore implements CartStore {
  _FakeCartStore(this.saved, this.products);
  List<({String productId, int quantity})> saved;
  final Map<String, Product> products;
  final saves = <List<String>>[];

  @override
  Future<List<({String productId, int quantity})>> load(String uid) async =>
      saved;
  @override
  Future<void> save(String uid, List<CartLine> lines) async =>
      saves.add([for (final l in lines) '${l.product.id}x${l.quantity}']);
  @override
  Future<Product?> product(String productId) async => products[productId];
}

class _FakeSellerRefunds implements SellerRefundsRepository {
  _FakeSellerRefunds(this.list);
  final List<RefundRequest> list;
  final replies = <(String, String)>[];

  @override
  Stream<List<RefundRequest>> watchForSeller(String sellerId) =>
      Stream.value(list);
  @override
  Future<void> respond(
          {required String refundId, required String response}) async =>
      replies.add((refundId, response));
}

const _ghs = 'GHS';

void main() {
  group('cart saved between sessions (SA-045)', () {
    test('restores saved lines, drops unavailable ones, caps at stock',
        () async {
      final store = _FakeCartStore([
        (productId: 'a', quantity: 2),
        (productId: 'gone', quantity: 1),
        (productId: 'low', quantity: 9),
        (productId: 'ngn', quantity: 1),
      ], {
        'a': testProduct(id: 'a', sellerId: 's', priceMinor: 100, currency: _ghs),
        'low': testProduct(
            id: 'low', sellerId: 's', priceMinor: 100, currency: _ghs, stock: 3),
        'ngn': testProduct(
            id: 'ngn', sellerId: 's', priceMinor: 100, currency: 'NGN'),
      });
      final container = ProviderContainer(overrides: [
        stubSession(authedSession(UserRole.buyer)),
        cartStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      container.read(cartSyncProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final lines = container.read(cartProvider);
      expect([for (final l in lines) '${l.product.id}x${l.quantity}'],
          ['ax2', 'lowx3']);
      expect(store.saves.last, ['ax2', 'lowx3']);

      // Later changes are saved.
      container.read(cartProvider.notifier).setQuantity('a', 1);
      expect(store.saves.last, ['ax1', 'lowx3']);
    });

    test('a signed-out cart is not saved and signing out clears it',
        () async {
      final store = _FakeCartStore(const [], const {});
      final container = ProviderContainer(overrides: [
        stubSession(),
        cartStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      container.read(cartSyncProvider);
      container.read(cartProvider.notifier).add(
          testProduct(id: 'a', sellerId: 's', priceMinor: 100, currency: _ghs));
      await Future<void>.delayed(Duration.zero);
      expect(store.saves, isEmpty);
    });
  });

  group('receipts (SA-046)', () {
    final order = ShopOrder(
      id: 'ORD1',
      buyerId: 'b',
      items: [
        testItem(
            sellerId: 's',
            unitPriceMinor: 5000,
            currency: _ghs,
            quantity: 2,
            refundedQuantity: 1),
      ],
      subtotal: const Money(minorUnits: 10000, currency: _ghs),
      paymentFee: const Money(minorUnits: 150, currency: _ghs),
      deliveryFee: const Money(minorUnits: 1000, currency: _ghs),
      total: const Money(minorUnits: 11150, currency: _ghs),
      paymentMethod: PaymentMethod.payNow,
      paymentStatus: PaymentStatus.partiallyRefunded,
      qrWalletTxnId: 'TXN-9',
    );

    test('only paid orders have a receipt', () {
      expect(hasReceipt(order), isTrue);
      expect(
          hasReceipt(ShopOrder(
            id: 'x',
            buyerId: 'b',
            items: const [],
            subtotal: Money.zero(_ghs),
            paymentFee: Money.zero(_ghs),
            total: Money.zero(_ghs),
          )),
          isFalse);
    });

    test('lists lines, fees, total, refund and the wallet reference', () {
      final text = receiptText(order);
      expect(text, contains('Order: ORD1'));
      expect(text, contains('2 x item  GHS 50.00 each  GHS 100.00'));
      expect(text, contains('1 refunded'));
      expect(text, contains('Delivery: GHS 10.00'));
      expect(text, contains('Total paid: GHS 111.50'));
      expect(text, contains('Refunded: GHS 50.00'));
      expect(text, contains('QR Wallet ref: TXN-9'));
    });
  });

  group('seller refunds (SA-055)', () {
    Future<_FakeSellerRefunds> pump(
        WidgetTester tester, List<RefundRequest> list) async {
      final repo = _FakeSellerRefunds(list);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          stubSession(authedSession(UserRole.seller, uid: 'seller1')),
          sellerRefundsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
            theme: AppTheme.dark,
            home: const Scaffold(body: SellerRefundsTab())),
      ));
      await tester.pumpAndSettle();
      return repo;
    }

    RefundRequest refund(RefundStatus status,
            {Map<String, String> replies = const {}}) =>
        RefundRequest(
          id: 'r1',
          orderId: 'o1',
          buyerId: 'b',
          lines: const [],
          amount: const Money(minorUnits: 5000, currency: _ghs),
          reason: 'Torn on arrival',
          tier: RefundTier.tier1,
          status: status,
          sellerResponses: replies,
        );

    testWidgets('the seller replies to an open request', (tester) async {
      final repo = await pump(tester, [refund(RefundStatus.requested)]);
      expect(find.text('Buyer says: Torn on arrival'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Checked before dispatch');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send reply'));
      await tester.pumpAndSettle();
      expect(repo.replies, [('r1', 'Checked before dispatch')]);
    });

    testWidgets('a decided request shows the reply without a form',
        (tester) async {
      await pump(tester, [
        refund(RefundStatus.refunded, replies: {'seller1': 'Sorry about that'}),
      ]);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('You replied: Sorry about that'), findsOneWidget);
      expect(find.text('Refunded to buyer'), findsOneWidget);
    });
  });
}
