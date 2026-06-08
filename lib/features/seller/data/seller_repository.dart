import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/seller.dart';
import '../../../services/session_controller.dart';

/// Reads a seller's own store profile (rating, market, approval/KYC status).
abstract interface class SellerRepository {
  Stream<Seller?> watchSeller(String sellerId);
}

class FirestoreSellerRepository implements SellerRepository {
  FirestoreSellerRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<Seller?> watchSeller(String sellerId) {
    return _db
        .collection(Collections.sellers)
        .doc(sellerId)
        .snapshots()
        .map((d) => d.exists ? Seller.fromMap(d.id, d.data()!) : null);
  }
}

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  return FirestoreSellerRepository(FirebaseFirestore.instance);
});

/// The signed-in seller's profile.
final currentSellerProvider = StreamProvider.autoDispose<Seller?>((ref) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(sellerRepositoryProvider).watchSeller(uid);
});
