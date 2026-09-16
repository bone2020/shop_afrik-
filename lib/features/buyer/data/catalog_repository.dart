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
  Stream<List<Product>> watchSellerProducts(String sellerId);
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

  @override
  Stream<List<Product>> watchSellerProducts(String sellerId) {
    return _db
        .collection(Collections.products)
        .where('sellerId', isEqualTo: sellerId)
        .where('approvalStatus', isEqualTo: 'approved')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return FirestoreCatalogRepository(FirebaseFirestore.instance);
});

final categoriesProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  return ref.watch(catalogRepositoryProvider).watchCategories();
});

/// How the catalog is sorted. Price sorts are currency-safe: they group by
/// currency and order within each group, never comparing amounts across
/// currencies.
enum ProductSort { newest, priceLowToHigh, priceHighToLow, topRated }

/// The buyer's current category filter (null = all categories).
final selectedCategoryProvider = StateProvider.autoDispose<String?>((_) => null);

/// Optional currency filter (null = all currencies).
final currencyFilterProvider = StateProvider.autoDispose<String?>((_) => null);

/// The buyer's current free-text search query.
final searchQueryProvider = StateProvider.autoDispose<String>((_) => '');

/// The buyer's current sort order.
final productSortProvider =
    StateProvider.autoDispose<ProductSort>((_) => ProductSort.newest);

/// Products for the selected category, filtered client-side by the search query
/// and optional currency, then sorted (Firestore has no full-text search; this
/// keeps it simple for the MVP).
final visibleProductsProvider =
    StreamProvider.autoDispose<List<Product>>((ref) {
  final categoryId = ref.watch(selectedCategoryProvider);
  final currency = ref.watch(currencyFilterProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(productSortProvider);

  return ref
      .watch(catalogRepositoryProvider)
      .watchProducts(categoryId: categoryId)
      .map((products) {
    var list = products;
    if (query.isNotEmpty) {
      list = list
          .where((p) =>
              p.title.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query))
          .toList();
    }
    if (currency != null) {
      list = list.where((p) => p.price.currency == currency).toList();
    } else {
      list = [...list];
    }
    sortProducts(list, sort);
    return list;
  });
});

/// Sorts [products] in place. Price comparisons are confined within a currency:
/// items are grouped by currency first, so amounts in different currencies are
/// never ranked against each other.
void sortProducts(List<Product> products, ProductSort sort) {
  switch (sort) {
    case ProductSort.newest:
      products.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
    case ProductSort.topRated:
      products.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
    case ProductSort.priceLowToHigh:
      products.sort((a, b) {
        final c = a.price.currency.compareTo(b.price.currency);
        return c != 0 ? c : a.price.minorUnits.compareTo(b.price.minorUnits);
      });
    case ProductSort.priceHighToLow:
      products.sort((a, b) {
        final c = a.price.currency.compareTo(b.price.currency);
        return c != 0 ? c : b.price.minorUnits.compareTo(a.price.minorUnits);
      });
  }
}

final productProvider =
    StreamProvider.autoDispose.family<Product?, String>((ref, id) {
  return ref.watch(catalogRepositoryProvider).watchProduct(id);
});

final sellerCatalogProvider =
    StreamProvider.autoDispose.family<List<Product>, String>((ref, sellerId) {
  return ref.watch(catalogRepositoryProvider).watchSellerProducts(sellerId);
});
