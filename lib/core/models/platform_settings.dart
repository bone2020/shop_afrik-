import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'market_config.dart';

/// Admin-configurable platform settings, stored at `settings/platform`
/// (plan §6, §10). This is the runtime source of truth for everything the plan
/// describes as admin-configurable, including the full set of markets and the
/// per-currency refund thresholds. [AppConfig] only provides seed defaults.
///
/// Country/currency behaviour is read from here, keyed by country code or
/// currency — no logic branches on a specific country.
@immutable
class PlatformSettings {
  const PlatformSettings({
    this.commissionRate = AppConfig.defaultCommissionRate,
    this.paymentFeeRate = AppConfig.defaultPaymentFeeRate,
    this.markets = AppConfig.seedMarkets,
    this.refundTiersByCurrency = AppConfig.seedRefundTiers,
    this.refundWindowDays = 7,
    this.settlementDelayDays = 8,
    this.lowStockThresholdRatio = AppConfig.lowStockThresholdRatio,
    this.maxProductsPerSeller = AppConfig.maxProductsPerSeller,
    this.commissionByCategory = const {},
  });

  /// Global commission rate (plan §6: start at 15%).
  final double commissionRate;

  /// Global buyer-paid payment-fee rate; markets may override per-row.
  final double paymentFeeRate;

  /// Every market Shop Afrik operates in, keyed by ISO country code.
  final Map<String, MarketConfig> markets;

  /// Refund approval ceilings keyed by currency (never compared across
  /// currencies).
  final Map<String, RefundTierCeilings> refundTiersByCurrency;

  final int refundWindowDays;
  final int settlementDelayDays;
  final double lowStockThresholdRatio;
  final int maxProductsPerSeller;

  /// Optional per-category overrides of [commissionRate] (plan §6 "later per
  /// category"), keyed by category id.
  final Map<String, double> commissionByCategory;

  // --- lookups (config-driven; no hardcoded countries/currencies) ---

  /// Markets currently open for transactions.
  Iterable<MarketConfig> get enabledMarkets =>
      markets.values.where((m) => m.enabled);

  MarketConfig? marketFor(String countryCode) => markets[countryCode];

  bool isMarketEnabled(String countryCode) =>
      markets[countryCode]?.enabled ?? false;

  /// Effective payment-fee rate for a market (per-market override or global).
  double paymentFeeRateFor(String countryCode) =>
      markets[countryCode]?.paymentFeeRate ?? paymentFeeRate;

  /// Refund ceilings for a currency, or null if that currency is unconfigured.
  RefundTierCeilings? refundTiersFor(String currency) =>
      refundTiersByCurrency[currency];

  /// Effective commission rate for a category, falling back to the global rate.
  double commissionFor(String? categoryId) =>
      commissionByCategory[categoryId] ?? commissionRate;

  Map<String, dynamic> toMap() => {
        'commissionRate': commissionRate,
        'paymentFeeRate': paymentFeeRate,
        'markets': markets.map((k, v) => MapEntry(k, v.toMap())),
        'refundTiersByCurrency':
            refundTiersByCurrency.map((k, v) => MapEntry(k, v.toMap())),
        'refundWindowDays': refundWindowDays,
        'settlementDelayDays': settlementDelayDays,
        'lowStockThresholdRatio': lowStockThresholdRatio,
        'maxProductsPerSeller': maxProductsPerSeller,
        'commissionByCategory': commissionByCategory,
      };

  factory PlatformSettings.fromMap(Map<String, dynamic> map) => PlatformSettings(
        commissionRate: (map['commissionRate'] as num?)?.toDouble() ??
            AppConfig.defaultCommissionRate,
        paymentFeeRate: (map['paymentFeeRate'] as num?)?.toDouble() ??
            AppConfig.defaultPaymentFeeRate,
        markets: (map['markets'] as Map?)?.map(
              (k, v) => MapEntry(
                k as String,
                MarketConfig.fromMap((v as Map).cast<String, dynamic>()),
              ),
            ) ??
            AppConfig.seedMarkets,
        refundTiersByCurrency: (map['refundTiersByCurrency'] as Map?)?.map(
              (k, v) => MapEntry(
                k as String,
                RefundTierCeilings.fromMap((v as Map).cast<String, dynamic>()),
              ),
            ) ??
            AppConfig.seedRefundTiers,
        refundWindowDays: (map['refundWindowDays'] as num?)?.toInt() ?? 7,
        settlementDelayDays: (map['settlementDelayDays'] as num?)?.toInt() ?? 8,
        lowStockThresholdRatio:
            (map['lowStockThresholdRatio'] as num?)?.toDouble() ??
                AppConfig.lowStockThresholdRatio,
        maxProductsPerSeller: (map['maxProductsPerSeller'] as num?)?.toInt() ??
            AppConfig.maxProductsPerSeller,
        commissionByCategory:
            (map['commissionByCategory'] as Map?)?.map(
                  (k, v) => MapEntry(k as String, (v as num).toDouble()),
                ) ??
                const {},
      );
}
