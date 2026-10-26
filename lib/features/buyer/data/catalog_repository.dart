import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/category.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/models/product.dart';
import 'buyer_repository.dart';

/// One page of catalog results. [cursor] is opaque: pass it back to fetch the
/// next page.
class ProductPage {
  const ProductPage({required this.items, this.cursor, required this.hasMore});
  final List<Product> items;
  final Object? cursor;
  final bool hasMore;
}

/// Read access to the public catalog for buyers (approved, active products and
/// the category tree).
abstract interface class CatalogRepository {
  Stream<List<Category>> watchCategories();

  /// Newest-first page of approved, active products in [market] (SA-103).
  Future<ProductPage> fetchProducts({
    required String market,
    String? categoryId,
    Object? cursor,
    int limit = catalogPageSize,
  });
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
  Future<ProductPage> fetchProducts({
    required String market,
    String? categoryId,
    Object? cursor,
    int limit = catalogPageSize,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection(Collections.products)
        .where('approvalStatus', isEqualTo: 'approved')
        .where('isActive', isEqualTo: true)
        .where('market', isEqualTo: market);
    if (categoryId != null) {
      q = q.where('categoryId', isEqualTo: categoryId);
    }
    q = q.orderBy('createdAt', descending: true).limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return ProductPage(
      items: snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList(),
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
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

/// Products per catalog page.
const catalogPageSize = 20;

/// The market the buyer is browsing (null = their default). Market decides
/// currency, so there is no separate currency filter.
final catalogMarketProvider = StateProvider<String?>((_) => null);

/// The market actually browsed: the buyer's choice, else the market of their
/// default address, else the first enabled market.
final effectiveCatalogMarketProvider = Provider.autoDispose<String?>((ref) {
  final chosen = ref.watch(catalogMarketProvider);
  if (chosen != null) return chosen;
  final settings = ref.watch(platformSettingsProvider).valueOrNull ??
      const PlatformSettings();
  final enabled = settings.enabledMarkets.map((m) => m.countryCode).toList();
  final home = ref.watch(currentBuyerProvider).valueOrNull?.defaultAddress?.market;
  if (home != null && enabled.contains(home)) return home;
  return enabled.isEmpty ? null : enabled.first;
});

/// The buyer's current free-text search query.
final searchQueryProvider = StateProvider.autoDispose<String>((_) => '');

/// The buyer's current sort order.
final productSortProvider =
    StateProvider.autoDispose<ProductSort>((_) => ProductSort.newest);

/// Loaded catalog pages for the current market and category.
class CatalogState {
  const CatalogState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.loading = false,
    this.error,
  });
  final List<Product> items;
  final Object? cursor;
  final bool hasMore;
  final bool loading;
  final Object? error;
}

/// Pages through the catalog 20 products at a time (SA-103). Changing the
/// market or category starts again from the first page.
class CatalogPager extends AutoDisposeNotifier<CatalogState> {
  // Bumped on every rebuild (market or category change) so a page that
  // arrives for an old query is dropped instead of appended.
  int _generation = 0;
  bool _inFlight = false;

  @override
  CatalogState build() {
    ref.watch(effectiveCatalogMarketProvider);
    ref.watch(selectedCategoryProvider);
    _generation++;
    _inFlight = false;
    Future.microtask(loadMore);
    return const CatalogState(loading: true);
  }

  Future<void> loadMore() async {
    if (_inFlight) return;
    final market = ref.read(effectiveCatalogMarketProvider);
    if (market == null) {
      state = const CatalogState(hasMore: false);
      return;
    }
    final current = state;
    if (!current.hasMore) return;
    final generation = _generation;
    _inFlight = true;
    state = CatalogState(
        items: current.items, cursor: current.cursor, loading: true);
    try {
      final page = await ref.read(catalogRepositoryProvider).fetchProducts(
            market: market,
            categoryId: ref.read(selectedCategoryProvider),
            cursor: current.cursor,
          );
      if (generation != _generation) return;
      state = CatalogState(
        items: [...current.items, ...page.items],
        cursor: page.cursor,
        hasMore: page.hasMore,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = CatalogState(
          items: current.items, cursor: current.cursor, error: e);
    } finally {
      if (generation == _generation) _inFlight = false;
    }
  }
}

final catalogPagerProvider =
    AutoDisposeNotifierProvider<CatalogPager, CatalogState>(CatalogPager.new);

/// Loaded products filtered client-side by the search query, then sorted.
/// Firestore has no full-text search, so search covers the pages loaded so
/// far; server-side search is SA-104.
final visibleProductsProvider = Provider.autoDispose<List<Product>>((ref) {
  final products = ref.watch(catalogPagerProvider).items;
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final sort = ref.watch(productSortProvider);

  var list = products;
  if (query.isNotEmpty) {
    list = list
        .where((p) =>
            p.title.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query))
        .toList();
  } else {
    list = [...list];
  }
  sortProducts(list, sort);
  return list;
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
