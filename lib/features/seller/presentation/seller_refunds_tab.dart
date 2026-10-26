import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/refund_request.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/callable_error.dart';
import '../../../core/util/money_format.dart';
import '../../../services/session_controller.dart';
import '../data/seller_refunds_repository.dart';

/// Refund requests on the seller's orders (SA-055). While a request is
/// undecided the seller can give their side; admins see it when deciding.
class SellerRefundsTab extends ConsumerWidget {
  const SellerRefundsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(sellerRefundsProvider);
    return refunds.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load refunds.\n$e')),
      data: (list) => list.isEmpty
          ? const Center(
              child: Text('No refund requests on your orders.',
                  style: TextStyle(color: AppColors.mutedText)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _RefundCard(refund: list[i]),
            ),
    );
  }
}

String _statusLabel(RefundStatus s) => switch (s) {
      RefundStatus.requested => 'New',
      RefundStatus.underReview || RefundStatus.escalated => 'Under review',
      RefundStatus.approved => 'Approved, paying out',
      RefundStatus.refunded => 'Refunded to buyer',
      RefundStatus.rejected => 'Declined',
    };

class _RefundCard extends ConsumerStatefulWidget {
  const _RefundCard({required this.refund});
  final RefundRequest refund;

  @override
  ConsumerState<_RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends ConsumerState<_RefundCard> {
  late final TextEditingController _reply;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reply = TextEditingController(text: _myReply ?? '');
  }

  String? get _myReply {
    final uid = ref.read(sessionControllerProvider).uid;
    return widget.refund.sellerResponses[uid];
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(sellerRefundsRepositoryProvider)
          .respond(refundId: widget.refund.id, response: text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply sent to the Shop Afrik team.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(callableErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.refund;
    final canReply = r.status == RefundStatus.requested ||
        r.status == RefundStatus.underReview ||
        r.status == RefundStatus.escalated;
    const muted = TextStyle(color: AppColors.mutedText, fontSize: 13);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(formatMoney(r.amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Text(_statusLabel(r.status), style: muted),
              ],
            ),
            const SizedBox(height: 4),
            Text('Order ${r.orderId}', style: muted),
            const SizedBox(height: 8),
            Text('Buyer says: ${r.reason}'),
            const SizedBox(height: 12),
            if (canReply) ...[
              TextField(
                controller: _reply,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                    labelText: 'Your side (optional)',
                    hintText: 'E.g. the item was checked before dispatch'),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 140,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _send,
                    child: Text(_myReply == null ? 'Send reply' : 'Update reply'),
                  ),
                ),
              ),
            ] else if (_myReply != null)
              Text('You replied: $_myReply', style: muted),
          ],
        ),
      ),
    );
  }
}
