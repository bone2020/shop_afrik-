import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/money.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/models/refund_request.dart';
import 'package:shop_afrik/core/models/seller.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/admin/data/admin_repository.dart';
import 'package:shop_afrik/features/admin/presentation/refund_queue_tab.dart';
import 'package:shop_afrik/features/admin/presentation/seller_approval_tab.dart';

class _FakeAdmin implements AdminRepository {
  _FakeAdmin({this.sellers = const [], this.refunds = const []});
  final List<Seller> sellers;
  final List<RefundRequest> refunds;

  @override
  Stream<List<Seller>> watchPendingSellers() => Stream.value(sellers);
  @override
  Stream<List<RefundRequest>> watchOpenRefunds() => Stream.value(refunds);
  @override
  Stream<List<ShopOrder>> watchOrdersAwaitingQuote() => const Stream.empty();
  @override
  Stream<List<ShopOrder>> watchShippedOrders() => const Stream.empty();
  @override
  Future<void> approveSeller({required String sellerId, required bool approve}) async {}
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

    final approveButtons =
        tester.widgetList<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Approve'));
    expect(approveButtons.length, 2);
    // Verified seller's Approve is enabled; unverified is disabled.
    expect(approveButtons.where((b) => b.onPressed != null).length, 1);
  });

  testWidgets('refund queue shows tier and per-currency amount', (tester) async {
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
    expect(find.widgetWithText(ElevatedButton, 'Approve (2nd)'), findsOneWidget);
  });
}
