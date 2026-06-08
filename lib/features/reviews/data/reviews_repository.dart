import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/review.dart';

/// Buyer reviews. A buyer may review a product from a delivered order (the
/// rules require the author to own the review and a 1–5 rating; verified-
/// purchase enforcement is server-side).
abstract interface class ReviewsRepository {
  Future<void> addReview(Review review);
  Stream<List<Review>> watchForProduct(String productId);
}

class FirestoreReviewsRepository implements ReviewsRepository {
  FirestoreReviewsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> addReview(Review review) async {
    await _db.collection(Collections.reviews).add({
      ...review.toMap(),
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Stream<List<Review>> watchForProduct(String productId) {
    return _db
        .collection(Collections.reviews)
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((s) => s.docs.map((d) => Review.fromMap(d.id, d.data())).toList());
  }
}

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return FirestoreReviewsRepository(FirebaseFirestore.instance);
});

final productReviewsProvider =
    StreamProvider.autoDispose.family<List<Review>, String>((ref, productId) {
  return ref.watch(reviewsRepositoryProvider).watchForProduct(productId);
});
