import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/category.dart';
import '../../../core/models/product.dart';

/// Read access to the public catalog for buyers (approved, active products and
/// the category tree).
abstract interface class CatalogRepository {
  Stream<List<Category>> watchCategories();
  Stream<List<Product>> watchProducts({String? categoryId});
  Stream<Product?> watchProduct(String id);
}

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<Category>> watchCategories() {
    return _db
        .collection(Collections.categories)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Category.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
  }

  @override
  Stream<List<Product>> watchProducts({String? categoryId}) {
    Query<Map<String, dynamic>> q = _db
        .collection(Collections.products)
        .where('approvalStatus', isEqualTo: 'approved')
        .where('isActive', isEqualTo: true);
    if (categoryId != null) {
      q = q.where('categoryId', isEqualTo: categoryId);
    }
    return q.snapshots().map(
        (s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<Product?> watchProduct(String id) {
    return _db
        .collection(Collections.products)
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? Product.fromMap(d.id, d.data()!) : null);
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return FirestoreCatalogRepository(FirebaseFirestore.instance);
});

final categoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchCategories();
});

/// The buyer's current category filter (null = all categories).
final selectedCategoryProvider = StateProvider.autoDispose<String?>((_) => null);

/// The buyer's current free-text search query.
final searchQueryProvider = StateProvider.autoDispose<String>((_) => '');

/// Products for the selected category, then filtered client-side by the search
/// query (Firestore has no full-text search; this keeps it simple for the MVP).
final visibleProductsProvider =
    StreamProvider.autoDispose<List<Product>>((ref) {
  final categoryId = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  return ref
      .watch(catalogRepositoryProvider)
      .watchProducts(categoryId: categoryId)
      .map((products) {
    if (query.isEmpty) return products;
    return products
        .where((p) =>
            p.title.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query))
        .toList();
  });
});

final productProvider =
    StreamProvider.autoDispose.family<Product?, String>((ref, id) {
  return ref.watch(catalogRepositoryProvider).watchProduct(id);
});
