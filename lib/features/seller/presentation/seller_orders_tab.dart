import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../../../services/session_controller.dart';
import '../../orders/presentation/order_status_chip.dart';
import '../application/seller_earnings.dart';
import '../data/seller_order_service.dart';

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
              itemBuilder: (_, i) => _SellerOrderCard(order: items[i], sellerId: uid),
            ),
    );
  }
}

class _SellerOrderCard extends ConsumerStatefulWidget {
  const _SellerOrderCard({required this.order, required this.sellerId});
  final ShopOrder order;
  final String sellerId;

  @override
  ConsumerState<_SellerOrderCard> createState() => _SellerOrderCardState();
}

class _SellerOrderCardState extends ConsumerState<_SellerOrderCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final mine = o.items.where((it) => it.sellerId == widget.sellerId).toList();
    final units = mine.fold<int>(0, (s, it) => s + it.quantity);
    final myTotal = mine.isEmpty
        ? null
        : mine.map((it) => it.lineTotal).reduce((a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      'Order ${o.id.substring(0, o.id.length.clamp(0, 6))}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                OrderStatusChip(status: o.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(myTotal == null
                ? '$units item(s)'
                : '$units item(s) · ${formatMoney(myTotal)}'),
            // Fulfillment: a seller can ship once the order is confirmed (paid).
            if (o.status == OrderStatus.confirmed) ...[
              const SizedBox(height: 12),
              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _markShipped,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Mark shipped'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markShipped() async {
    setState(() => _busy = true);
    try {
      await ref.read(sellerOrderServiceProvider).markShipped(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Marked shipped')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
