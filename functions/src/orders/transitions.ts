import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth, requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { recordLedgerMove } from '../lib/ledger';
import { loadSettings } from '../config';
import * as qrWallet from '../lib/qrWallet';
import { Collections, Money, canTransition } from '../types';

/**
 * Seller marks an order shipped (v2 §8 B1). Allowed only from `confirmed`, and
 * only by a seller with a line in the order. Shipping is the cancellation
 * cutoff — the buyer can no longer cancel afterwards.
 */
export const markShipped = onCall(async (req) => {
  const sellerId = requireRole(req, 'seller');
  const orderId = req.data?.orderId as string | undefined;
  if (!orderId) throw new HttpsError('invalid-argument', 'orderId required.');

  const buyerId = await db.runTransaction(async (tx) => {
    const ref = db.collection(Collections.orders).doc(orderId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
    const order = snap.data()!;

    const sellerIds = (order.sellerIds ?? []) as string[];
    if (!sellerIds.includes(sellerId)) {
      throw new HttpsError('permission-denied', 'Not your order.');
    }
    if (!canTransition(order.status, 'shipped')) {
      throw new HttpsError(
        'failed-precondition',
        `Cannot ship an order in state ${order.status}.`,
      );
    }
    tx.update(ref, {
      status: 'shipped',
      deliveryStatus: 'dispatched',
      updatedAt: FieldValue.serverTimestamp(),
    });
    return order.buyerId as string;
  });

  await writeAudit({
    actorId: sellerId,
    action: 'order.shipped',
    targetType: 'order',
    targetId: orderId,
  });
  await notify({
    recipientId: buyerId,
    audience: 'buyer',
    title: 'Order shipped',
    body: 'Your order is on its way.',
    type: 'order_shipped',
    deepLink: `/buyer/orders/${orderId}`,
  });
  return { ok: true };
});

interface DeliveryProofInput {
  deliveryPersonId: string;
  barcode: string;
  photoUrl?: string | null;
  latitude?: number | null;
  longitude?: number | null;
}

/**
 * Shared delivery transition (v2 §8 B1): moves an order to `delivered`, opens
 * the refund window, and schedules day-8 settlement. NOTE: it does NOT complete
 * the order — `completed` is reached only after the seller is settled on day 8.
 * For pay-on-delivery this is the capture trigger; the capture seam is inert for
 * now, so the delivery is recorded and the capture left pending, never faked.
 *
 * Used by both the delivery person (with proof) and the admin backup (no proof).
 */
async function deliverOrder(
  orderId: string,
  actorId: string,
  proof?: DeliveryProofInput,
): Promise<void> {
  const settings = await loadSettings();
  const ref = db.collection(Collections.orders).doc(orderId);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
    const order = snap.data()!;
    if (!canTransition(order.status, 'delivered')) {
      throw new HttpsError(
        'failed-precondition',
        `Cannot deliver an order in state ${order.status}.`,
      );
    }
    const dueAt = Timestamp.fromMillis(
      Date.now() + settings.settlementDelayDays * 24 * 60 * 60 * 1000,
    );
    const update: Record<string, unknown> = {
      status: 'delivered',
      deliveryStatus: 'deliveryConfirmed',
      deliveryConfirmedAt: FieldValue.serverTimestamp(),
      settlementStatus: 'scheduled',
      settlementDueAt: dueAt,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (proof) {
      update.deliveryProof = {
        deliveryPersonId: proof.deliveryPersonId,
        barcode: proof.barcode,
        photoUrl: proof.photoUrl ?? null,
        latitude: proof.latitude ?? null,
        longitude: proof.longitude ?? null,
        capturedAt: new Date().toISOString(),
      };
    }
    tx.update(ref, update);
    return {
      buyerId: order.buyerId as string,
      paymentMethod: order.paymentMethod as string | null,
      total: order.total as Money,
    };
  });

  await writeAudit({
    actorId,
    action: 'order.delivered',
    targetType: 'order',
    targetId: orderId,
    metadata: { withProof: proof != null },
  });

  // Pay-on-delivery: capture the hold into escrow now. Inert for now — record
  // the delivery and leave the capture pending rather than faking it.
  if (result.paymentMethod === 'payOnDelivery') {
    try {
      const txn = await qrWallet.captureHold({
        orderId,
        amount: result.total,
        idempotencyKey: `escrow_capture_${orderId}`,
      });
      await ref.update({ paymentStatus: 'captured' });
      await recordLedgerMove({
        moveId: `escrow_capture_${orderId}`,
        type: 'escrow_hold',
        currency: result.total.currency,
        deltas: { escrow: result.total.minorUnits },
        ref: { orderId },
        externalTxnId: txn,
      });
    } catch (e) {
      await writeAudit({
        actorId: 'system',
        action: 'order.capture.pending',
        targetType: 'order',
        targetId: orderId,
        metadata: { error: (e as Error).message },
      });
    }
  }

  await notify({
    recipientId: result.buyerId,
    audience: 'buyer',
    title: 'Order delivered',
    body: 'Your order was delivered. You have 7 days to request a refund.',
    type: 'order_delivered',
    deepLink: `/buyer/orders/${orderId}`,
  });
}

/**
 * Delivery person submits proof of delivery (photo + GPS + timestamp) for a
 * scanned package. The barcode must match the order id, the order must be
 * shipped, and submitting marks the order delivered.
 */
export const submitProofOfDelivery = onCall(async (req) => {
  const deliveryPersonId = requireRole(req, 'delivery');
  const orderId = req.data?.orderId as string | undefined;
  const barcode = req.data?.barcode as string | undefined;
  if (!orderId || !barcode) {
    throw new HttpsError('invalid-argument', 'orderId and barcode required.');
  }
  // The package barcode encodes the order id.
  if (barcode !== orderId) {
    throw new HttpsError(
      'failed-precondition',
      'Scanned barcode does not match this order.',
    );
  }

  await deliverOrder(orderId, deliveryPersonId, {
    deliveryPersonId,
    barcode,
    photoUrl: (req.data?.photoUrl as string | undefined) ?? null,
    latitude: (req.data?.latitude as number | undefined) ?? null,
    longitude: (req.data?.longitude as number | undefined) ?? null,
  });
  return { ok: true };
});

/**
 * Admin backup for marking an order delivered, for the rare case the delivery
 * scan didn't happen.
 */
export const markDelivered = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const orderId = req.data?.orderId as string | undefined;
  if (!orderId) throw new HttpsError('invalid-argument', 'orderId required.');
  await deliverOrder(orderId, adminId);
  return { ok: true };
});

/**
 * Buyer cancels an order (v2 §8 B1). Allowed only before shipping. If the order
 * was already confirmed, the money is reversed: refund-from-escrow for pay-now,
 * release-hold for pay-on-delivery (both inert for now, but the guard and the
 * call are in place). Stock committed at payment is restored.
 */
export const cancelOrder = onCall(async (req) => {
  const buyerId = requireAuth(req);
  const orderId = req.data?.orderId as string | undefined;
  if (!orderId) throw new HttpsError('invalid-argument', 'orderId required.');

  const ref = db.collection(Collections.orders).doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
  const order = snap.data()!;

  if (order.buyerId !== buyerId) {
    throw new HttpsError('permission-denied', 'Not your order.');
  }
  const status = order.status as string;
  const cancellable = ['awaitingDeliveryQuote', 'awaitingPayment', 'confirmed'];
  if (!cancellable.includes(status)) {
    throw new HttpsError(
      'failed-precondition',
      'This order can no longer be cancelled (it has shipped).',
    );
  }

  const wasConfirmed = status === 'confirmed';
  const total = order.total as Money;
  let paymentStatus: string | null = null;

  // Reverse money for a confirmed order before cancelling (inert → throws).
  if (wasConfirmed) {
    if (order.paymentStatus === 'captured') {
      await qrWallet.refundFromEscrow({
        orderId,
        buyerWalletId: buyerId,
        amount: total,
        idempotencyKey: `cancel_refund_${orderId}`,
      });
      await recordLedgerMove({
        moveId: `cancel_refund_${orderId}`,
        type: 'refund_release',
        currency: total.currency,
        deltas: { escrow: -total.minorUnits },
        ref: { orderId },
      });
      paymentStatus = 'refunded';
    } else if (order.paymentStatus === 'held') {
      await qrWallet.releaseHold({
        orderId,
        buyerWalletId: buyerId,
        amount: total,
        idempotencyKey: `cancel_release_${orderId}`,
      });
      paymentStatus = 'released';
    }
  }

  await db.runTransaction(async (tx) => {
    // Restore stock committed at payment (only confirmed orders decremented it).
    if (wasConfirmed) {
      const items = (order.items ?? []) as Array<{
        productId: string;
        quantity: number;
      }>;
      const snaps = await Promise.all(
        items.map((i) =>
          tx.get(db.collection(Collections.products).doc(i.productId)),
        ),
      );
      snaps.forEach((p, idx) => {
        if (!p.exists) return;
        tx.update(p.ref, {
          stock: ((p.data()!.stock as number) ?? 0) + items[idx].quantity,
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
    }
    const update: Record<string, unknown> = {
      status: 'cancelled',
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (paymentStatus != null) update.paymentStatus = paymentStatus;
    tx.update(ref, update);
  });

  await writeAudit({
    actorId: buyerId,
    action: 'order.cancelled',
    targetType: 'order',
    targetId: orderId,
  });
  await notify({
    recipientId: buyerId,
    audience: 'buyer',
    title: 'Order cancelled',
    body: 'Your order was cancelled.',
    type: 'order_cancelled',
    deepLink: `/buyer/orders/${orderId}`,
  });
  return { ok: true };
});
