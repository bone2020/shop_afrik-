import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/seller.dart';
import '../../../services/session_controller.dart';

/// Reads a seller's own store profile (rating, market, approval/KYC status).
abstract interface class SellerRepository {
  Stream<Seller?> watchSeller(String sellerId);

  /// Another seller's public store profile (name, market, logo, rating).
  Stream<Seller?> watchStore(String sellerId);
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

  @override
  Stream<Seller?> watchStore(String sellerId) {
    return _db
        .collection(Collections.stores)
        .doc(sellerId)
        .snapshots()
        .map((d) => d.exists && d.data()!['listed'] == true
            ? Seller.fromMap(d.id, d.data()!)
            : null);
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

/// Any seller's public profile, by id (for the storefront page).
/// A seller's public store profile, for buyers.
final sellerByIdProvider =
    StreamProvider.autoDispose.family<Seller?, String>((ref, id) {
  return ref.watch(sellerRepositoryProvider).watchStore(id);
});
