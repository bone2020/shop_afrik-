import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { loadSettings } from '../config';
import { Collections } from '../types';

const HOUR = 60 * 60 * 1000;

/**
 * Cancels orders left waiting too long (SA-042): no delivery quote within
 * `quoteExpiryHours` of placing, or no payment within `paymentExpiryHours`
 * of the quote. No money has moved for either, and an order with a payment
 * in progress or in doubt is never touched.
 */
export const expireStaleOrders = onSchedule(
  { schedule: 'every 60 minutes', timeZone: 'Africa/Accra' },
  async () => {
    await expireStale(Timestamp.now());
  },
);

/** One sweep as of [now]; exported for tests. Returns orders expired. */
export async function expireStale(now: Timestamp, pageSize = 200): Promise<number> {
  const settings = await loadSettings();
  const quoteCutoff = Timestamp.fromMillis(now.toMillis() - settings.quoteExpiryHours * HOUR);
  const payCutoff = Timestamp.fromMillis(now.toMillis() - settings.paymentExpiryHours * HOUR);

  let expired = 0;
  for (const [status, field, cutoff, reason] of [
    ['awaitingDeliveryQuote', 'createdAt', quoteCutoff, 'quoteExpired'],
    ['awaitingPayment', 'quotedAt', payCutoff, 'paymentExpired'],
  ] as const) {
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let query = db
        .collection(Collections.orders)
        .where('status', '==', status)
        .where(field, '<=', cutoff)
        .orderBy(field)
        .limit(pageSize);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        if (await expireOne(doc.ref, status, reason)) expired++;
      }
      if (page.docs.length < pageSize) break;
      cursor = page.docs[page.docs.length - 1];
    }
  }
  return expired;
}

async function expireOne(
  ref: FirebaseFirestore.DocumentReference,
  status: string,
  reason: 'quoteExpired' | 'paymentExpired',
): Promise<boolean> {
  const buyerId = await db.runTransaction(async (tx) => {
    const o = (await tx.get(ref)).data();
    if (!o || o.status !== status || o.stockReserved === true || o.paymentInDoubt === true) {
      return null;
    }
    tx.update(ref, {
      status: 'cancelled',
      cancelReason: reason,
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return o.buyerId as string;
  });
  if (!buyerId) return false;

  await writeAudit({
    actorId: 'system',
    action: `order.${reason}`,
    targetType: 'order',
    targetId: ref.id,
  });
  await notify({
    recipientId: buyerId,
    audience: 'buyer',
    title: 'Order expired',
    body:
      reason === 'quoteExpired'
        ? 'We could not quote delivery in time, so your order was cancelled. Nothing was charged.'
        : 'Your order was not paid in time, so it was cancelled. Nothing was charged.',
    type: 'order_expired',
    deepLink: `/buyer/orders/${ref.id}`,
  });
  return true;
}
