import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/settlement.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../application/seller_earnings.dart';
import '../data/settlement_repository.dart';

/// What the seller is owed (payable), shown per currency, then the payout
/// history: each settled or held order with its commission and payout
/// reference (SA-066).
class SellerEarningsTab extends ConsumerWidget {
  const SellerEarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payable = ref.watch(sellerPayableProvider);

    return payable.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message('Could not load earnings.\n$e'),
      data: (byCurrency) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Owed to you',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'Earnings from delivered orders, net of commission, awaiting '
            'settlement. Shown separately per currency.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 16),
          if (byCurrency.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nothing owed yet.',
                    style: TextStyle(color: AppColors.mutedText)),
              ),
            )
          else
            for (final entry in byCurrency.entries)
              Card(
                child: ListTile(
                  title: Text(entry.key),
                  trailing: Text(
                    formatMoney(entry.value),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryTeal),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          Text('Payout history',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const _PayoutHistory(),
        ],
      ),
    );
  }
}

class _PayoutHistory extends ConsumerWidget {
  const _PayoutHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settlements = ref.watch(sellerSettlementsProvider);
    return settlements.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Could not load payouts.\n$e',
          style: const TextStyle(color: AppColors.mutedText)),
      data: (list) => list.isEmpty
          ? const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No payouts yet.',
                    style: TextStyle(color: AppColors.mutedText)),
              ),
            )
          : Column(
              children: [for (final s in list) _PayoutCard(settlement: s)],
            ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.settlement});
  final Settlement settlement;

  @override
  Widget build(BuildContext context) {
    final s = settlement;
    final held = s.status == SettlementStatus.onHold;
    final when = s.settledAt ?? s.createdAt;
    final rate = s.commissionRate * 100;
    final pct = rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1);
    const muted = TextStyle(color: AppColors.mutedText, fontSize: 13);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order ${_short(s.orderId)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(
                  formatMoney(s.net),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: held ? AppColors.mutedText : AppColors.primaryTeal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                'Sales ${formatMoney(s.gross)} · commission $pct% '
                '${formatMoney(s.commission)}',
                style: muted),
            const SizedBox(height: 2),
            if (held)
              Text(
                s.holdReason == 'sellerSuspended'
                    ? 'On hold while your store is suspended'
                    : 'On hold',
                style: const TextStyle(
                    color: AppColors.dangerCoral, fontSize: 13),
              )
            else
              Text(
                [
                  if (when != null) _date(when),
                  if (s.qrWalletPayoutId != null)
                    'Ref ${s.qrWalletPayoutId}',
                ].join(' · '),
                style: muted,
              ),
          ],
        ),
      ),
    );
  }

  static String _short(String id) =>
      id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  static String _date(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
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
