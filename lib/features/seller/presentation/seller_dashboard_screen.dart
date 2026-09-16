import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/seller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/session_controller.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../data/seller_repository.dart';
import 'seller_earnings_tab.dart';
import 'seller_orders_tab.dart';
import 'seller_products_tab.dart';

/// Seller shell: store header (rating), then Products / Orders / Earnings tabs.
class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seller = ref.watch(currentSellerProvider).valueOrNull;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seller Dashboard'),
          actions: [
            const NotificationsBell(),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Orders'),
              Tab(text: 'Earnings'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (seller != null) _StoreHeader(seller: seller),
            const Expanded(
              child: TabBarView(
                children: [
                  SellerProductsTab(),
                  SellerOrdersTab(),
                  SellerEarningsTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.sellerProductNew),
          icon: const Icon(Icons.add),
          label: const Text('Product'),
        ),
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.seller});
  final Seller seller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppColors.panelDark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seller.storeName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(seller.market,
                    style: const TextStyle(color: AppColors.mutedText)),
              ],
            ),
          ),
          const Icon(Icons.star, size: 18, color: AppColors.brightAqua),
          const SizedBox(width: 4),
          Text(
            seller.ratingCount == 0
                ? 'No ratings'
                : '${seller.ratingAverage.toStringAsFixed(1)} (${seller.ratingCount})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
