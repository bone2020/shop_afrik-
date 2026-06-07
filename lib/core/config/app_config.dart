/// Supported launch markets for Shop Afrik.
///
/// Plan §10 recommends starting with Ghana and Nigeria.
enum Market {
  ghana(code: 'GH', currency: 'GHS', dialCode: '+233', label: 'Ghana'),
  nigeria(code: 'NG', currency: 'NGN', dialCode: '+234', label: 'Nigeria');

  const Market({
    required this.code,
    required this.currency,
    required this.dialCode,
    required this.label,
  });

  final String code;
  final String currency;
  final String dialCode;
  final String label;
}

/// Static, build-time configuration and the MVP defaults captured in the
/// project plan (§6 Money/Refunds/Settlement, §10 Open Decisions).
///
/// Values that the plan describes as "admin-configurable" (commission,
/// refund tiers, low-stock threshold) are mirrored here only as seed
/// defaults; the source of truth at runtime is the platform settings
/// document in Firestore.
abstract final class AppConfig {
  static const String appName = 'Shop Afrik';

  /// Launch markets enabled for the MVP.
  static const List<Market> enabledMarkets = [Market.ghana, Market.nigeria];

  // --- Money & settlement (§6) ---

  /// Platform commission as a fraction of the seller subtotal (15%).
  static const double defaultCommissionRate = 0.15;

  /// Refund window measured from courier-confirmed delivery.
  static const Duration refundWindow = Duration(days: 7);

  /// Auto-settlement to the seller fires the day after the refund window
  /// closes (day 8 after delivery).
  static const Duration settlementDelay = Duration(days: 8);

  // --- Refund approval tiers (§10), in NGN-equivalent ---

  /// Tier 1: a single admin may approve refunds up to this amount.
  static const num refundTier1Ceiling = 50000;

  /// Tier 2: admin + supervisor approval up to this amount.
  static const num refundTier2Ceiling = 300000;

  // --- Inventory & catalog (§10) ---

  /// Low-stock alert threshold as a fraction of initial stock.
  static const double lowStockThresholdRatio = 0.20;

  /// Maximum products a single seller can list in v1.
  static const int maxProductsPerSeller = 500;
}
