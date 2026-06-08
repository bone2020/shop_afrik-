import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/category.dart';
import 'package:shop_afrik/core/models/product.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/buyer/data/catalog_repository.dart';
import 'package:shop_afrik/features/buyer/presentation/shop_tab.dart';

import 'support/fixtures.dart';

class _FakeCatalog implements CatalogRepository {
  _FakeCatalog(this.products, this.categories);
  final List<Product> products;
  final List<Category> categories;

  @override
  Stream<List<Category>> watchCategories() => Stream.value(categories);

  @override
  Stream<List<Product>> watchProducts({String? categoryId}) => Stream.value(
      categoryId == null
          ? products
          : products.where((p) => p.categoryId == categoryId).toList());

  @override
  Stream<Product?> watchProduct(String id) =>
      Stream.value(products.where((p) => p.id == id).firstOrNull);
}

void main() {
  testWidgets('renders products and price with the right currency decimals',
      (tester) async {
    final products = [
      testProduct(id: 'a', sellerId: 's1', priceMinor: 150000, currency: 'NGN'),
      testProduct(id: 'b', sellerId: 's2', priceMinor: 12345, currency: 'TND'),
    ];
    final cats = [const Category(id: 'cat1', name: 'Phones')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider
              .overrideWithValue(_FakeCatalog(products, cats)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: ShopTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product a'), findsOneWidget);
    expect(find.text('Product b'), findsOneWidget);
    expect(find.text('NGN 1,500.00'), findsOneWidget);
    expect(find.text('TND 12.345'), findsOneWidget);
    expect(find.text('Phones'), findsOneWidget);
  });
}
