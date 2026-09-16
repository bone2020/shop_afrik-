import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/order.dart';
import '../../../core/models/review.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../../../services/session_controller.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/presentation/order_status_chip.dart';
import '../../reviews/data/reviews_repository.dart';
import '../data/order_service.dart';

/// Buyer order detail (v2 §5): totals, status, and the post-quote actions —
/// pay (now / on delivery), cancel (before shipping), and rate after delivery.
class BuyerOrderDetailScreen extends ConsumerWidget {
  const BuyerOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load this order.\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText)),
          ),
        ),
        data: (o) => o == null
            ? const Center(child: Text('Order not found.'))
            : _Detail(order: o),
      ),
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.order});
  final ShopOrder order;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Order ${o.id.substring(0, o.id.length.clamp(0, 6))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            OrderStatusChip(status: o.status),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final item in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('${item.quantity} × ${item.title}',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text(formatMoney(item.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(),
                _line('Subtotal', formatMoney(o.subtotal)),
                _line('Payment fee', formatMoney(o.paymentFee)),
                _line(
                  'Delivery',
                  o.deliveryFee == null
                      ? 'Not quoted yet'
                      : formatMoney(o.deliveryFee!),
                ),
                const Divider(),
                _line('Total', formatMoney(o.total), bold: true),
              ],
            ),
          ),
        ),
        if (o.deliveryLocation != null) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(o.deliveryLocation!.recipientName),
              subtitle: Text(o.deliveryLocation!.summary),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Tracking(order: o),
        const SizedBox(height: 16),
        ..._actions(o),
      ],
    );
  }

  List<Widget> _actions(ShopOrder o) {
    if (_busy) {
      return [const Center(child: CircularProgressIndicator())];
    }
    final widgets = <Widget>[];

    if (o.status == OrderStatus.awaitingDeliveryQuote) {
      widgets.add(const _Info(
          'Awaiting a delivery quote. We will notify you when it is ready.'));
    }

    if (o.status == OrderStatus.awaitingPayment) {
      widgets.addAll([
        Text('Pay ${formatMoney(o.total)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _pay(PaymentMethod.payNow),
          child: const Text('Pay now'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => _pay(PaymentMethod.payOnDelivery),
          child: const Text('Pay on delivery'),
        ),
      ]);
    }

    if (o.status.buyerCanCancel) {
      widgets.addAll([
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel order',
              style: TextStyle(color: AppColors.dangerCoral)),
        ),
      ]);
    }

    if (o.status == OrderStatus.delivered ||
        o.status == OrderStatus.completed) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(const Text('Rate your items',
          style: TextStyle(fontWeight: FontWeight.w600)));
      for (final item in o.items) {
        widgets.add(ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: TextButton(
            onPressed: () => _rate(o, item),
            child: const Text('Rate'),
          ),
        ));
      }
    }

    return widgets;
  }

  Widget _line(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }

  Future<void> _pay(PaymentMethod method) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(orderServiceProvider)
          .payOrder(orderId: widget.order.id, method: method);
      _snack('Payment confirmed.');
    } catch (e) {
      // The seam is inert for now — report the real failure, never fake success.
      _snack('Payment could not be completed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(orderServiceProvider).cancelOrder(widget.order.id);
      _snack('Order cancelled.');
    } catch (e) {
      _snack('Could not cancel: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(ShopOrder o, OrderItem item) async {
    final result = await showDialog<({int rating, String? comment})>(
      context: context,
      builder: (_) => _RatingDialog(productTitle: item.title),
    );
    if (result == null) return;

    final uid = ref.read(sessionControllerProvider).uid;
    final name = ref.read(sessionControllerProvider).displayName ?? 'Buyer';
    if (uid == null) return;

    try {
      await ref.read(reviewsRepositoryProvider).addReview(Review(
            id: '',
            productId: item.productId,
            buyerId: uid,
            orderId: o.id,
            rating: result.rating,
            buyerName: name,
            comment: result.comment,
          ));
      _snack('Thanks for your review.');
    } catch (e) {
      _snack('Could not submit review: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.productTitle});
  final String productTitle;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.productTitle}',
          maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  icon: Icon(i <= _rating ? Icons.star : Icons.star_border,
                      color: AppColors.brightAqua),
                  onPressed: () => setState(() => _rating = i),
                ),
            ],
          ),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(labelText: 'Comment (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop((
            rating: _rating,
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          )),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

/// A simple delivery-tracking timeline of the order's lifecycle milestones,
/// plus the captured proof of delivery once delivered.
class _Tracking extends StatelessWidget {
  const _Tracking({required this.order});
  final ShopOrder order;

  static const _steps = [
    'Order placed',
    'Delivery quoted',
    'Paid',
    'Shipped',
    'Delivered',
  ];

  int get _progress => switch (order.status) {
        OrderStatus.awaitingDeliveryQuote => 0,
        OrderStatus.awaitingPayment => 1,
        OrderStatus.confirmed => 2,
        OrderStatus.shipped => 3,
        OrderStatus.delivered => 4,
        OrderStatus.completed => 4,
        OrderStatus.cancelled => -1,
        OrderStatus.refunded => -1,
      };

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.refunded) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cancel_outlined,
              color: AppColors.dangerCoral),
          title: Text(order.status == OrderStatus.cancelled
              ? 'Order cancelled'
              : 'Order refunded'),
        ),
      );
    }

    final proof = order.deliveryProof;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tracking',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (var i = 0; i < _steps.length; i++)
              Row(
                children: [
                  Icon(
                    i <= _progress
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: i <= _progress
                        ? AppColors.primaryTeal
                        : AppColors.mutedText,
                  ),
                  const SizedBox(width: 10),
                  Text(_steps[i],
                      style: TextStyle(
                        color: i <= _progress
                            ? AppColors.primaryText
                            : AppColors.mutedText,
                      )),
                ],
              ),
            if (order.status == OrderStatus.completed)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Completed — seller settled.',
                    style: TextStyle(
                        color: AppColors.mutedText, fontSize: 12)),
              ),
            if (proof != null) ...[
              const Divider(height: 24),
              const Text('Proof of delivery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (proof.photoUrl != null)
                Text('Photo: ${proof.photoUrl}',
                    style: const TextStyle(
                        color: AppColors.mutedText, fontSize: 12)),
              if (proof.hasLocation)
                Text(
                    'Location: ${proof.latitude!.toStringAsFixed(5)}, '
                    '${proof.longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(
                        color: AppColors.mutedText, fontSize: 12)),
              if (proof.capturedAt != null)
                Text('Time: ${proof.capturedAt!.toLocal()}',
                    style: const TextStyle(
                        color: AppColors.mutedText, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}
