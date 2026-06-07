/// Canonical Firestore collection names (plan §7 Core Data Model).
///
/// Keep these in one place so the app, the security rules, and the Cloud
/// Functions all agree on the same paths.
abstract final class Collections {
  static const String products = 'products';
  static const String categories = 'categories';
  static const String orders = 'orders';
  static const String sellers = 'sellers';
  static const String buyers = 'buyers';
  static const String reviews = 'reviews';
  static const String refundRequests = 'refund_requests';
  static const String settlements = 'settlements';
  static const String notifications = 'notifications';
  static const String adminAudit = 'admin_audit';

  /// Singleton document holding admin-configurable platform settings
  /// (commission rate, refund tiers, etc.). Path: settings/platform.
  static const String settings = 'settings';
  static const String platformSettingsDoc = 'platform';

  /// Shop Afrik's mirror of the QR Wallet platform account: the three buckets
  /// per currency, the ledger of moves, and reconciliation runs.
  static const String platformBalances = 'platform_balances';
  static const String platformLedger = 'platform_ledger';
  static const String reconciliations = 'reconciliations';
}
