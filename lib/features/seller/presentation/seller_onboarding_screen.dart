import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/session_controller.dart';
import '../data/seller_application_service.dart';

/// Seller application form. Submitting creates a pending seller record that
/// feeds the admin approval queue; KYC (via QR Wallet) and approval follow.
class SellerOnboardingScreen extends ConsumerStatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  ConsumerState<SellerOnboardingScreen> createState() =>
      _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState
    extends ConsumerState<SellerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _store = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  String? _market;
  bool _busy = false;

  @override
  void dispose() {
    _store.dispose();
    _owner.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(platformSettingsProvider).valueOrNull ??
        const PlatformSettings();
    final markets = settings.enabledMarkets.toList();
    final selected = _market ??
        (markets.isNotEmpty ? markets.first.countryCode : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Become a seller')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Tell us about your store. After you submit, an admin reviews your '
              'application; you will complete KYC through QR Wallet before going '
              'live.',
              style: TextStyle(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _store,
              decoration: const InputDecoration(labelText: 'Store name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _owner,
              decoration: const InputDecoration(labelText: 'Owner name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use  // controlled by parent state
              value: selected,
              decoration: const InputDecoration(labelText: 'Market'),
              items: [
                for (final m in markets)
                  DropdownMenuItem(value: m.countryCode, child: Text(m.label)),
              ],
              onChanged: (v) => setState(() => _market = v),
              validator: (v) => v == null ? 'Choose a market' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (selected == null || _busy)
                  ? null
                  : () => _submit(selected),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit application'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(String market) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(sessionControllerProvider).uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(sellerApplicationServiceProvider).submit(
            userId: uid,
            storeName: _store.text.trim(),
            ownerName: _owner.text.trim(),
            market: market,
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Application submitted'),
          content: const Text(
              'Thanks! An admin will review your application. You will be '
              'notified once it is approved.'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
