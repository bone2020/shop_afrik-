import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/platform_balance.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../data/platform_balance_repository.dart';

/// The segregated Shop Afrik platform account, shown as three buckets **per
/// currency**: held in escrow, owed to sellers, and earned commission.
/// Currencies are never blended; only commission is revenue.
class PlatformBalancesView extends ConsumerWidget {
  const PlatformBalancesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(platformBalancesProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Platform account',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Held by QR Wallet. Each currency is shown separately; only '
          'commission is revenue.',
          style: TextStyle(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        balances.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorCard(message: '$e'),
          data: (rows) => rows.isEmpty
              ? const _EmptyCard()
              : Column(
                  children: [
                    for (final b in rows) _CurrencyBucketsCard(balance: b),
                  ],
                ),
        ),
      ],
    );
  }
}

class _CurrencyBucketsCard extends StatelessWidget {
  const _CurrencyBucketsCard({required this.balance});

  final PlatformBalance balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              balance.currency,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _BucketRow(
              label: 'Held in escrow',
              value: formatMoney(balance.escrow),
              hint: 'Buyer funds awaiting settlement or refund (liability)',
            ),
            const Divider(height: 20),
            _BucketRow(
              label: 'Owed to sellers',
              value: formatMoney(balance.payable),
              hint: 'Earnings not yet paid out (liability)',
            ),
            const Divider(height: 20),
            _BucketRow(
              label: 'Commission earned',
              value: formatMoney(balance.commission),
              hint: 'Revenue',
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.label,
    required this.value,
    required this.hint,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String hint;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 2),
              Text(hint,
                  style: const TextStyle(
                      color: AppColors.mutedText, fontSize: 12)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: emphasize ? AppColors.primaryTeal : AppColors.primaryText,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No platform activity yet. Balances appear here once orders are paid.',
          style: TextStyle(color: AppColors.mutedText),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Could not load platform balances',
                style: TextStyle(color: AppColors.dangerCoral)),
            const SizedBox(height: 8),
            Text(message,
                style:
                    const TextStyle(color: AppColors.mutedText, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
