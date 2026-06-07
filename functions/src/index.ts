// Shop Afrik Cloud Functions entry point.
//
// Money-critical and privileged operations live here (plan §4): order
// creation, payment confirmation, delivery confirmation, refund decisions,
// seller approval, role management, and day-8 settlement.

export { setUserRole } from './auth/setUserRole';
export { approveSeller } from './sellers/approveSeller';

export { createOrder } from './orders/createOrder';
export { confirmPayment } from './orders/confirmPayment';
export { confirmDelivery } from './orders/confirmDelivery';

export { decideRefund } from './refunds/decideRefund';

export { settleDueOrders } from './settlement/settleDueOrders';

export { reconcilePlatformAccount } from './platform/reconcile';
