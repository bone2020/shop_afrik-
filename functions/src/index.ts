// Shop Afrik Cloud Functions entry point.
//
// Money-critical and privileged operations live here (plan §4): order
// creation, payment confirmation, delivery confirmation, refund decisions,
// seller approval, role management, and day-8 settlement.

export { setUserRole } from './auth/setUserRole';
export { approveSeller } from './sellers/approveSeller';
export { approveProduct } from './products/approveProduct';

export { createOrder } from './orders/createOrder';
export { quoteDelivery } from './orders/quoteDelivery';
export { payOrder } from './orders/payOrder';
export {
  markShipped,
  markDelivered,
  cancelOrder,
  submitProofOfDelivery,
} from './orders/transitions';

export { decideRefund } from './refunds/decideRefund';

export { settleDueOrders } from './settlement/settleDueOrders';

export { reconcilePlatformAccount } from './platform/reconcile';

export { onReviewCreated } from './reviews/onReviewCreated';
