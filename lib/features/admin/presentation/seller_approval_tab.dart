import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/seller.dart';
import '../../../core/theme/app_colors.dart';
import '../data/admin_repository.dart';

/// Seller approval queue. Approving grants the seller role (server-side) and
/// requires verified QR Wallet KYC; the action runs through the `approveSeller`
/// Cloud Function.
class SellerApprovalTab extends ConsumerWidget {
  const SellerApprovalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingSellersProvider);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message('Could not load the approval queue.\n$e'),
      data: (sellers) => sellers.isEmpty
          ? const _Message('No sellers awaiting approval.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sellers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SellerCard(seller: sellers[i]),
            ),
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
            if (!kycVerified)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'KYC must be verified before approval.',
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
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
                      onPressed: kycVerified ? () => _decide(true) : null,
                      child: const Text('Approve'),
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
      await ref
          .read(adminRepositoryProvider)
          .approveSeller(sellerId: widget.seller.id, approve: approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Seller approved' : 'Seller rejected')),
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
