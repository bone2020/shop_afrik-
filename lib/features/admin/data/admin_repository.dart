import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/order.dart';
import '../../../core/models/product.dart';
import '../../../core/models/refund_request.dart';
import '../../../core/models/seller.dart';
import '../../../core/models/staff_member.dart';

/// Admin read access to the approval queues plus the privileged action
/// callables. Seller approval and refund decisions are server-authoritative
/// (they grant roles / move money), so they go through Cloud Functions.
abstract interface class AdminRepository {
  Stream<List<Seller>> watchSellers(SellerApprovalStatus status);
  Stream<List<RefundRequest>> watchOpenRefunds();
  Stream<List<ShopOrder>> watchOrdersAwaitingQuote();
  Stream<List<ShopOrder>> watchOrdersToDispatch();
  Stream<List<StaffMember>> watchCouriers();
  Stream<List<Product>> watchPendingProducts();
  Future<void> approveProduct(
      {required String productId, required bool approve});
  Future<void> approveSeller({required String sellerId, required bool approve});
  Future<void> suspendSeller({
    required String sellerId,
    required bool suspend,
    String? reason,
  });
  Future<void> decideRefund({
    required String refundId,
    required bool approve,
    String? note,
  });
  Future<void> quoteDelivery({
    required String orderId,
    required int deliveryFeeMinor,
    String? note,
  });
  Future<void> markDelivered(String orderId);
  Future<void> assignCourier(
      {required String orderId, required String courierId});
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Seller>> watchSellers(SellerApprovalStatus status) {
    return _db
        .collection(Collections.sellers)
        .where('approvalStatus', isEqualTo: status.name)
        .snapshots()
        .map((s) => s.docs.map((d) => Seller.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<RefundRequest>> watchOpenRefunds() {
    return _db
        .collection(Collections.refundRequests)
        .where('status', whereIn: ['requested', 'underReview', 'escalated'])
        .snapshots()
        .map((s) =>
            s.docs.map((d) => RefundRequest.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<ShopOrder>> watchOrdersAwaitingQuote() {
    return _db
        .collection(Collections.orders)
        .where('status', isEqualTo: 'awaitingDeliveryQuote')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<ShopOrder>> watchOrdersToDispatch() {
    return _db
        .collection(Collections.orders)
        .where('status', whereIn: ['confirmed', 'shipped'])
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<StaffMember>> watchCouriers() {
    return _db
        .collection(Collections.staff)
        .where('role', isEqualTo: 'delivery')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => StaffMember.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> assignCourier({
    required String orderId,
    required String courierId,
  }) async {
    await _functions
        .httpsCallable('assignCourier')
        .call({'orderId': orderId, 'courierId': courierId});
  }

  @override
  Stream<List<Product>> watchPendingProducts() {
    return _db
        .collection(Collections.products)
        .where('approvalStatus', isEqualTo: 'pending')
        .snapshots()
        .map(
            (s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> approveProduct({
    required String productId,
    required bool approve,
  }) async {
    await _functions
        .httpsCallable('approveProduct')
        .call({'productId': productId, 'approve': approve});
  }

  @override
  Future<void> quoteDelivery({
    required String orderId,
    required int deliveryFeeMinor,
    String? note,
  }) async {
    await _functions.httpsCallable('quoteDelivery').call({
      'orderId': orderId,
      'deliveryFeeMinor': deliveryFeeMinor,
      if (note != null) 'note': note,
    });
  }

  @override
  Future<void> markDelivered(String orderId) async {
    await _functions.httpsCallable('markDelivered').call({'orderId': orderId});
  }

  @override
  Future<void> approveSeller({
    required String sellerId,
    required bool approve,
  }) async {
    await _functions
        .httpsCallable('approveSeller')
        .call({'sellerId': sellerId, 'approve': approve});
  }

  @override
  Future<void> suspendSeller({
    required String sellerId,
    required bool suspend,
    String? reason,
  }) async {
    await _functions.httpsCallable('suspendSeller').call({
      'sellerId': sellerId,
      'suspend': suspend,
      if (reason != null) 'reason': reason,
    });
  }

  @override
  Future<void> decideRefund({
    required String refundId,
    required bool approve,
    String? note,
  }) async {
    await _functions.httpsCallable('decideRefund').call({
      'refundId': refundId,
      'decision': approve ? 'approve' : 'reject',
      if (note != null) 'note': note,
    });
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return FirebaseAdminRepository(
      FirebaseFirestore.instance, FirebaseFunctions.instance);
});

final sellersByStatusProvider = StreamProvider.autoDispose
    .family<List<Seller>, SellerApprovalStatus>((ref, status) {
  return ref.watch(adminRepositoryProvider).watchSellers(status);
});

final openRefundsProvider =
    StreamProvider.autoDispose<List<RefundRequest>>((ref) {
  return ref.watch(adminRepositoryProvider).watchOpenRefunds();
});

final ordersAwaitingQuoteProvider =
    StreamProvider.autoDispose<List<ShopOrder>>((ref) {
  return ref.watch(adminRepositoryProvider).watchOrdersAwaitingQuote();
});

/// Paid orders still to be delivered: confirmed (assign a courier) or
/// shipped (in transit).
final ordersToDispatchProvider =
    StreamProvider.autoDispose<List<ShopOrder>>((ref) {
  return ref.watch(adminRepositoryProvider).watchOrdersToDispatch();
});

final couriersProvider = StreamProvider.autoDispose<List<StaffMember>>((ref) {
  return ref.watch(adminRepositoryProvider).watchCouriers();
});

final pendingProductsProvider =
    StreamProvider.autoDispose<List<Product>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingProducts();
});
