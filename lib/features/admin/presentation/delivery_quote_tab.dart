import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/currency.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../data/admin_repository.dart';

/// Queue of orders awaiting a delivery quote (v2 §5). The admin sees the
/// delivery location and items total, enters a delivery price (in the order's
/// currency), and submits — moving the order to awaiting payment.
class DeliveryQuoteTab extends ConsumerWidget {
  const DeliveryQuoteTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersAwaitingQuoteProvider);

    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message('Could not load the quote queue.\n$e'),
      data: (items) => items.isEmpty
          ? const _Message('No orders awaiting a delivery quote.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _QuoteCard(order: items[i]),
            ),
    );
  }
}

class _QuoteCard extends ConsumerStatefulWidget {
  const _QuoteCard({required this.order});
  final ShopOrder order;

  @override
  ConsumerState<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends ConsumerState<_QuoteCard> {
  final _price = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final currency = o.total.currency;
    final loc = o.deliveryLocation;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ${o.id.substring(0, o.id.length.clamp(0, 6))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Items total: ${formatMoney(o.total)}',
                style: const TextStyle(color: AppColors.mutedText)),
            const SizedBox(height: 8),
            const Text('Deliver to:',
                style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
            Text(loc == null
                ? 'No location'
                : '${loc.recipientName} · ${loc.phone}\n${loc.summary}'),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Delivery price',
                prefixText: '$currency ',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                  labelText: 'Breakdown / note (optional)'),
            ),
            const SizedBox(height: 12),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: () => _submit(currency),
                child: const Text('Send quote'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(String currency) async {
    final major = double.tryParse(_price.text.trim());
    if (major == null || major < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid delivery price')),
      );
      return;
    }
    final minor = (major * CurrencyMeta.minorUnitsPer(currency)).round();

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).quoteDelivery(
            orderId: widget.order.id,
            deliveryFeeMinor: minor,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Quote sent')));
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
