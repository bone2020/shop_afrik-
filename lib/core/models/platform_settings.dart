import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// Admin-configurable platform settings, stored at `settings/platform`
/// (plan §6, §10). This is the runtime source of truth for values the plan
/// describes as admin-configurable; [AppConfig] only provides seed defaults.
@immutable
class PlatformSettings {
  const PlatformSettings({
    this.commissionRate = AppConfig.defaultCommissionRate,
    this.paymentFeeRate = AppConfig.defaultPaymentFeeRate,
    this.deliveryFeeByMarket = AppConfig.defaultDeliveryFeeByMarket,
    this.refundWindowDays = 7,
    this.settlementDelayDays = 8,
    this.refundTier1Ceiling = AppConfig.refundTier1Ceiling,
    this.refundTier2Ceiling = AppConfig.refundTier2Ceiling,
    this.lowStockThresholdRatio = AppConfig.lowStockThresholdRatio,
    this.maxProductsPerSeller = AppConfig.maxProductsPerSeller,
    this.commissionByCategory = const {},
  });

  /// Global commission rate (plan §6: start at 15%).
  final double commissionRate;

  /// Buyer-paid payment processing fee, as a fraction of subtotal (plan §6).
  final double paymentFeeRate;

  /// Flat delivery fee per market in minor currency units (plan §3).
  final Map<String, int> deliveryFeeByMarket;
  final int refundWindowDays;
  final int settlementDelayDays;
  final num refundTier1Ceiling;
  final num refundTier2Ceiling;
  final double lowStockThresholdRatio;
  final int maxProductsPerSeller;

  /// Optional per-category overrides of [commissionRate] (plan §6 "later per
  /// category"), keyed by category id.
  final Map<String, double> commissionByCategory;

  /// Effective commission rate for a category, falling back to the global rate.
  double commissionFor(String? categoryId) =>
      commissionByCategory[categoryId] ?? commissionRate;

  Map<String, dynamic> toMap() => {
        'commissionRate': commissionRate,
        'paymentFeeRate': paymentFeeRate,
        'deliveryFeeByMarket': deliveryFeeByMarket,
        'refundWindowDays': refundWindowDays,
        'settlementDelayDays': settlementDelayDays,
        'refundTier1Ceiling': refundTier1Ceiling,
        'refundTier2Ceiling': refundTier2Ceiling,
        'lowStockThresholdRatio': lowStockThresholdRatio,
        'maxProductsPerSeller': maxProductsPerSeller,
        'commissionByCategory': commissionByCategory,
      };

  factory PlatformSettings.fromMap(Map<String, dynamic> map) => PlatformSettings(
        commissionRate: (map['commissionRate'] as num?)?.toDouble() ??
            AppConfig.defaultCommissionRate,
        paymentFeeRate: (map['paymentFeeRate'] as num?)?.toDouble() ??
            AppConfig.defaultPaymentFeeRate,
        deliveryFeeByMarket: (map['deliveryFeeByMarket'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ) ??
            AppConfig.defaultDeliveryFeeByMarket,
        refundWindowDays: (map['refundWindowDays'] as num?)?.toInt() ?? 7,
        settlementDelayDays: (map['settlementDelayDays'] as num?)?.toInt() ?? 8,
        refundTier1Ceiling:
            map['refundTier1Ceiling'] as num? ?? AppConfig.refundTier1Ceiling,
        refundTier2Ceiling:
            map['refundTier2Ceiling'] as num? ?? AppConfig.refundTier2Ceiling,
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
