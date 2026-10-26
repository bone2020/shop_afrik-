import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { notify } from '../lib/notify';
import { recordLedgerMove } from '../lib/ledger';
import { writeAudit } from '../lib/audit';
import * as qrWallet from '../lib/qrWallet';
import { releaseStock, reservationExpiry, reserveStock } from './stockReservation';
import { Collections, Money, OrderItem, PaymentMethod } from '../types';

/**
 * Buyer pays once delivery is quoted (v2 §5). Two options:
 *   - payNow: money-in via the capture seam (funds land in escrow now).
 *   - payOnDelivery: money-in via the hold seam (authorization hold; captured
 *     on delivery).
 *
 * Stock is reserved in a transaction *before* any money moves (SA-040), so two
 * buyers can never pay for the last unit: the loser is refused before being
 * charged. A declined payment releases the reservation. A payment whose
 * outcome is unknown (timeout) keeps it and is flagged for reconciliation,
 * because the money may have moved; an expired reservation is released by
 * `releaseExpiredReservations` only when no payment is in doubt.
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

  // Step 1: reserve stock and mark the payment as in progress, atomically.
  const order = await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
    const o = snap.data()!;
    if (o.buyerId !== buyerId) {
      throw new HttpsError('permission-denied', 'Not your order.');
    }
    if (o.status !== 'awaitingPayment') {
      throw new HttpsError(
        'failed-precondition',
        'This order is not awaiting payment.',
      );
    }
    if (o.stockReserved === true) {
      throw new HttpsError(
        'aborted',
        'A payment for this order is already in progress.',
      );
    }
    await reserveStock(tx, (o.items ?? []) as OrderItem[]);
    tx.update(orderRef, {
      stockReserved: true,
      reservationExpiresAt: reservationExpiry(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return o;
  });

  const total = order.total as Money;
  const idempotencyKey = `pay_${orderId}`;

  // Step 2: money-in via the seam.
  let externalTxnId: string;
  try {
    externalTxnId = method === 'payNow'
      ? await qrWallet.capture({ orderId, buyerWalletId: buyerId, amount: total, idempotencyKey })
      : await qrWallet.hold({ orderId, buyerWalletId: buyerId, amount: total, idempotencyKey });
  } catch (e) {
    const code = (e as HttpsError).code;
    if (code === 'deadline-exceeded') {
      // Outcome unknown: keep the stock and flag the order for recovery.
      await orderRef.update({
        paymentInDoubt: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
      await writeAudit({
        actorId: 'system',
        action: 'order.payment.uncertain',
        targetType: 'order',
        targetId: orderId,
        metadata: { method, error: (e as Error).message },
      });
    } else {
      // Definitely not charged: give the stock back.
      await db.runTransaction(async (tx) => {
        await releaseStock(tx, (order.items ?? []) as OrderItem[]);
        tx.update(orderRef, {
          stockReserved: false,
          reservationExpiresAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
    }
    throw e;
  }

  // Step 3: confirm. Stock is already committed by the reservation.
  await orderRef.update({
    status: 'confirmed',
    paymentMethod: method,
    paymentStatus: method === 'payNow' ? 'captured' : 'held',
    qrWalletTxnId: externalTxnId,
    reservationExpiresAt: null,
    updatedAt: FieldValue.serverTimestamp(),
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
