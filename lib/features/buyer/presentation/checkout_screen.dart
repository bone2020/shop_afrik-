import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/market_config.dart';
import '../../../core/models/money.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../application/cart_controller.dart';
import '../data/order_service.dart';

/// Checkout up to the payment step.
///
/// Deliberately does NOT include delivery in the total: the delivery model
/// (product-only vs admin-quoted-then-pay) is undecided, so delivery is
/// arranged after the order is placed. The payment step calls the real seam,
/// which is inert for now — we surface that honestly and never simulate a
/// successful payment.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _market;
  bool _placing = false;

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final settings =
        ref.watch(platformSettingsProvider).valueOrNull ??
            const PlatformSettings();

    if (lines.isEmpty || subtotal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }

    // Markets that can receive this cart: enabled and matching the cart's
    // currency (money is never blended across currencies).
    final markets = settings.enabledMarkets
        .where((m) => m.currency == subtotal.currency)
        .toList();
    final selected = _market ??
        (markets.isNotEmpty ? markets.first.countryCode : null);

    final paymentFee = selected == null
        ? Money.zero(subtotal.currency)
        : subtotal.applyRate(settings.paymentFeeRateFor(selected));
    final total = subtotal + paymentFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (markets.isEmpty)
            const _Banner(
              color: AppColors.dangerCoral,
              text: 'No delivery market is configured for this currency yet.',
            )
          else
            _MarketSelector(
              markets: markets,
              selected: selected,
              onChanged: (v) => setState(() => _market = v),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text('${l.quantity} × ${l.product.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          Text(formatMoney(l.lineTotal)),
                        ],
                      ),
                    ),
                  const Divider(),
                  _Line('Subtotal', formatMoney(subtotal)),
                  _Line('Payment fee', formatMoney(paymentFee)),
                  const Divider(),
                  _Line('Total due now', formatMoney(total), bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Banner(
            color: AppColors.deepTeal,
            text: 'Delivery is arranged after your order is placed and is not '
                'included in this total.',
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: (selected == null || _placing) ? null : _placeOrder,
            child: _placing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Place order & continue to payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    final lines = ref.read(cartProvider);
    final market = _market ??
        ref
            .read(platformSettingsProvider)
            .valueOrNull
            ?.enabledMarkets
            .firstOrNull
            ?.countryCode;
    if (market == null) return;

    setState(() => _placing = true);
    try {
      final result = await ref.read(orderServiceProvider).createOrder(
            items: [
              for (final l in lines)
                CartItemRef(productId: l.product.id, quantity: l.quantity),
            ],
            market: market,
          );
      if (!mounted) return;
      ref.read(cartProvider.notifier).clear();
      _showOutcome(result);
    } catch (e) {
      if (!mounted) return;
      _showError('$e');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _showOutcome(CreateOrderResult result) {
    // The order is recorded as pending payment. Payment collection is not yet
    // available (the wallet seam is inert) — say so plainly.
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Order placed'),
        content: Text(
          result.paymentConfigured
              ? 'Your order is awaiting payment. Open QR Wallet to pay.'
              : 'Your order (${result.orderId}) is saved as pending payment. '
                  'Payment is not available yet — the QR Wallet integration is '
                  'still being connected.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Could not place order'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _MarketSelector extends StatelessWidget {
  const _MarketSelector({
    required this.markets,
    required this.selected,
    required this.onChanged,
  });

  final List<MarketConfig> markets;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use  // controlled by parent state
      value: selected,
      decoration: const InputDecoration(labelText: 'Delivery country'),
      items: [
        for (final m in markets)
          DropdownMenuItem(value: m.countryCode, child: Text(m.label)),
      ],
      onChanged: onChanged,
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}
