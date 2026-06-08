import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/refund_request.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../data/admin_repository.dart';

/// Refund approval queue with tiered approval (server-enforced):
/// tier 1 needs one admin; tier 2 / exceptional need two distinct admins, the
/// second a supervisor.
class RefundQueueTab extends ConsumerWidget {
  const RefundQueueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(openRefundsProvider);

    return refunds.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message('Could not load the refund queue.\n$e'),
      data: (items) => items.isEmpty
          ? const _Message('No refunds awaiting a decision.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _TierNote(),
                const SizedBox(height: 12),
                for (final r in items) _RefundCard(refund: r),
              ],
            ),
    );
  }
}

class _TierNote extends StatelessWidget {
  const _TierNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.deepTeal.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Tier 1 refunds need one admin. Tier 2 and exceptional refunds need a '
        'second approval from a different, senior admin (supervisor).',
        style: TextStyle(fontSize: 13),
      ),
    );
  }
}

class _RefundCard extends ConsumerStatefulWidget {
  const _RefundCard({required this.refund});
  final RefundRequest refund;

  @override
  ConsumerState<_RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends ConsumerState<_RefundCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.refund;
    final awaitingSecond = r.status == RefundStatus.escalated;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatMoney(r.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                _TierBadge(tier: r.tier),
              ],
            ),
            const SizedBox(height: 6),
            Text('Order ${r.orderId}',
                style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
            const SizedBox(height: 8),
            Text(r.reason),
            if (awaitingSecond)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Awaiting a second, senior approver (different from the first).',
                  style: TextStyle(color: AppColors.brightAqua, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _decide(false),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _decide(true),
                      child: Text(awaitingSecond ? 'Approve (2nd)' : 'Approve'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).decideRefund(
            refundId: widget.refund.id,
            approve: approve,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Decision recorded' : 'Refund rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});
  final RefundTier tier;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tier) {
      RefundTier.tier1 => ('Tier 1', AppColors.primaryTeal),
      RefundTier.tier2 => ('Tier 2', AppColors.brightAqua),
      RefundTier.exceptional => ('Exceptional', AppColors.dangerCoral),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
