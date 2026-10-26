// Shop Afrik Cloud Functions entry point.
//
// Money-critical and privileged operations live here (plan §4): order
// creation, payment confirmation, delivery confirmation, refund decisions,
// seller approval, role management, and day-8 settlement.

export { setUserRole } from './auth/setUserRole';
export { approveSeller } from './sellers/approveSeller';
export { suspendSeller } from './sellers/suspendSeller';
export { syncStoreProfile } from './sellers/syncStore';

export { findUser } from './admin/findUser';
export { updatePlatformSettings } from './admin/updatePlatformSettings';
export { approveProduct } from './products/approveProduct';
export { removeProduct } from './products/removeProduct';

export { createOrder } from './orders/createOrder';
export { quoteDelivery } from './orders/quoteDelivery';
export { payOrder } from './orders/payOrder';
export { assignCourier } from './orders/assignCourier';
export { releaseExpiredReservations } from './orders/releaseExpiredReservations';
export { expireStaleOrders } from './orders/expireStaleOrders';
export {
  markShipped,
  markDelivered,
  cancelOrder,
  submitProofOfDelivery,
} from './orders/transitions';

export { requestRefund } from './refunds/requestRefund';
export { decideRefund } from './refunds/decideRefund';
export { respondToRefund } from './refunds/respondToRefund';

export { settleDueOrders } from './settlement/settleDueOrders';

export {
  reconcilePlatformAccount,
  reconcilePlatformAccountDaily,
} from './platform/reconcile';

export { submitReview, deleteReview } from './reviews/submitReview';
