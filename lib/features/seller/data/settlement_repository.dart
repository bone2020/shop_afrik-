import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/settlement.dart';
import '../../../services/session_controller.dart';

/// A seller's settlement records, newest first: one per order they were
/// paid (or are held) for (SA-066).
abstract interface class SettlementRepository {
  Stream<List<Settlement>> watchSellerSettlements(String sellerId,
      {int limit = 50});
}

class FirestoreSettlementRepository implements SettlementRepository {
  FirestoreSettlementRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Settlement>> watchSellerSettlements(String sellerId,
      {int limit = 50}) {
    return _db
        .collection(Collections.settlements)
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Settlement.fromMap(d.id, d.data())).toList());
  }
}

final settlementRepositoryProvider = Provider<SettlementRepository>((ref) {
  return FirestoreSettlementRepository(FirebaseFirestore.instance);
});

/// The signed-in seller's payout history.
final sellerSettlementsProvider =
    StreamProvider.autoDispose<List<Settlement>>((ref) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(settlementRepositoryProvider).watchSellerSettlements(uid);
});
