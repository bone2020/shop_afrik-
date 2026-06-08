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

/// The order lifecycle (Integration Spec v2 §5 / §8 B1).
///
/// Money is only involved from [confirmed] onward, and the cancellation cutoff
/// is [shipped]: a buyer may cancel up to (but not including) shipping.
enum OrderStatus {
  /// Placed by the buyer; no money held. Awaiting an admin delivery quote.
  awaitingDeliveryQuote,

  /// Delivery quoted; the buyer must pay the full total (items + delivery).
  awaitingPayment,

  /// Buyer paid — captured (pay-now) or authorized as a hold (pay-on-delivery).
  /// Awaiting seller fulfillment.
  confirmed,

  /// Seller shipped. This is the cancellation cutoff.
  shipped,

  /// Delivery confirmed. For pay-on-delivery this is the capture trigger;
  /// it also opens the refund window.
  delivered,

  /// Refund window closed and seller settled.
  completed,

  /// Cancelled by the buyer before shipping (escrow refunded / hold released).
  cancelled,

  /// Refunded through the refund-request flow.
  refunded;

  static OrderStatus fromName(String? n) =>
      _byName(values, n, awaitingDeliveryQuote);

  bool get isTerminal =>
      this == completed || this == cancelled || this == refunded;

  /// Allowed forward transitions of the lifecycle state machine (§8 B1).
  static const Map<OrderStatus, Set<OrderStatus>> _transitions = {
    OrderStatus.awaitingDeliveryQuote: {
      OrderStatus.awaitingPayment,
      OrderStatus.cancelled,
    },
    OrderStatus.awaitingPayment: {
      OrderStatus.confirmed,
      OrderStatus.cancelled,
    },
    OrderStatus.confirmed: {
      OrderStatus.shipped,
      OrderStatus.cancelled,
    },
    OrderStatus.shipped: {
      OrderStatus.delivered,
    },
    OrderStatus.delivered: {
      OrderStatus.completed,
      OrderStatus.refunded,
    },
    OrderStatus.completed: {},
    OrderStatus.cancelled: {},
    OrderStatus.refunded: {},
  };

  bool canTransitionTo(OrderStatus next) =>
      _transitions[this]?.contains(next) ?? false;

  /// The buyer may cancel only before shipment (cutoff at [shipped]).
  bool get buyerCanCancel =>
      this == awaitingDeliveryQuote ||
      this == awaitingPayment ||
      this == confirmed;
}

/// How the buyer chose to pay once the order total is known (§5).
enum PaymentMethod {
  /// Money-in at checkout via the capture seam.
  payNow,

  /// Authorization hold at checkout via the hold seam; captured on delivery.
  payOnDelivery;

  static PaymentMethod? fromName(String? n) {
    for (final v in values) {
      if (v.name == n) return v;
    }
    return null;
  }
}

/// Payment money state (the seam calls that move it stay inert for now).
enum PaymentStatus {
  /// No money moved yet.
  pending,

  /// Pay-on-delivery authorization hold placed.
  held,

  /// Funds captured into escrow (pay-now at checkout, or pay-on-delivery on
  /// delivery).
  captured,

  /// Pay-on-delivery hold released (buyer cancelled before shipping).
  released,

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
