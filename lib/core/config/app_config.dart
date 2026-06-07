import '../models/market_config.dart';

/// Static, build-time configuration and the MVP defaults from the project plan
/// (§6 Money/Refunds/Settlement, §10 Open Decisions).
///
/// Shop Afrik is a multi-country marketplace covering every country QR Wallet
/// operates in. Anything country- or currency-specific (markets, currencies,
/// fees, refund thresholds) is **data**, seeded here and overridable at runtime
/// via the platform settings document. Values the plan calls "admin
/// configurable" are mirrored here only as seed defaults; the runtime source of
/// truth is `settings/platform` in Firestore.
///
/// Adding country #3 … #22 means adding rows to [seedMarkets] (and
/// [seedRefundTiers] for any new currency) — or, in production, editing the
/// platform settings document. It never means changing logic.
abstract final class AppConfig {
  static const String appName = 'Shop Afrik';

  // --- Country-agnostic platform defaults ---

  /// Platform commission as a fraction of the seller subtotal (15%).
  static const double defaultCommissionRate = 0.15;

  /// Default payment processing fee charged to the buyer as a separate
  /// checkout line item (plan §6), as a fraction of the subtotal. Markets may
  /// override this per-row.
  static const double defaultPaymentFeeRate = 0.015;

  /// Refund window measured from courier-confirmed delivery.
  static const Duration refundWindow = Duration(days: 7);

  /// Auto-settlement fires the day after the refund window closes (day 8).
  static const Duration settlementDelay = Duration(days: 8);

  /// Low-stock alert threshold as a fraction of initial stock.
  static const double lowStockThresholdRatio = 0.20;

  /// Maximum products a single seller can list in v1.
  static const int maxProductsPerSeller = 500;

  // --- Seed market rows ---
  //
  // The ONLY place launch markets are named. Ghana and Nigeria are simply the
  // first two rows; the rest of QR Wallet's countries are added the same way.
  // No logic anywhere may assume this list has exactly two entries or branch on
  // a specific country code.
  static const Map<String, MarketConfig> seedMarkets = {
    'GH': MarketConfig(
      countryCode: 'GH',
      currency: 'GHS',
      dialCode: '+233',
      label: 'Ghana',
      enabled: true,
      deliveryFeeMinor: 1500, // GHS 15.00
    ),
    'NG': MarketConfig(
      countryCode: 'NG',
      currency: 'NGN',
      dialCode: '+234',
      label: 'Nigeria',
      enabled: true,
      deliveryFeeMinor: 150000, // NGN 1,500.00
    ),
  };

  // --- Seed refund-tier ceilings, keyed by currency (major units) ---
  //
  // Plan §10 quotes "NGN 50,000 / NGN 300,000 equivalent". Each currency
  // carries its own ceilings; they are never compared across currencies. The
  // GHS figures here are placeholder equivalents for admins to tune.
  static const Map<String, RefundTierCeilings> seedRefundTiers = {
    'NGN': RefundTierCeilings(tier1: 50000, tier2: 300000),
    'GHS': RefundTierCeilings(tier1: 600, tier2: 3600),
  };
}
