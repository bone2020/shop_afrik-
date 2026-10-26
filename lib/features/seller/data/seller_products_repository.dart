import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/product.dart';

/// A seller's view of their own products, with create / update / remove.
/// Approval status and ratings are not writable here (enforced by the rules);
/// new products always start pending admin approval.
abstract interface class SellerProductsRepository {
  Stream<List<Product>> watchMyProducts(String sellerId);
  Future<void> create(Product product);
  Future<void> update(Product product);
  Future<void> setStock(String productId, int stock);
  /// Deletes a product, or archives it if it has ever been ordered (SA-044).
  /// Returns true when it was archived.
  Future<bool> remove(String productId);
}

class FirestoreSellerProductsRepository implements SellerProductsRepository {
  FirestoreSellerProductsRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.products);

  @override
  Stream<List<Product>> watchMyProducts(String sellerId) {
    return _col
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Product.fromMap(d.id, d.data()))
            .where((p) => !p.archived)
            .toList());
  }

  @override
  Future<void> create(Product product) async {
    final now = DateTime.now().toIso8601String();
    await _col.add({...product.toMap(), 'createdAt': now, 'updatedAt': now});
  }

  @override
  Future<void> update(Product product) async {
    // Never overwrite the creation time (the catalog is ordered by it) or the
    // market (fixed at creation; the rules reject changes).
    final data = product.toMap()
      ..remove('createdAt')
      ..remove('market');
    await _col.doc(product.id).update({
      ...data,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> setStock(String productId, int stock) async {
    await _col.doc(productId).update({
      'stock': stock,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<bool> remove(String productId) async {
    final res = await _functions
        .httpsCallable('removeProduct')
        .call({'productId': productId});
    return (res.data as Map?)?['archived'] == true;
  }
}

final sellerProductsRepositoryProvider =
    Provider<SellerProductsRepository>((ref) {
  return FirestoreSellerProductsRepository(
      FirebaseFirestore.instance, FirebaseFunctions.instance);
});
