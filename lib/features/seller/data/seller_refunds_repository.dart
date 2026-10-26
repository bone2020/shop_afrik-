import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/refund_request.dart';
import '../../../services/session_controller.dart';

/// Refund requests on a seller's orders, and the seller's reply (SA-055).
abstract interface class SellerRefundsRepository {
  Stream<List<RefundRequest>> watchForSeller(String sellerId);
  Future<void> respond({required String refundId, required String response});
}

class FirebaseSellerRefundsRepository implements SellerRefundsRepository {
  FirebaseSellerRefundsRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<RefundRequest>> watchForSeller(String sellerId) {
    return _db
        .collection(Collections.refundRequests)
        .where('sellerIds', arrayContains: sellerId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => RefundRequest.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> respond(
      {required String refundId, required String response}) async {
    await _functions
        .httpsCallable('respondToRefund')
        .call({'refundId': refundId, 'response': response});
  }
}

final sellerRefundsRepositoryProvider =
    Provider<SellerRefundsRepository>((ref) {
  return FirebaseSellerRefundsRepository(
      FirebaseFirestore.instance, FirebaseFunctions.instance);
});

final sellerRefundsProvider =
    StreamProvider.autoDispose<List<RefundRequest>>((ref) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(sellerRefundsRepositoryProvider).watchForSeller(uid);
});
