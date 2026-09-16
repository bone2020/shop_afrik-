import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import {
  Collections,
  Money,
  addMoney,
  canTransition,
  money,
} from '../types';

/**
 * Admin sets the delivery price for an order awaiting a quote (v2 §5 / §8 B1).
 * The order total is recomputed to items + delivery and the order moves to
 * `awaitingPayment`; the buyer is notified to pay the full total. No money is
 * held yet.
 */
export const quoteDelivery = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const orderId = req.data?.orderId as string | undefined;
  const deliveryFeeMinor = req.data?.deliveryFeeMinor as number | undefined;
  const note = (req.data?.note as string | undefined) ?? null;

  if (!orderId || deliveryFeeMinor == null || deliveryFeeMinor < 0) {
    throw new HttpsError(
      'invalid-argument',
      'orderId and a non-negative deliveryFeeMinor are required.',
    );
  }

  const buyerId = await db.runTransaction(async (tx) => {
    const ref = db.collection(Collections.orders).doc(orderId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
    const order = snap.data()!;

    if (!canTransition(order.status, 'awaitingPayment')) {
      throw new HttpsError(
        'failed-precondition',
        `Cannot quote delivery for an order in state ${order.status}.`,
      );
    }

    const subtotal = order.subtotal as Money;
    const paymentFee = order.paymentFee as Money;
    // Delivery is quoted in the order's own currency — never blend currencies.
    const deliveryFee = money(deliveryFeeMinor, subtotal.currency);
    const total = addMoney(addMoney(subtotal, paymentFee), deliveryFee);

    tx.update(ref, {
      deliveryFee,
      deliveryQuoteNote: note,
      total,
      status: 'awaitingPayment',
      updatedAt: FieldValue.serverTimestamp(),
    });
    return order.buyerId as string;
  });

  await writeAudit({
    actorId: adminId,
    action: 'order.delivery.quoted',
    targetType: 'order',
    targetId: orderId,
    metadata: { deliveryFeeMinor },
  });
  await notify({
    recipientId: buyerId,
    audience: 'buyer',
    title: 'Delivery quoted',
    body: 'Your delivery price is ready. Review the full total and pay.',
    type: 'delivery_quoted',
    deepLink: `/buyer/orders/${orderId}`,
  });

  return { ok: true };
});
