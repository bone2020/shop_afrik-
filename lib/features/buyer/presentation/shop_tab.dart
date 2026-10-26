import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/catalog_repository.dart';
import 'widgets/product_card.dart';

/// Buyer catalog: search, category filter chips, market picker, and the
/// product grid, loaded a page at a time.
class ShopTab extends ConsumerWidget {
  const ShopTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final pager = ref.watch(catalogPagerProvider);
    final items = ref.watch(visibleProductsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search products',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: categories.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (cats) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: selectedCategory == null,
                    onTap: () =>
                        ref.read(selectedCategoryProvider.notifier).state = null,
                  ),
                  for (final c in cats)
                    _CategoryChip(
                      label: c.name,
                      selected: selectedCategory == c.id,
                      onTap: () => ref
                          .read(selectedCategoryProvider.notifier)
                          .state = c.id,
                    ),
                ],
              ),
            ),
          ),
          const _SortFilterBar(),
          const SizedBox(height: 4),
          Expanded(
            child: items.isEmpty
                ? (pager.loading
                    ? const Center(child: CircularProgressIndicator())
                    : pager.error != null
                        ? const _Message('Could not load products.')
                        : const _Message('No products found.'))
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => ProductCard(
                            product: items[i],
                            onTap: () =>
                                context.push(Routes.buyerProduct(items[i].id)),
                          ),
                        ),
                      ),
                      if (pager.hasMore || pager.loading)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Center(
                              child: pager.loading
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(
                                      onPressed: () => ref
                                          .read(catalogPagerProvider.notifier)
                                          .loadMore(),
                                      child: const Text('Load more'),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Sort order and market picker. The market decides which products (and so
/// which currency) the buyer sees.
class _SortFilterBar extends ConsumerWidget {
  const _SortFilterBar();

  static const _sortLabels = {
    ProductSort.newest: 'Newest',
    ProductSort.priceLowToHigh: 'Price ↑',
    ProductSort.priceHighToLow: 'Price ↓',
    ProductSort.topRated: 'Top rated',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(productSortProvider);
    final market = ref.watch(effectiveCatalogMarketProvider);
    final settings = ref.watch(platformSettingsProvider).valueOrNull ??
        const PlatformSettings();
    final markets = settings.enabledMarkets.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18, color: AppColors.mutedText),
          const SizedBox(width: 6),
          DropdownButton<ProductSort>(
            value: sort,
            underline: const SizedBox.shrink(),
            items: [
              for (final entry in _sortLabels.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) => v == null
                ? null
                : ref.read(productSortProvider.notifier).state = v,
          ),
          const Spacer(),
          const Icon(Icons.public, size: 18, color: AppColors.mutedText),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: markets.any((m) => m.countryCode == market) ? market : null,
            underline: const SizedBox.shrink(),
            items: [
              for (final m in markets)
                DropdownMenuItem(value: m.countryCode, child: Text(m.label)),
            ],
            onChanged: (v) =>
                ref.read(catalogMarketProvider.notifier).state = v,
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.deepTeal,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText)),
      ),
    );
  }
}
