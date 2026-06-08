import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/order.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/money_format.dart';
import '../application/cart_controller.dart';
import '../data/order_service.dart';

/// Checkout — phase 1 (Integration Spec v2 §5).
///
/// The buyer places the order and provides a delivery location. The total shown
/// here is items only; delivery is NOT included and is quoted by an admin
/// shortly after placement. No money is held at this step — payment happens
/// later, after the quote, from the order detail screen.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  String? _market;
  bool _placing = false;

  @override
  void dispose() {
    _recipient.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final settings = ref.watch(platformSettingsProvider).valueOrNull ??
        const PlatformSettings();

    if (lines.isEmpty || subtotal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }

    // Delivery markets matching the cart currency (never blend currencies).
    final markets = settings.enabledMarkets
        .where((m) => m.currency == subtotal.currency)
        .toList();
    final selected =
        _market ?? (markets.isNotEmpty ? markets.first.countryCode : null);

    final paymentFee = selected == null
        ? subtotal.applyRate(0)
        : subtotal.applyRate(settings.paymentFeeRateFor(selected));
    final itemsTotal = subtotal + paymentFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                    _Line('Items total', formatMoney(itemsTotal), bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _Banner(
              color: AppColors.brightAqua,
              text: 'Delivery is not included yet. We will add a delivery '
                  'quote shortly after you place the order, then ask you to pay '
                  'the full total.',
            ),
            const SizedBox(height: 16),
            Text('Delivery location',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (markets.isEmpty)
              const _Banner(
                color: AppColors.dangerCoral,
                text: 'No delivery market is configured for this currency yet.',
              )
            else
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use  // controlled by parent state
                value: selected,
                decoration: const InputDecoration(labelText: 'Country'),
                items: [
                  for (final m in markets)
                    DropdownMenuItem(value: m.countryCode, child: Text(m.label)),
                ],
                onChanged: (v) => setState(() => _market = v),
              ),
            const SizedBox(height: 12),
            _field(_recipient, 'Recipient name'),
            const SizedBox(height: 12),
            _field(_phone, 'Phone',
                keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_address, 'Address'),
            const SizedBox(height: 12),
            _field(_city, 'City / town'),
            const SizedBox(height: 12),
            _field(_region, 'Region / state (optional)', required: false),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (selected == null || _placing)
                  ? null
                  : () => _placeOrder(selected),
              child: _placing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Place order'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = true, TextInputType? keyboard}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Future<void> _placeOrder(String market) async {
    if (!_formKey.currentState!.validate()) return;
    final lines = ref.read(cartProvider);

    final location = DeliveryLocation(
      recipientName: _recipient.text.trim(),
      phone: _phone.text.trim(),
      addressLine: _address.text.trim(),
      city: _city.text.trim(),
      region: _region.text.trim().isEmpty ? null : _region.text.trim(),
      market: market,
    );

    setState(() => _placing = true);
    try {
      await ref.read(orderServiceProvider).placeOrder(
            items: [
              for (final l in lines)
                CartItemRef(productId: l.product.id, quantity: l.quantity),
            ],
            deliveryLocation: location,
          );
      if (!mounted) return;
      ref.read(cartProvider.notifier).clear();
      _showDialog(
        'Order placed',
        'Your order is placed and awaiting a delivery quote. We will notify '
            'you when it is ready to pay.',
        popTwice: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showDialog('Could not place order', '$e');
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _showDialog(String title, String message, {bool popTwice = false}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (popTwice) Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
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
