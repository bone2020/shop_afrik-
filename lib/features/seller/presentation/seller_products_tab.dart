import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/product.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../../../services/session_controller.dart';
import '../data/seller_products_repository.dart';

class SellerProductsTab extends ConsumerWidget {
  const SellerProductsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionControllerProvider).uid;
    if (uid == null) return const SizedBox.shrink();
    final products = ref.watch(_myProductsProvider(uid));

    return products.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message('Could not load your products.\n$e'),
      data: (items) => items.isEmpty
          ? const _Message('No products yet. Tap + to add your first one.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ProductRow(product: items[i]),
            ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(product.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${formatMoney(product.price)} · ${product.stock} in stock'),
            const SizedBox(height: 6),
            _ApprovalBadge(status: product.approvalStatus),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push(Routes.sellerProductEdit(product.id)),
        ),
        onTap: () => context.push(Routes.sellerProductEdit(product.id)),
      ),
    );
  }
}

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.status});
  final ProductApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ProductApprovalStatus.pending => ('Pending review', AppColors.mutedText),
      ProductApprovalStatus.approved => ('Approved', AppColors.primaryTeal),
      ProductApprovalStatus.rejected => ('Rejected', AppColors.dangerCoral),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText)),
        ),
      );
}

final _myProductsProvider = StreamProvider.autoDispose
    .family((ref, String uid) =>
        ref.watch(sellerProductsRepositoryProvider).watchMyProducts(uid));
