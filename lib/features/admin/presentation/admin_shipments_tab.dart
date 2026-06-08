import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../data/admin_repository.dart';

/// Shipped orders awaiting delivery confirmation. Normally a delivery person
/// confirms via the proof-of-delivery scan; this is the admin backup for the
/// rare case the scan didn't happen.
class AdminShipmentsTab extends ConsumerWidget {
  const AdminShipmentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipped = ref.watch(shippedOrdersProvider);

    return shipped.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message('Could not load shipments.\n$e'),
      data: (orders) => orders.isEmpty
          ? const _Message('No shipments in transit.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ShipmentCard(order: orders[i]),
            ),
    );
  }
}

class _ShipmentCard extends ConsumerStatefulWidget {
  const _ShipmentCard({required this.order});
  final ShopOrder order;

  @override
  ConsumerState<_ShipmentCard> createState() => _ShipmentCardState();
}

class _ShipmentCardState extends ConsumerState<_ShipmentCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final loc = o.deliveryLocation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${o.id.substring(0, o.id.length.clamp(0, 6))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (loc != null) ...[
              const SizedBox(height: 4),
              Text(loc.summary,
                  style: const TextStyle(color: AppColors.mutedText)),
            ],
            const SizedBox(height: 12),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              OutlinedButton.icon(
                onPressed: _markDelivered,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark delivered (backup)'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markDelivered() async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).markDelivered(widget.order.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Marked delivered')));
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
