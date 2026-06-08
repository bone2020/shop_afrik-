import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../../../services/session_controller.dart';
import '../../orders/presentation/order_status_chip.dart';
import '../application/seller_earnings.dart';

class SellerOrdersTab extends ConsumerWidget {
  const SellerOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionControllerProvider).uid;
    if (uid == null) return const SizedBox.shrink();
    final orders = ref.watch(sellerOrdersProvider(uid));

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message('Could not load orders.\n$e'),
      data: (items) => items.isEmpty
          ? const _Message('No orders yet.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final o = items[i];
                // Only this seller's lines from the (possibly multi-seller) order.
                final mine =
                    o.items.where((it) => it.sellerId == uid).toList();
                final units =
                    mine.fold<int>(0, (s, it) => s + it.quantity);
                final myTotal = mine.isEmpty
                    ? null
                    : mine
                        .map((it) => it.lineTotal)
                        .reduce((a, b) => a + b);
                return Card(
                  child: ListTile(
                    title: Text(
                        'Order ${o.id.substring(0, o.id.length.clamp(0, 6))}'),
                    subtitle: Text(myTotal == null
                        ? '$units item(s)'
                        : '$units item(s) · ${formatMoney(myTotal)}'),
                    trailing: OrderStatusChip(status: o.status),
                  ),
                );
              },
            ),
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
