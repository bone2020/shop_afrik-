import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';

/// Submits a seller application. The seller document is created under the user's
/// own id, starting with KYC not-started and approval pending, which places it
/// in the admin approval queue (the rules require exactly these starting
/// values). Approval — granting the seller role — happens via the admin flow.
abstract interface class SellerApplicationService {
  Future<void> submit({
    required String userId,
    required String storeName,
    required String ownerName,
    required String market,
    String? phone,
  });
}

class FirestoreSellerApplicationService implements SellerApplicationService {
  FirestoreSellerApplicationService(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> submit({
    required String userId,
    required String storeName,
    required String ownerName,
    required String market,
    String? phone,
  }) async {
    await _db.collection(Collections.sellers).doc(userId).set({
      'storeName': storeName,
      'ownerName': ownerName,
      'market': market,
      'phone': phone,
      'kycStatus': 'notStarted',
      'approvalStatus': 'pending',
      'ratingAverage': 0,
      'ratingCount': 0,
      'productCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}

final sellerApplicationServiceProvider =
    Provider<SellerApplicationService>((ref) {
  return FirestoreSellerApplicationService(FirebaseFirestore.instance);
});
