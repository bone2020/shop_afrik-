import { logger } from 'firebase-functions/v2';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { loadSettings } from '../config';
import { refundTierFor } from './tier';
import { Collections, Money, OrderItem, money } from '../types';

/** Refund statuses that still block settlement and a second request. */
export const OPEN_REFUND_STATUSES = [
  'requested',
  'underReview',
  'escalated',
  'approved',
];

interface RefundLineInput {
  productId: string;
  quantity: number;
}

/**
 * Buyer opens a refund request (SA-050). The server, not the client, decides
 * what is refundable: the order must be the caller's and delivered, the
 * refund window (from courier-confirmed delivery) must be open, each line can
 * claim at most its not-yet-refunded quantity, a single-item order is
 * all-or-nothing, and only one refund per order may be open at a time. The
 * amount is computed from the order's own unit prices.
 *
 * In the same transaction the order's day-8 settlement is put on hold
 * (SA-051), so the seller is never paid while a refund is undecided.
 */
export const requestRefund = onCall(async (req) => {
  const buyerId = requireAuth(req);
  const orderId = req.data?.orderId as string | undefined;
  const lines = req.data?.lines as RefundLineInput[] | undefined;
  const reason = ((req.data?.reason as string | undefined) ?? '').trim();
  const evidenceUrls = ((req.data?.evidenceUrls as string[] | undefined) ?? [])
    .filter((u) => typeof u === 'string')
    .slice(0, 5);

  if (!orderId || !Array.isArray(lines) || lines.length === 0) {
    throw new HttpsError('invalid-argument', 'orderId and lines are required.');
  }
  if (!reason) {
    throw new HttpsError('invalid-argument', 'Please give a reason.');
  }

  const settings = await loadSettings();
  const orderRef = db.collection(Collections.orders).doc(orderId);
  const refundRef = db.collection(Collections.refundRequests).doc();

  const amount = await db.runTransaction(async (tx) => {
    const openSnap = await tx.get(
      db
        .collection(Collections.refundRequests)
        .where('orderId', '==', orderId)
        .where('status', 'in', OPEN_REFUND_STATUSES),
    );
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
    const order = snap.data()!;

    if (order.buyerId !== buyerId) {
      throw new HttpsError('permission-denied', 'Not your order.');
    }
    if (order.status !== 'delivered') {
      throw new HttpsError(
        'failed-precondition',
        'Refunds can only be requested for delivered orders.',
      );
    }
    const deliveredAt = order.deliveryConfirmedAt as Timestamp | undefined;
    const windowMs = settings.refundWindowDays * 24 * 60 * 60 * 1000;
    if (!deliveredAt || Date.now() > deliveredAt.toMillis() + windowMs) {
      throw new HttpsError(
        'failed-precondition',
        `The ${settings.refundWindowDays}-day refund window has closed.`,
      );
    }
    if (!openSnap.empty) {
      throw new HttpsError(
        'already-exists',
        'A refund request for this order is already open.',
      );
    }

    const items = (order.items ?? []) as OrderItem[];
    const seen = new Set<string>();
    const refundLines: Array<{ productId: string; quantity: number; amount: Money }> = [];
    const sellerIds = new Set<string>();
    let total: Money | null = null;

    for (const line of lines) {
      const qty = line?.quantity;
      if (!line?.productId || !Number.isInteger(qty) || qty < 1) {
        throw new HttpsError('invalid-argument', 'Invalid refund line.');
      }
      if (seen.has(line.productId)) {
        throw new HttpsError('invalid-argument', 'Duplicate refund line.');
      }
      seen.add(line.productId);

      const item = items.find((i) => i.productId === line.productId);
      if (!item) {
        throw new HttpsError('invalid-argument', 'That item is not in this order.');
      }
      const remaining = item.quantity - (item.refundedQuantity ?? 0);
      if (qty > remaining) {
        throw new HttpsError(
          'failed-precondition',
          `Only ${remaining} of ${item.title} can still be refunded.`,
        );
      }
      if (items.length === 1 && qty !== remaining) {
        throw new HttpsError(
          'failed-precondition',
          'A single-item order can only be refunded in full.',
        );
      }

      const lineAmount = money(item.unitPrice.minorUnits * qty, item.unitPrice.currency);
      refundLines.push({ productId: item.productId, quantity: qty, amount: lineAmount });
      sellerIds.add(item.sellerId);
      total = total
        ? money(total.minorUnits + lineAmount.minorUnits, total.currency)
        : lineAmount;
    }

    const sum = total!;
    let tier;
    try {
      tier = refundTierFor(sum.minorUnits, sum.currency, settings);
    } catch (e) {
      logger.error('Refund tiers missing', { currency: sum.currency, error: (e as Error).message });
      throw new HttpsError(
        'failed-precondition',
        'Refunds are not available in this currency yet. Please contact support.',
      );
    }

    tx.set(refundRef, {
      orderId,
      buyerId,
      sellerIds: [...sellerIds],
      lines: refundLines,
      amount: sum,
      reason: reason.slice(0, 2000),
      evidenceUrls,
      tier,
      status: 'requested',
      firstApproverId: null,
      secondApproverId: null,
      decisionNote: null,
      createdAt: new Date().toISOString(),
      resolvedAt: null,
    });
    // SA-051: no payout while a refund is undecided.
    if (order.settlementStatus === 'scheduled') {
      tx.update(orderRef, {
        settlementStatus: 'onHold',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return sum;
  });

  await writeAudit({
    actorId: buyerId,
    action: 'refund.requested',
    targetType: 'refund_request',
    targetId: refundRef.id,
    metadata: { orderId, amountMinor: amount.minorUnits, currency: amount.currency },
  });
  await notify({
    recipientId: buyerId,
    audience: 'buyer',
    title: 'Refund requested',
    body: 'We received your refund request and will review it shortly.',
    type: 'refund_requested',
    deepLink: `/buyer/orders/${orderId}`,
  });

  return { refundId: refundRef.id, status: 'requested' };
});
