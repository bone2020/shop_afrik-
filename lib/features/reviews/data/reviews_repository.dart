import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/review.dart';

/// Buyer reviews. A buyer reviews a product from a delivered order through
/// the `submitReview` function, which checks the order line, keeps one review
/// per line (sending again edits it) and recomputes ratings (SA-111).
abstract interface class ReviewsRepository {
  Future<void> submitReview({
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  });
  Stream<List<Review>> watchForProduct(String productId);
}

class FirestoreReviewsRepository implements ReviewsRepository {
  FirestoreReviewsRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<void> submitReview({
    required String orderId,
    required String productId,
    required int rating,
    String? comment,
  }) async {
    await _functions.httpsCallable('submitReview').call({
      'orderId': orderId,
      'productId': productId,
      'rating': rating,
      if (comment != null) 'comment': comment,
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
  return FirestoreReviewsRepository(
      FirebaseFirestore.instance, FirebaseFunctions.instance);
});

final productReviewsProvider =
    StreamProvider.autoDispose.family<List<Review>, String>((ref, productId) {
  return ref.watch(reviewsRepositoryProvider).watchForProduct(productId);
});
