import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { notify } from '../lib/notify';
import { recordLedgerMove } from '../lib/ledger';
import * as qrWallet from '../lib/qrWallet';
import { Collections, Money } from '../types';

/**
 * Confirms payment for an order against QR Wallet and begins fulfillment
 * (plan §5 steps 5–6).
 *
 * Idempotent: re-confirming an already-paid order is a no-op. Stock is
 * decremented here (not at order creation) so only paid orders consume
 * inventory.
 */
export const confirmPayment = onCall(async (req) => {
  requireAuth(req);
  const orderId = req.data?.orderId as string | undefined;
  if (!orderId) {
    throw new HttpsError('invalid-argument', 'orderId is required.');
  }

  // Verify with QR Wallet before touching the order (plan §5 step 6).
  const txn = await qrWallet.lookupTransaction(orderId);
  if (!txn || txn.status !== 'completed') {
    throw new HttpsError('failed-precondition', 'Payment not completed.');
  }

  const result = await db.runTransaction(async (tx) => {
    const orderRef = db.collection(Collections.orders).doc(orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) {
      throw new HttpsError('not-found', 'Order not found.');
    }
    const order = orderSnap.data()!;

    if (order.paymentStatus === 'paid') {
      return {
        alreadyPaid: true,
        buyerId: order.buyerId as string,
        subtotal: order.subtotal as Money,
      };
    }

    const total = order.total as Money;
    if (txn.amount.minorUnits < total.minorUnits) {
      throw new HttpsError('failed-precondition', 'Underpayment detected.');
    }

    // Re-read and decrement stock for each line within the transaction.
    const items = (order.items ?? []) as Array<{
      productId: string;
      quantity: number;
    }>;
    const productSnaps = await Promise.all(
      items.map((i) =>
        tx.get(db.collection(Collections.products).doc(i.productId)),
      ),
    );
    productSnaps.forEach((snap, idx) => {
      if (!snap.exists) return;
      const current = (snap.data()!.stock as number) ?? 0;
      const next = current - items[idx].quantity;
      tx.update(snap.ref, {
        stock: next < 0 ? 0 : next,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    tx.update(orderRef, {
      status: 'paid',
      paymentStatus: 'paid',
      qrWalletTxnId: txn.id,
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      alreadyPaid: false,
      buyerId: order.buyerId as string,
      subtotal: order.subtotal as Money,
    };
  });

  if (!result.alreadyPaid) {
    // Hold the seller-attributable amount (subtotal) into the order's escrow
    // bucket in the platform account, then mirror the move in Shop Afrik's
    // ledger. The deterministic id is also the QR Wallet idempotency key.
    const moveId = `escrow_hold_${orderId}`;
    const escrowed = result.subtotal;
    const externalTxnId = await qrWallet.holdToEscrow({
      orderId,
      buyerWalletId: result.buyerId,
      amount: escrowed,
      idempotencyKey: moveId,
    });
    await recordLedgerMove({
      moveId,
      type: 'escrow_hold',
      currency: escrowed.currency,
      deltas: { escrow: escrowed.minorUnits },
      ref: { orderId },
      externalTxnId,
    });

    await notify({
      recipientId: result.buyerId,
      audience: 'buyer',
      title: 'Payment confirmed',
      body: 'Your order is paid and being prepared.',
      type: 'order_paid',
      deepLink: `/buyer/orders/${orderId}`,
    });
  }

  return { ok: true, alreadyPaid: result.alreadyPaid };
});
