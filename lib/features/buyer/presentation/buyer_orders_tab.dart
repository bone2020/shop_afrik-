import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../../../services/session_controller.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/presentation/order_status_chip.dart';

class BuyerOrdersTab extends ConsumerWidget {
  const BuyerOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionControllerProvider).uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to see your orders.'));
    }
    final orders =
        ref.watch(_buyerOrdersProvider(uid));

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load your orders.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedText)),
        ),
      ),
      data: (items) => items.isEmpty
          ? const Center(
              child: Text('No orders yet.',
                  style: TextStyle(color: AppColors.mutedText)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final o = items[i];
                final count =
                    o.items.fold<int>(0, (s, it) => s + it.quantity);
                return Card(
                  child: ListTile(
                    title: Text('Order ${o.id.substring(0, o.id.length.clamp(0, 6))}'),
                    subtitle: Text('$count item(s) · ${formatMoney(o.total)}'),
                    trailing: OrderStatusChip(status: o.status),
                    onTap: () => context.push(Routes.buyerOrder(o.id)),
                  ),
                );
              },
            ),
    );
  }
}

final _buyerOrdersProvider = StreamProvider.autoDispose
    .family((ref, String uid) =>
        ref.watch(ordersRepositoryProvider).watchBuyerOrders(uid));
