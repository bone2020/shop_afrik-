import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../application/seller_earnings.dart';

/// What the seller is owed (payable), shown per currency. Figures stay empty
/// until the QR Wallet half exists and orders settle — that's expected.
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
        ],
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
