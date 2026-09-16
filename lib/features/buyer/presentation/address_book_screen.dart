import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/buyer.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/session_controller.dart';
import '../data/buyer_repository.dart';

/// Buyer address book: saved delivery locations reused at checkout.
class AddressBookScreen extends ConsumerWidget {
  const AddressBookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buyer = ref.watch(currentBuyerProvider);
    final uid = ref.watch(sessionControllerProvider).uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved addresses')),
      floatingActionButton: FloatingActionButton(
        onPressed: uid == null ? null : () => _edit(context, ref, uid, null),
        child: const Icon(Icons.add),
      ),
      body: buyer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message('Could not load addresses.\n$e'),
        data: (b) {
          final addresses = b?.addresses ?? const [];
          if (addresses.isEmpty) {
            return const _Message('No saved addresses. Tap + to add one.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = addresses[i];
              return Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Text(a.label.isEmpty ? a.recipientName : a.label),
                      if (a.isDefault) ...[
                        const SizedBox(width: 8),
                        const _DefaultBadge(),
                      ],
                    ],
                  ),
                  subtitle: Text('${a.recipientName} · ${a.phone}\n'
                      '${[a.line1, a.city, a.market].join(', ')}'),
                  isThreeLine: true,
                  trailing: uid == null
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _edit(context, ref, uid, a);
                            if (v == 'default') {
                              ref
                                  .read(buyerRepositoryProvider)
                                  .setDefaultAddress(uid, a.id);
                            }
                            if (v == 'delete') {
                              ref
                                  .read(buyerRepositoryProvider)
                                  .deleteAddress(uid, a.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'default',
                                child: Text('Set as default')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, String uid, Address? existing) async {
    final saved = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (_) => _AddressEditScreen(existing: existing)),
    );
    if (saved != null) {
      await ref.read(buyerRepositoryProvider).upsertAddress(uid, saved);
    }
  }
}

class _AddressEditScreen extends ConsumerStatefulWidget {
  const _AddressEditScreen({this.existing});
  final Address? existing;

  @override
  ConsumerState<_AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends ConsumerState<_AddressEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.existing?.label ?? '');
  late final _recipient =
      TextEditingController(text: widget.existing?.recipientName ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _line1 = TextEditingController(text: widget.existing?.line1 ?? '');
  late final _city = TextEditingController(text: widget.existing?.city ?? '');
  late final _region =
      TextEditingController(text: widget.existing?.region ?? '');
  String? _market;
  late bool _isDefault = widget.existing?.isDefault ?? false;

  @override
  void dispose() {
    for (final c in [_label, _recipient, _phone, _line1, _city, _region]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(platformSettingsProvider).valueOrNull ??
        const PlatformSettings();
    final markets = settings.enabledMarkets.toList();
    final selected = _market ??
        widget.existing?.market ??
        (markets.isNotEmpty ? markets.first.countryCode : null);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null ? 'New address' : 'Edit address')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_label, 'Label (e.g. Home)', required: false),
            const SizedBox(height: 12),
            _field(_recipient, 'Recipient name'),
            const SizedBox(height: 12),
            _field(_phone, 'Phone', keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_line1, 'Address'),
            const SizedBox(height: 12),
            _field(_city, 'City / town'),
            const SizedBox(height: 12),
            _field(_region, 'Region / state (optional)', required: false),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use  // controlled by parent state
              value: selected,
              decoration: const InputDecoration(labelText: 'Country'),
              items: [
                for (final m in markets)
                  DropdownMenuItem(value: m.countryCode, child: Text(m.label)),
              ],
              onChanged: (v) => setState(() => _market = v),
              validator: (v) => v == null ? 'Choose a country' : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default address'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: selected == null ? null : () => _save(selected),
              child: const Text('Save address'),
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

  void _save(String market) {
    if (!_formKey.currentState!.validate()) return;
    final address = Address(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      label: _label.text.trim(),
      recipientName: _recipient.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      city: _city.text.trim(),
      region: _region.text.trim().isEmpty ? null : _region.text.trim(),
      market: market,
      isDefault: _isDefault,
    );
    Navigator.of(context).pop(address);
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('Default',
          style: TextStyle(
              color: AppColors.primaryTeal,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
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
