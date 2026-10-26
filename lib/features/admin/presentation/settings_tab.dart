import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/market_config.dart';
import '../../../core/models/platform_settings.dart';
import '../../../core/models/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/callable_error.dart';
import '../../../services/session_controller.dart';
import '../data/admin_tools_repository.dart';

/// Platform settings editor (SA-133): commission and fees, the refund window
/// and settlement delay, markets, and refund tiers per currency. Supervisors
/// edit; other admins see the values read-only. The server validates and
/// audits every change, and the next checkout, refund or settlement uses it.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(platformSettingsProvider);
    final canEdit =
        ref.watch(sessionControllerProvider).adminTier == AdminTier.supervisor;
    return settings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load settings.\n$e')),
      // Rebuild the editor from scratch whenever the stored settings change.
      data: (s) => _SettingsEditor(
          key: ValueKey(s.toMap().toString()), settings: s, canEdit: canEdit),
    );
  }
}

double _rate(String text) =>
    ((double.tryParse(text.trim()) ?? double.nan) * 100).round() / 10000;

String _pct(double rate) {
  final p = rate * 100;
  return p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
}

class _SettingsEditor extends ConsumerStatefulWidget {
  const _SettingsEditor(
      {super.key, required this.settings, required this.canEdit});
  final PlatformSettings settings;
  final bool canEdit;

  @override
  ConsumerState<_SettingsEditor> createState() => _SettingsEditorState();
}

class _SettingsEditorState extends ConsumerState<_SettingsEditor> {
  late final PlatformSettings s = widget.settings;
  late final _commission = TextEditingController(text: _pct(s.commissionRate));
  late final _fee = TextEditingController(text: _pct(s.paymentFeeRate));
  late final _window =
      TextEditingController(text: '${s.refundWindowDays}');
  late final _delay =
      TextEditingController(text: '${s.settlementDelayDays}');
  late final Map<String, MarketConfig> _markets = {...s.markets};
  late final Map<String, (TextEditingController, TextEditingController)>
      _tiers = {
    for (final e in s.refundTiersByCurrency.entries)
      e.key: (
        TextEditingController(text: '${e.value.tier1}'),
        TextEditingController(text: '${e.value.tier2}'),
      ),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_commission, _fee, _window, _delay]) {
      c.dispose();
    }
    for (final (a, b) in _tiers.values) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _patch() {
    final patch = <String, dynamic>{};
    final commission = _rate(_commission.text);
    if (commission != s.commissionRate) patch['commissionRate'] = commission;
    final fee = _rate(_fee.text);
    if (fee != s.paymentFeeRate) patch['paymentFeeRate'] = fee;
    final window = int.tryParse(_window.text.trim());
    if (window != s.refundWindowDays) patch['refundWindowDays'] = window;
    final delay = int.tryParse(_delay.text.trim());
    if (delay != s.settlementDelayDays) patch['settlementDelayDays'] = delay;

    final markets = _markets.map((k, v) => MapEntry(k, v.toMap()
      ..removeWhere((_, value) => value == null)));
    final before = s.markets.map((k, v) => MapEntry(k, v.toMap()
      ..removeWhere((_, value) => value == null)));
    if (markets.toString() != before.toString()) patch['markets'] = markets;

    final tiers = {
      for (final e in _tiers.entries)
        e.key: {
          'tier1': num.tryParse(e.value.$1.text.trim()),
          'tier2': num.tryParse(e.value.$2.text.trim()),
        },
    };
    final tiersBefore =
        s.refundTiersByCurrency.map((k, v) => MapEntry(k, v.toMap()));
    if (tiers.toString() != tiersBefore.toString()) {
      patch['refundTiersByCurrency'] = tiers;
    }
    return patch;
  }

  Future<void> _save() async {
    final patch = _patch();
    if (patch.isEmpty) {
      _snack('Nothing changed.');
      return;
    }
    if (patch.values.any((v) => v == null || (v is double && v.isNaN))) {
      _snack('Check the numbers: every field needs a value.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminToolsRepositoryProvider).updateSettings(patch);
      _snack('Settings saved.');
    } catch (e) {
      _snack(callableErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addMarket() async {
    final m = await showDialog<_NewMarket>(
        context: context, builder: (_) => const _AddMarketDialog());
    if (m == null) return;
    if (_markets.containsKey(m.market.countryCode)) {
      _snack('${m.market.countryCode} is already a market.');
      return;
    }
    setState(() {
      _markets[m.market.countryCode] = m.market;
      _tiers.putIfAbsent(
        m.market.currency,
        () => (
          TextEditingController(text: m.tier1),
          TextEditingController(text: m.tier2),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.canEdit;
    final title = Theme.of(context).textTheme.titleMedium;
    final numbers = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    final whole = [FilteringTextInputFormatter.digitsOnly];

    Widget field(TextEditingController c, String label, String suffix,
            List<TextInputFormatter> formatters) =>
        TextField(
          controller: c,
          enabled: edit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: formatters,
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!edit)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Only a supervisor can change settings.',
                style: TextStyle(color: AppColors.mutedText)),
          ),
        Text('Fees', style: title),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: field(_commission, 'Commission', '%', numbers)),
          const SizedBox(width: 12),
          Expanded(child: field(_fee, 'Payment fee', '%', numbers)),
        ]),
        const SizedBox(height: 20),
        Text('Refunds and payouts', style: title),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: field(_window, 'Refund window', 'days', whole)),
          const SizedBox(width: 12),
          Expanded(child: field(_delay, 'Pay sellers after', 'days', whole)),
        ]),
        const SizedBox(height: 4),
        const Text('Sellers must be paid after the refund window closes.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Text('Markets', style: title)),
          if (edit)
            TextButton.icon(
              onPressed: _addMarket,
              icon: const Icon(Icons.add),
              label: const Text('Add market'),
            ),
        ]),
        for (final m in _markets.values)
          Card(
            child: SwitchListTile(
              title: Text('${m.label} (${m.countryCode})'),
              subtitle: Text('${m.currency} · ${m.dialCode}'),
              value: m.enabled,
              onChanged: edit
                  ? (on) => setState(() => _markets[m.countryCode] =
                      MarketConfig(
                        countryCode: m.countryCode,
                        currency: m.currency,
                        dialCode: m.dialCode,
                        label: m.label,
                        enabled: on,
                        paymentFeeRate: m.paymentFeeRate,
                        minOrderMinor: m.minOrderMinor,
                      ))
                  : null,
            ),
          ),
        const SizedBox(height: 20),
        Text('Refund approval limits', style: title),
        const SizedBox(height: 4),
        const Text(
            'In whole currency units. Up to tier 1 one admin approves; up to '
            'tier 2 a supervisor must also approve.',
            style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
        const SizedBox(height: 8),
        for (final e in _tiers.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 56, child: Text(e.key)),
              Expanded(child: field(e.value.$1, 'Tier 1', '', numbers)),
              const SizedBox(width: 12),
              Expanded(child: field(e.value.$2, 'Tier 2', '', numbers)),
            ]),
          ),
        const SizedBox(height: 20),
        if (edit)
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save settings'),
          ),
      ],
    );
  }
}

class _NewMarket {
  const _NewMarket(this.market, this.tier1, this.tier2);
  final MarketConfig market;
  final String tier1;
  final String tier2;
}

class _AddMarketDialog extends StatefulWidget {
  const _AddMarketDialog();

  @override
  State<_AddMarketDialog> createState() => _AddMarketDialogState();
}

class _AddMarketDialogState extends State<_AddMarketDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _currency = TextEditingController();
  final _dial = TextEditingController(text: '+');
  final _tier1 = TextEditingController();
  final _tier2 = TextEditingController();

  @override
  void dispose() {
    for (final c in [_code, _name, _currency, _dial, _tier1, _tier2]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      RegExp(r'^[A-Z]{2}$').hasMatch(_code.text.trim()) &&
      _name.text.trim().isNotEmpty &&
      RegExp(r'^[A-Z]{3}$').hasMatch(_currency.text.trim()) &&
      RegExp(r'^\+\d{1,4}$').hasMatch(_dial.text.trim());

  @override
  Widget build(BuildContext context) {
    final upper = [UpperCaseTextFormatter()];
    TextField f(TextEditingController c, String label,
            {List<TextInputFormatter>? formatters}) =>
        TextField(
          controller: c,
          inputFormatters: formatters,
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {}),
        );

    return AlertDialog(
      title: const Text('Add market'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'New markets start switched off. Turn one on once its refund '
                'limits are set.',
                style: TextStyle(color: AppColors.mutedText)),
            f(_code, 'Country code (e.g. KE)', formatters: upper),
            f(_name, 'Country name'),
            f(_currency, 'Currency code (e.g. KES)', formatters: upper),
            f(_dial, 'Dial code (e.g. +254)'),
            f(_tier1, 'Refund tier 1 (if new currency)'),
            f(_tier2, 'Refund tier 2 (if new currency)'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        TextButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop(_NewMarket(
                    MarketConfig(
                      countryCode: _code.text.trim(),
                      currency: _currency.text.trim(),
                      dialCode: _dial.text.trim(),
                      label: _name.text.trim(),
                      enabled: false,
                    ),
                    _tier1.text.trim(),
                    _tier2.text.trim(),
                  ))
              : null,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Upper-cases codes as they are typed.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
