import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/product.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../../reviews/data/reviews_repository.dart';
import '../application/cart_controller.dart';
import '../data/catalog_repository.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: product.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load product.\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText)),
          ),
        ),
        data: (p) => p == null
            ? const Center(child: Text('Product not found.'))
            : _Detail(product: p),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = product.images.isNotEmpty ? product.images.first : null;
    final canAdd = ref.read(cartProvider.notifier).canAdd(product);

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: image == null
                    ? Container(
                        color: AppColors.panelDark,
                        child: const Icon(Icons.image_outlined,
                            size: 64, color: AppColors.mutedText),
                      )
                    : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(product.price),
                      style: const TextStyle(
                        color: AppColors.primaryTeal,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 16, color: AppColors.brightAqua),
                        const SizedBox(width: 4),
                        Text(
                          product.ratingCount == 0
                              ? 'No ratings yet'
                              : '${product.ratingAverage.toStringAsFixed(1)} '
                                  '(${product.ratingCount})',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                        const Spacer(),
                        Text(
                          product.isOutOfStock
                              ? 'Out of stock'
                              : '${product.stock} in stock',
                          style: TextStyle(
                            color: product.isOutOfStock
                                ? AppColors.dangerCoral
                                : AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(product.description),
                    const SizedBox(height: 24),
                    _Reviews(productId: product.id),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: product.isPurchasable
                  ? () {
                      if (!canAdd) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Your cart holds a different currency. '
                                'Check out or clear it first.'),
                          ),
                        );
                        return;
                      }
                      ref.read(cartProvider.notifier).add(product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to cart')),
                      );
                    }
                  : null,
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(product.isOutOfStock ? 'Out of stock' : 'Add to cart'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Product reviews list (buyers write them from a delivered order).
class _Reviews extends ConsumerWidget {
  const _Reviews({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(productReviewsProvider(productId));
    return reviews.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return const Text('No reviews yet.',
              style: TextStyle(color: AppColors.mutedText));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reviews (${items.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final r in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 1; i <= 5; i++)
                          Icon(
                            i <= r.rating ? Icons.star : Icons.star_border,
                            size: 14,
                            color: AppColors.brightAqua,
                          ),
                        const SizedBox(width: 8),
                        Text(r.buyerName,
                            style: const TextStyle(
                                color: AppColors.mutedText, fontSize: 12)),
                      ],
                    ),
                    if (r.comment != null && r.comment!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(r.comment!),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
