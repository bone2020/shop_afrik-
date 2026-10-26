import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/seller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/callable_error.dart';
import '../data/admin_repository.dart';

/// Sellers by status. Pending sellers are approved or rejected (approval
/// grants the seller role server-side and requires verified QR Wallet KYC);
/// approved sellers can be suspended with a reason and suspended ones
/// reinstated (SA-063). Both actions run through Cloud Functions.
class SellerApprovalTab extends ConsumerStatefulWidget {
  const SellerApprovalTab({super.key});

  @override
  ConsumerState<SellerApprovalTab> createState() => _SellerApprovalTabState();
}

class _SellerApprovalTabState extends ConsumerState<SellerApprovalTab> {
  SellerApprovalStatus _status = SellerApprovalStatus.pending;

  static const _empty = {
    SellerApprovalStatus.pending: 'No sellers awaiting approval.',
    SellerApprovalStatus.approved: 'No approved sellers yet.',
    SellerApprovalStatus.suspended: 'No suspended sellers.',
  };

  @override
  Widget build(BuildContext context) {
    final sellers = ref.watch(sellersByStatusProvider(_status));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SegmentedButton<SellerApprovalStatus>(
            segments: const [
              ButtonSegment(
                  value: SellerApprovalStatus.pending, label: Text('Pending')),
              ButtonSegment(
                  value: SellerApprovalStatus.approved,
                  label: Text('Approved')),
              ButtonSegment(
                  value: SellerApprovalStatus.suspended,
                  label: Text('Suspended')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ),
        Expanded(
          child: sellers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message('Could not load sellers.\n$e'),
            data: (list) => list.isEmpty
                ? _Message(_empty[_status]!)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SellerCard(seller: list[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SellerCard extends ConsumerStatefulWidget {
  const _SellerCard({required this.seller});
  final Seller seller;

  @override
  ConsumerState<_SellerCard> createState() => _SellerCardState();
}

class _SellerCardState extends ConsumerState<_SellerCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.seller;
    final kycVerified = s.kycStatus == KycStatus.verified;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.storeName,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('${s.ownerName} · ${s.market}',
                style: const TextStyle(color: AppColors.mutedText)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  kycVerified ? Icons.verified : Icons.gpp_maybe,
                  size: 16,
                  color:
                      kycVerified ? AppColors.primaryTeal : AppColors.dangerCoral,
                ),
                const SizedBox(width: 6),
                Text(
                  'KYC: ${s.kycStatus.name}',
                  style: TextStyle(
                    color: kycVerified
                        ? AppColors.primaryTeal
                        : AppColors.dangerCoral,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (s.approvalStatus == SellerApprovalStatus.pending &&
                !kycVerified)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'KYC must be verified before approval.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ),
            if (s.approvalStatus == SellerApprovalStatus.suspended)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Suspended: ${s.suspensionReason ?? 'no reason recorded'}',
                  style: const TextStyle(
                      color: AppColors.dangerCoral, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            if (_busy)
              const Center(child: CircularProgressIndicator())
            else
              _actions(s, kycVerified),
          ],
        ),
      ),
    );
  }

  Widget _actions(Seller s, bool kycVerified) {
    switch (s.approvalStatus) {
      case SellerApprovalStatus.pending:
        return Row(
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
                onPressed: kycVerified ? () => _decide(true) : null,
                child: const Text('Approve'),
              ),
            ),
          ],
        );
      case SellerApprovalStatus.approved:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerCoral),
            onPressed: _suspend,
            child: const Text('Suspend'),
          ),
        );
      case SellerApprovalStatus.suspended:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _run(
              () => ref
                  .read(adminRepositoryProvider)
                  .suspendSeller(sellerId: s.id, suspend: false),
              'Seller reinstated',
            ),
            child: const Text('Reinstate'),
          ),
        );
      case SellerApprovalStatus.rejected:
        return const SizedBox.shrink();
    }
  }

  Future<void> _suspend() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _SuspendDialog(),
    );
    if (reason == null) return;
    await _run(
      () => ref.read(adminRepositoryProvider).suspendSeller(
          sellerId: widget.seller.id, suspend: true, reason: reason),
      'Seller suspended',
    );
  }

  Future<void> _decide(bool approve) => _run(
        () => ref
            .read(adminRepositoryProvider)
            .approveSeller(sellerId: widget.seller.id, approve: approve),
        approve ? 'Seller approved' : 'Seller rejected',
      );

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action failed: ${callableErrorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Asks for the suspension reason, which the seller sees in their
/// notification.
class _SuspendDialog extends StatefulWidget {
  const _SuspendDialog();

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Suspend seller'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Their products are hidden from the catalog and their payouts are '
            'held until you reinstate them.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text('Suspend'),
        ),
      ],
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
