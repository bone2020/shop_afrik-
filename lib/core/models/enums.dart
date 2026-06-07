/// Shared status enums that encode the Shop Afrik state machines.
///
/// These mirror the lifecycle described in the project plan (§5 payment flow,
/// §6 money/refunds/settlement) and are kept in sync with the Cloud Functions
/// type definitions (`functions/src/types.ts`).
library;

/// Helper to resolve an enum from its stored string name with a safe default.
T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

// --- Catalog ---

/// Admin moderation state for a seller-submitted product.
enum ProductApprovalStatus {
  pending,
  approved,
  rejected;

  static ProductApprovalStatus fromName(String? n) =>
      _byName(values, n, pending);
}

// --- Sellers ---

/// QR Wallet KYC state. A seller cannot be approved until [verified].
enum KycStatus {
  notStarted,
  pending,
  verified,
  rejected;

  static KycStatus fromName(String? n) => _byName(values, n, notStarted);
}

/// Admin approval state for a seller account.
enum SellerApprovalStatus {
  pending,
  approved,
  suspended,
  rejected;

  static SellerApprovalStatus fromName(String? n) => _byName(values, n, pending);
}

// --- Orders ---

/// High-level order state (the customer-facing status).
enum OrderStatus {
  pendingPayment,
  paid,
  processing,
  shipped,
  delivered,
  completed,
  cancelled,
  refunded;

  static OrderStatus fromName(String? n) => _byName(values, n, pendingPayment);

  bool get isTerminal =>
      this == completed || this == cancelled || this == refunded;
}

/// Payment leg, driven by QR Wallet confirmation (plan §5).
enum PaymentStatus {
  pending,
  paid,
  failed,
  partiallyRefunded,
  refunded;

  static PaymentStatus fromName(String? n) => _byName(values, n, pending);
}

/// Delivery leg. The refund window opens at [deliveryConfirmed] (plan §6).
enum DeliveryStatus {
  notDispatched,
  dispatched,
  inTransit,
  delivered,
  deliveryConfirmed;

  static DeliveryStatus fromName(String? n) => _byName(values, n, notDispatched);
}

/// Settlement leg — proceeds held in the Shop Afrik business wallet until the
/// refund window closes, then paid out on day 8 (plan §6).
enum SettlementStatus {
  /// Order not yet eligible (not delivered / not paid).
  notDue,

  /// Eligible and queued for day-8 payout.
  scheduled,

  /// Paid out to the seller's QR Wallet.
  settled,

  /// Withheld due to an open refund/dispute.
  onHold,

  /// Released as a refund instead of being settled.
  reversed;

  static SettlementStatus fromName(String? n) => _byName(values, n, notDue);
}

// --- Refunds ---

/// Refund request lifecycle with tiered approval (plan §6, §10).
enum RefundStatus {
  requested,
  underReview,
  approved,
  rejected,

  /// Awaiting a second approver (tier 2: admin + supervisor).
  escalated,

  /// Money returned to the buyer via QR Wallet.
  refunded;

  static RefundStatus fromName(String? n) => _byName(values, n, requested);
}

/// Approval tier required for a refund, by amount (plan §10).
enum RefundTier {
  /// Single admin, up to the tier-1 ceiling.
  tier1,

  /// Admin + supervisor, up to the tier-2 ceiling.
  tier2,

  /// Above tier-2 ceiling — requires explicit escalation handling.
  exceptional;

  static RefundTier fromName(String? n) => _byName(values, n, tier1);
}

// --- Notifications ---

enum NotificationAudience {
  buyer,
  seller,
  admin;

  static NotificationAudience fromName(String? n) => _byName(values, n, buyer);
}
