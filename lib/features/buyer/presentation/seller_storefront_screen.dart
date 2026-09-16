import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/seller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../seller/data/seller_repository.dart';
import '../data/catalog_repository.dart';
import 'widgets/product_card.dart';

/// Public per-seller storefront: the store profile and rating, plus their
/// approved products.
class SellerStorefrontScreen extends ConsumerWidget {
  const SellerStorefrontScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(sellerByIdProvider(sellerId));
    final products = ref.watch(sellerCatalogProvider(sellerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          seller.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (s) => s == null ? const SizedBox.shrink() : _Header(seller: s),
          ),
          const SizedBox(height: 16),
          Text('Products',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          products.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Could not load products.\n$e',
                style: const TextStyle(color: AppColors.mutedText)),
            data: (items) => items.isEmpty
                ? const Text('No products listed yet.',
                    style: TextStyle(color: AppColors.mutedText))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.seller});
  final Seller seller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.deepTeal,
              child: Icon(Icons.storefront, color: AppColors.primaryText),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(seller.storeName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 16, color: AppColors.brightAqua),
                      const SizedBox(width: 4),
                      Text(
                        seller.ratingCount == 0
                            ? 'No ratings yet'
                            : '${seller.ratingAverage.toStringAsFixed(1)} '
                                '(${seller.ratingCount})',
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
