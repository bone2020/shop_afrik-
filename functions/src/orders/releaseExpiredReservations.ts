import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { writeAudit } from '../lib/audit';
import { releaseStock } from './stockReservation';
import { Collections, OrderItem } from '../types';

/**
 * Returns stock held by abandoned payments (SA-040). A reservation is released
 * only while the order is still awaiting payment and no payment is in doubt;
 * an in-doubt payment keeps its stock until recovery decides what happened.
 */
export const releaseExpiredReservations = onSchedule('every 5 minutes', async () => {
  await releaseExpired(Timestamp.now());
});

/** One sweep as of [now]; exported for tests. */
export async function releaseExpired(now: Timestamp): Promise<number> {
  const due = await db
    .collection(Collections.orders)
    .where('stockReserved', '==', true)
    .where('reservationExpiresAt', '<=', now)
    .limit(200)
    .get();

  let released = 0;
  for (const doc of due.docs) {
    const did = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(doc.ref);
      const o = fresh.data();
      if (
        !o ||
        o.stockReserved !== true ||
        o.status !== 'awaitingPayment' ||
        o.paymentInDoubt === true
      ) {
        return false;
      }
      await releaseStock(tx, (o.items ?? []) as OrderItem[]);
      tx.update(doc.ref, {
        stockReserved: false,
        reservationExpiresAt: null,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (did) {
      released++;
      await writeAudit({
        actorId: 'system',
        action: 'order.reservation.expired',
        targetType: 'order',
        targetId: doc.id,
      });
    }
  }
  return released;
}
