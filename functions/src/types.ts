// Shared types for Shop Afrik Cloud Functions. These mirror the Dart models
// in `lib/core/models` and the status enums in `lib/core/models/enums.dart`.

export const Collections = {
  products: 'products',
  categories: 'categories',
  orders: 'orders',
  sellers: 'sellers',
  buyers: 'buyers',
  reviews: 'reviews',
  refundRequests: 'refund_requests',
  settlements: 'settlements',
  notifications: 'notifications',
  adminAudit: 'admin_audit',
  settings: 'settings',
} as const;

export const PLATFORM_SETTINGS_DOC = 'platform';

export type OrderStatus =
  | 'pendingPayment'
  | 'paid'
  | 'processing'
  | 'shipped'
  | 'delivered'
  | 'completed'
  | 'cancelled'
  | 'refunded';

export type PaymentStatus =
  | 'pending'
  | 'paid'
  | 'failed'
  | 'partiallyRefunded'
  | 'refunded';

export type DeliveryStatus =
  | 'notDispatched'
  | 'dispatched'
  | 'inTransit'
  | 'delivered'
  | 'deliveryConfirmed';

export type SettlementStatus =
  | 'notDue'
  | 'scheduled'
  | 'settled'
  | 'onHold'
  | 'reversed';

export type RefundStatus =
  | 'requested'
  | 'underReview'
  | 'approved'
  | 'rejected'
  | 'escalated'
  | 'refunded';

export type RefundTier = 'tier1' | 'tier2' | 'exceptional';

export type UserRole = 'buyer' | 'seller' | 'admin';
export type AdminTier = 'admin' | 'supervisor';

/** A currency amount in integer minor units (mirrors Dart `Money`). */
export interface Money {
  minorUnits: number;
  currency: string;
}

export interface OrderItem {
  productId: string;
  sellerId: string;
  title: string;
  unitPrice: Money;
  quantity: number;
  imageUrl?: string | null;
  refundedQuantity: number;
}

export const money = (minorUnits: number, currency: string): Money => ({
  minorUnits,
  currency,
});

export const addMoney = (a: Money, b: Money): Money => {
  assertSameCurrency(a, b);
  return { minorUnits: a.minorUnits + b.minorUnits, currency: a.currency };
};

export const applyRate = (a: Money, rate: number): Money => ({
  minorUnits: Math.round(a.minorUnits * rate),
  currency: a.currency,
});

export function assertSameCurrency(a: Money, b: Money): void {
  if (a.currency !== b.currency) {
    throw new Error(`Currency mismatch: ${a.currency} vs ${b.currency}`);
  }
}
