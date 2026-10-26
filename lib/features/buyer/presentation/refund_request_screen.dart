import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/money.dart';
import '../../../core/models/order.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/callable_error.dart';
import '../../../core/util/money_format.dart';
import '../../../services/session_controller.dart';
import '../data/refund_service.dart';

/// Buyer asks for a refund on a delivered order (SA-053): picks the lines and
/// quantities, gives a reason and optional photos. The server decides what is
/// refundable and computes the amount; the total shown here is a preview.
class RefundRequestScreen extends ConsumerStatefulWidget {
  const RefundRequestScreen({super.key, required this.order});

  final ShopOrder order;

  @override
  ConsumerState<RefundRequestScreen> createState() =>
      _RefundRequestScreenState();
}

class _RefundRequestScreenState extends ConsumerState<RefundRequestScreen> {
  static const _maxPhotos = 5;

  final _reason = TextEditingController();
  final Map<String, int> _quantities = {};
  final List<String> _photos = [];
  bool _busy = false;
  String? _error;

  List<OrderItem> get _refundable => widget.order.items
      .where((i) => i.quantity - i.refundedQuantity > 0)
      .toList();

  /// A single-item order is refunded all-or-nothing (plan §6).
  bool get _singleItem => widget.order.items.length == 1;

  Money? get _preview {
    Money? total;
    for (final item in _refundable) {
      final qty = _quantities[item.productId] ?? 0;
      if (qty == 0) continue;
      final line = item.unitPrice * qty;
      total = total == null ? line : total + line;
    }
    return total;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Request a refund')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Which items?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final item in _refundable) _lineTile(item),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'What went wrong?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Photos (optional)',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in _photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(url,
                      width: 72, height: 72, fit: BoxFit.cover),
                ),
              if (_photos.length < _maxPhotos)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add photo'),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.dangerCoral)),
          ],
          const SizedBox(height: 20),
          if (preview != null)
            Text('Refund amount: ${formatMoney(preview)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _busy || preview == null ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit request'),
          ),
        ],
      ),
    );
  }

  Widget _lineTile(OrderItem item) {
    final remaining = item.quantity - item.refundedQuantity;
    final qty = _quantities[item.productId] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: qty > 0,
              onChanged: _busy
                  ? null
                  : (on) => setState(() => _quantities[item.productId] =
                      on == true ? (_singleItem ? remaining : 1) : 0),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${formatMoney(item.unitPrice)} each',
                      style: const TextStyle(color: AppColors.mutedText)),
                ],
              ),
            ),
            if (qty > 0 && !_singleItem && remaining > 1)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: qty > 1
                        ? () => setState(
                            () => _quantities[item.productId] = qty - 1)
                        : null,
                  ),
                  Text('$qty'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: qty < remaining
                        ? () => setState(
                            () => _quantities[item.productId] = qty + 1)
                        : null,
                  ),
                ],
              )
            else if (qty > 0)
              Text('× $qty'),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto() async {
    final uid = ref.read(sessionControllerProvider).uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      final url =
          await ref.read(refundServiceProvider).pickAndUploadEvidence(uid);
      if (url != null) setState(() => _photos.add(url));
    } catch (e) {
      setState(() => _error = 'Could not upload the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Please tell us what went wrong.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(refundServiceProvider).requestRefund(
            orderId: widget.order.id,
            quantities: _quantities,
            reason: _reason.text.trim(),
            evidenceUrls: _photos,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Refund requested. We will notify you of the decision.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = callableErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
