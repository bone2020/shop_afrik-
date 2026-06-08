import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/session_controller.dart';
import '../../notifications/presentation/notifications_bell.dart';
import '../data/delivery_repository.dart';
import 'proof_of_delivery_screen.dart';

/// Delivery-person home: the list of packages to drop off (orders that have
/// shipped). Tapping one opens the proof-of-delivery flow.
class DeliveryHomeScreen extends ConsumerWidget {
  const DeliveryHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deliveries = ref.watch(assignedDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          const NotificationsBell(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: deliveries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message('Could not load deliveries.\n$e'),
        data: (orders) => orders.isEmpty
            ? const _Message('No deliveries to drop off right now.')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _DeliveryCard(order: orders[i]),
              ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.order});
  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    final loc = order.deliveryLocation;
    final units = order.items.fold<int>(0, (s, it) => s + it.quantity);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${order.id.substring(0, order.id.length.clamp(0, 6))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$units item(s)',
                style: const TextStyle(color: AppColors.mutedText)),
            const SizedBox(height: 8),
            if (loc != null) ...[
              Text(loc.recipientName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${loc.phone}\n${loc.summary}'),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProofOfDeliveryScreen(order: order),
                ),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan & confirm delivery'),
            ),
          ],
        ),
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
