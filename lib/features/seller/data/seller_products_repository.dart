import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/product.dart';

/// A seller's view of their own products, with create / update / delete.
/// Approval status and ratings are not writable here (enforced by the rules);
/// new products always start pending admin approval.
abstract interface class SellerProductsRepository {
  Stream<List<Product>> watchMyProducts(String sellerId);
  Future<void> create(Product product);
  Future<void> update(Product product);
  Future<void> setStock(String productId, int stock);
  Future<void> delete(String productId);
}

class FirestoreSellerProductsRepository implements SellerProductsRepository {
  FirestoreSellerProductsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(Collections.products);

  @override
  Stream<List<Product>> watchMyProducts(String sellerId) {
    return _col
        .where('sellerId', isEqualTo: sellerId)
        .snapshots()
        .map((s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> create(Product product) async {
    final now = DateTime.now().toIso8601String();
    await _col.add({...product.toMap(), 'createdAt': now, 'updatedAt': now});
  }

  @override
  Future<void> update(Product product) async {
    await _col.doc(product.id).update({
      ...product.toMap(),
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
  Future<void> delete(String productId) => _col.doc(productId).delete();
}

final sellerProductsRepositoryProvider =
    Provider<SellerProductsRepository>((ref) {
  return FirestoreSellerProductsRepository(FirebaseFirestore.instance);
});
