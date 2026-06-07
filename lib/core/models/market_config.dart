import 'package:flutter/foundation.dart';

import 'money.dart';

/// Per-country configuration for a market Shop Afrik operates in.
///
/// Shop Afrik serves **every country QR Wallet operates in** (~20+). A market
/// is data, not a type: it lives in config / platform settings keyed by ISO
/// country code. Adding a country is a config change (a new row), never a code
/// change — no logic should branch on a specific country code.
@immutable
class MarketConfig {
  const MarketConfig({
    required this.countryCode,
    required this.currency,
    required this.dialCode,
    required this.label,
    this.enabled = true,
    this.deliveryFeeMinor = 0,
    this.paymentFeeRate,
    this.minOrderMinor,
  });

  /// ISO-3166 alpha-2 country code, e.g. `GH`, `NG`. Also the map key.
  final String countryCode;

  /// ISO-4217 currency code for this market, e.g. `GHS`, `NGN`.
  final String currency;

  /// International dialing prefix, e.g. `+233`.
  final String dialCode;

  /// Human-readable country name.
  final String label;

  /// Whether buyers/sellers in this market can transact yet. Launch markets
  /// start enabled; expansion markets are added disabled, then flipped on.
  final bool enabled;

  /// Flat delivery fee in minor units of [currency] (basic delivery model).
  final int deliveryFeeMinor;

  /// Optional per-market payment-fee rate override; falls back to the global
  /// rate when null.
  final double? paymentFeeRate;

  /// Optional minimum order amount in minor units of [currency].
  final int? minOrderMinor;

  Money get deliveryFee =>
      Money(minorUnits: deliveryFeeMinor, currency: currency);

  Money? get minOrder => minOrderMinor == null
      ? null
      : Money(minorUnits: minOrderMinor!, currency: currency);

  Map<String, dynamic> toMap() => {
        'countryCode': countryCode,
        'currency': currency,
        'dialCode': dialCode,
        'label': label,
        'enabled': enabled,
        'deliveryFeeMinor': deliveryFeeMinor,
        'paymentFeeRate': paymentFeeRate,
        'minOrderMinor': minOrderMinor,
      };

  factory MarketConfig.fromMap(Map<String, dynamic> map) => MarketConfig(
        countryCode: map['countryCode'] as String? ?? '',
        currency: map['currency'] as String? ?? '',
        dialCode: map['dialCode'] as String? ?? '',
        label: map['label'] as String? ?? '',
        enabled: map['enabled'] as bool? ?? true,
        deliveryFeeMinor: (map['deliveryFeeMinor'] as num?)?.toInt() ?? 0,
        paymentFeeRate: (map['paymentFeeRate'] as num?)?.toDouble(),
        minOrderMinor: (map['minOrderMinor'] as num?)?.toInt(),
      );
}

/// Refund approval ceilings for a single currency, in **major** units of that
/// currency (plan §10). Keyed by currency so thresholds are never compared
/// across currencies.
@immutable
class RefundTierCeilings {
  const RefundTierCeilings({required this.tier1, required this.tier2});

  /// Single-admin approval ceiling.
  final num tier1;

  /// Admin + supervisor approval ceiling.
  final num tier2;

  Map<String, dynamic> toMap() => {'tier1': tier1, 'tier2': tier2};

  factory RefundTierCeilings.fromMap(Map<String, dynamic> map) =>
      RefundTierCeilings(
        tier1: map['tier1'] as num? ?? 0,
        tier2: map['tier2'] as num? ?? 0,
      );
}
