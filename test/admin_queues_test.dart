import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/money.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/models/product.dart';
import 'package:shop_afrik/core/models/refund_request.dart';
import 'package:shop_afrik/core/models/seller.dart';
import 'package:shop_afrik/core/models/staff_member.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/admin/data/admin_repository.dart';
import 'package:shop_afrik/features/admin/presentation/product_approval_tab.dart';
import 'package:shop_afrik/features/admin/presentation/refund_queue_tab.dart';
import 'package:shop_afrik/features/admin/presentation/seller_approval_tab.dart';

import 'support/fixtures.dart';

class _FakeAdmin implements AdminRepository {
  _FakeAdmin({
    this.sellers = const [],
    this.refunds = const [],
    this.products = const [],
  });
  final List<Seller> sellers;
  final List<RefundRequest> refunds;
  final List<Product> products;
  final suspendCalls = <(String, bool, String?)>[];

  @override
  Stream<List<Seller>> watchSellers(SellerApprovalStatus status) =>
      Stream.value(sellers.where((s) => s.approvalStatus == status).toList());
  @override
  Future<void> suspendSeller({
    required String sellerId,
    required bool suspend,
    String? reason,
  }) async =>
      suspendCalls.add((sellerId, suspend, reason));
  @override
  Stream<List<RefundRequest>> watchOpenRefunds() => Stream.value(refunds);
  @override
  Stream<List<ShopOrder>> watchOrdersAwaitingQuote() => const Stream.empty();
  @override
  Stream<List<ShopOrder>> watchOrdersToDispatch() => const Stream.empty();
  @override
  Stream<List<StaffMember>> watchCouriers() => const Stream.empty();
  @override
  Stream<List<Product>> watchPendingProducts() => Stream.value(products);
  @override
  Future<void> approveProduct({
    required String productId,
    required bool approve,
  }) async {}
  @override
  Future<void> approveSeller(
      {required String sellerId, required bool approve}) async {}
  @override
  Future<void> decideRefund({
    required String refundId,
    required bool approve,
    String? note,
  }) async {}
  @override
  Future<void> quoteDelivery({
    required String orderId,
    required int deliveryFeeMinor,
    String? note,
  }) async {}
  @override
  Future<void> markDelivered(String orderId) async {}
  @override
  Future<void> assignCourier({
    required String orderId,
    required String courierId,
  }) async {}
}

Widget _wrap(Widget child, AdminRepository repo) => ProviderScope(
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child)),
    );

void main() {
  testWidgets('seller approval gates Approve on verified KYC', (tester) async {
    final repo = _FakeAdmin(sellers: [
      const Seller(
        id: 's1',
        storeName: 'Verified Store',
        ownerName: 'Ama',
        market: 'GH',
        kycStatus: KycStatus.verified,
      ),
      const Seller(
        id: 's2',
        storeName: 'Unverified Store',
        ownerName: 'Bola',
        market: 'NG',
        kycStatus: KycStatus.pending,
      ),
    ]);

    await tester.pumpWidget(_wrap(const SellerApprovalTab(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Verified Store'), findsOneWidget);
    expect(find.text('Unverified Store'), findsOneWidget);

    final approveButtons = tester.widgetList<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Approve'));
    expect(approveButtons.length, 2);
    // Verified seller's Approve is enabled; unverified is disabled.
    expect(approveButtons.where((b) => b.onPressed != null).length, 1);
  });

  testWidgets('admin suspends an approved seller with a reason',
      (tester) async {
    final repo = _FakeAdmin(sellers: [
      const Seller(
        id: 's1',
        storeName: 'Live Store',
        ownerName: 'Ama',
        market: 'GH',
        kycStatus: KycStatus.verified,
        approvalStatus: SellerApprovalStatus.approved,
      ),
    ]);

    await tester.pumpWidget(_wrap(const SellerApprovalTab(), repo));
    await tester.pumpAndSettle();
    expect(find.text('Live Store'), findsNothing);

    await tester.tap(find.text('Approved'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Suspend'));
    await tester.pumpAndSettle();

    // Suspend stays disabled until a reason is typed.
    final confirm = find.widgetWithText(TextButton, 'Suspend');
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Counterfeit goods');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(repo.suspendCalls, [('s1', true, 'Counterfeit goods')]);
  });

  testWidgets('suspended sellers show the reason and can be reinstated',
      (tester) async {
    final repo = _FakeAdmin(sellers: [
      const Seller(
        id: 's2',
        storeName: 'Paused Store',
        ownerName: 'Bola',
        market: 'GH',
        approvalStatus: SellerApprovalStatus.suspended,
        suspensionReason: 'Late deliveries',
      ),
    ]);

    await tester.pumpWidget(_wrap(const SellerApprovalTab(), repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspended'));
    await tester.pumpAndSettle();

    expect(find.text('Suspended: Late deliveries'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Reinstate'));
    await tester.pumpAndSettle();
    expect(repo.suspendCalls, [('s2', false, null)]);
  });

  testWidgets('product approval queue lists pending products', (tester) async {
    final repo = _FakeAdmin(products: [
      testProduct(
          id: 'p1', sellerId: 's1', priceMinor: 150000, currency: 'NGN'),
    ]);

    await tester.pumpWidget(_wrap(const ProductApprovalTab(), repo));
    await tester.pumpAndSettle();

    expect(find.text('Product p1'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Reject'), findsOneWidget);
  });

  testWidgets('refund queue shows tier and per-currency amount',
      (tester) async {
    final repo = _FakeAdmin(refunds: [
      const RefundRequest(
        id: 'r1',
        orderId: 'o1',
        buyerId: 'b1',
        lines: [],
        amount: Money(minorUnits: 1000000, currency: 'NGN'),
        reason: 'Damaged item',
        tier: RefundTier.tier2,
        status: RefundStatus.escalated,
        firstApproverId: 'admin1',
      ),
    ]);

    await tester.pumpWidget(_wrap(const RefundQueueTab(), repo));
    await tester.pumpAndSettle();

    expect(find.text('NGN 10,000.00'), findsOneWidget);
    expect(find.text('Tier 2'), findsOneWidget);
    expect(find.textContaining('second, senior approver'), findsWidgets);
    expect(
        find.widgetWithText(ElevatedButton, 'Approve (2nd)'), findsOneWidget);
  });
}
