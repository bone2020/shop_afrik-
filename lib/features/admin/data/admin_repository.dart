import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/order.dart';
import '../../../core/models/refund_request.dart';
import '../../../core/models/seller.dart';

/// Admin read access to the approval queues plus the privileged action
/// callables. Seller approval and refund decisions are server-authoritative
/// (they grant roles / move money), so they go through Cloud Functions.
abstract interface class AdminRepository {
  Stream<List<Seller>> watchPendingSellers();
  Stream<List<RefundRequest>> watchOpenRefunds();
  Stream<List<ShopOrder>> watchOrdersAwaitingQuote();
  Future<void> approveSeller({required String sellerId, required bool approve});
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
}

class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<Seller>> watchPendingSellers() {
    return _db
        .collection(Collections.sellers)
        .where('approvalStatus', isEqualTo: 'pending')
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
        .map((s) => s.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList());
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

final pendingSellersProvider =
    StreamProvider.autoDispose<List<Seller>>((ref) {
  return ref.watch(adminRepositoryProvider).watchPendingSellers();
});

final openRefundsProvider =
    StreamProvider.autoDispose<List<RefundRequest>>((ref) {
  return ref.watch(adminRepositoryProvider).watchOpenRefunds();
});

final ordersAwaitingQuoteProvider =
    StreamProvider.autoDispose<List<ShopOrder>>((ref) {
  return ref.watch(adminRepositoryProvider).watchOrdersAwaitingQuote();
});
