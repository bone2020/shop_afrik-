import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/data/platform_settings_repository.dart';
import 'package:shop_afrik/core/models/category.dart';
import 'package:shop_afrik/core/models/market_config.dart';
import 'package:shop_afrik/core/models/platform_settings.dart';
import 'package:shop_afrik/core/models/product.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/buyer/data/buyer_repository.dart';
import 'package:shop_afrik/features/buyer/data/catalog_repository.dart';
import 'package:shop_afrik/features/buyer/presentation/shop_tab.dart';

import 'support/fixtures.dart';

/// Pages [products] by market, [pageSize] at a time, recording each request.
class _FakeCatalog implements CatalogRepository {
  _FakeCatalog(this.products, this.categories, {this.pageSize = 20});
  final List<Product> products;
  final List<Category> categories;
  final int pageSize;
  final requests = <String>[];

  @override
  Stream<List<Category>> watchCategories() => Stream.value(categories);

  @override
  Future<ProductPage> fetchProducts({
    required String market,
    String? categoryId,
    Object? cursor,
    int limit = catalogPageSize,
  }) async {
    requests.add(market);
    final matching = products
        .where((p) =>
            p.market == market &&
            (categoryId == null || p.categoryId == categoryId))
        .toList();
    final start = (cursor as int?) ?? 0;
    final end = (start + pageSize).clamp(0, matching.length);
    return ProductPage(
      items: matching.sublist(start, end),
      cursor: end,
      hasMore: end < matching.length,
    );
  }

  @override
  Stream<Product?> watchProduct(String id) =>
      Stream.value(products.where((p) => p.id == id).firstOrNull);

  @override
  Stream<List<Product>> watchSellerProducts(String sellerId) =>
      Stream.value(products.where((p) => p.sellerId == sellerId).toList());
}

const _settings = PlatformSettings(markets: {
  'NG': MarketConfig(
      countryCode: 'NG', currency: 'NGN', dialCode: '+234', label: 'Nigeria'),
  'TN': MarketConfig(
      countryCode: 'TN', currency: 'TND', dialCode: '+216', label: 'Tunisia'),
});

Product _in(String market, Product p) => Product(
      id: p.id,
      sellerId: p.sellerId,
      title: p.title,
      description: p.description,
      price: p.price,
      categoryId: p.categoryId,
      images: p.images,
      stock: p.stock,
      initialStock: p.initialStock,
      approvalStatus: p.approvalStatus,
      market: market,
    );

Widget _app(_FakeCatalog catalog) => ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(catalog),
        platformSettingsProvider.overrideWith((ref) => Stream.value(_settings)),
        currentBuyerProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: ShopTab()),
      ),
    );

void main() {
  testWidgets('shows only the chosen market, with its currency decimals',
      (tester) async {
    final catalog = _FakeCatalog([
      _in('NG', testProduct(id: 'a', sellerId: 's1', priceMinor: 150000, currency: 'NGN')),
      _in('TN', testProduct(id: 'b', sellerId: 's2', priceMinor: 12345, currency: 'TND')),
    ], [const Category(id: 'cat1', name: 'Phones')]);

    await tester.pumpWidget(_app(catalog));
    await tester.pumpAndSettle();

    // Defaults to the first enabled market.
    expect(find.text('Product a'), findsOneWidget);
    expect(find.text('NGN 1,500.00'), findsOneWidget);
    expect(find.text('Product b'), findsNothing);
    expect(find.text('Phones'), findsOneWidget);

    await tester.tap(find.text('Nigeria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tunisia').last);
    await tester.pumpAndSettle();

    expect(find.text('Product a'), findsNothing);
    expect(find.text('TND 12.345'), findsOneWidget);
    expect(catalog.requests, ['NG', 'TN']);
  });

  testWidgets('loads the next page on demand', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final catalog = _FakeCatalog([
      for (var i = 0; i < 3; i++)
        _in('NG', testProduct(id: 'p$i', sellerId: 's1', priceMinor: 100, currency: 'NGN')),
    ], const [], pageSize: 2);

    await tester.pumpWidget(_app(catalog));
    await tester.pumpAndSettle();
    expect(find.text('Product p2'), findsNothing);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Product p2'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });
}
