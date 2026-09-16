import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { notify } from '../lib/notify';
import { recordLedgerMove } from '../lib/ledger';
import * as qrWallet from '../lib/qrWallet';
import { Collections, Money, PaymentMethod } from '../types';

/**
 * Buyer pays once delivery is quoted (v2 §5). Two options:
 *   - payNow: money-in via the capture seam (funds land in escrow now).
 *   - payOnDelivery: money-in via the hold seam (authorization hold; captured
 *     on delivery).
 *
 * Both seam calls are inert for now and will throw — the order stays in
 * `awaitingPayment` and the real failure is surfaced. We never simulate
 * success. On a real success the order becomes `confirmed` and stock is
 * decremented.
 */
export const payOrder = onCall(async (req) => {
  const buyerId = requireAuth(req);
  const orderId = req.data?.orderId as string | undefined;
  const method = req.data?.method as PaymentMethod | undefined;

  if (!orderId || (method !== 'payNow' && method !== 'payOnDelivery')) {
    throw new HttpsError(
      'invalid-argument',
      'orderId and a valid method (payNow|payOnDelivery) are required.',
    );
  }

  const orderRef = db.collection(Collections.orders).doc(orderId);
  const snap = await orderRef.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
  const order = snap.data()!;

  if (order.buyerId !== buyerId) {
    throw new HttpsError('permission-denied', 'Not your order.');
  }
  if (order.status !== 'awaitingPayment') {
    throw new HttpsError(
      'failed-precondition',
      'This order is not awaiting payment.',
    );
  }

  const total = order.total as Money;
  const idempotencyKey = `pay_${orderId}`;

  // Money-in via the seam (inert for now → throws, surfaced honestly).
  let externalTxnId: string;
  if (method === 'payNow') {
    externalTxnId = await qrWallet.capture({
      orderId,
      buyerWalletId: buyerId,
      amount: total,
      idempotencyKey,
    });
  } else {
    externalTxnId = await qrWallet.hold({
      orderId,
      buyerWalletId: buyerId,
      amount: total,
      idempotencyKey,
    });
  }

  // Only reached on a real seam success: confirm the order and commit stock.
  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(orderRef);
    if (fresh.data()!.status !== 'awaitingPayment') return; // already handled

    const items = (order.items ?? []) as Array<{
      productId: string;
      quantity: number;
    }>;
    const productSnaps = await Promise.all(
      items.map((i) =>
        tx.get(db.collection(Collections.products).doc(i.productId)),
      ),
    );
    productSnaps.forEach((p, idx) => {
      if (!p.exists) return;
      const next = ((p.data()!.stock as number) ?? 0) - items[idx].quantity;
      tx.update(p.ref, {
        stock: next < 0 ? 0 : next,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    tx.update(orderRef, {
      status: 'confirmed',
      paymentMethod: method,
      paymentStatus: method === 'payNow' ? 'captured' : 'held',
      qrWalletTxnId: externalTxnId,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  // Pay-now funds are in escrow immediately; a pay-on-delivery hold is not in
  // escrow until captured on delivery.
  if (method === 'payNow') {
    await recordLedgerMove({
      moveId: `escrow_capture_${orderId}`,
      type: 'escrow_hold',
      currency: total.currency,
      deltas: { escrow: total.minorUnits },
      ref: { orderId },
      externalTxnId,
    });
  }

  await notify({
    recipientId: buyerId,
    audience: 'buyer',
    title: 'Payment confirmed',
    body: method === 'payNow'
        ? 'Your payment was received. Your order is being prepared.'
        : 'Your pay-on-delivery order is confirmed and being prepared.',
    type: 'order_confirmed',
    deepLink: `/buyer/orders/${orderId}`,
  });

  return { ok: true, status: 'confirmed' };
});
