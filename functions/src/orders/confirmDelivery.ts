import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { loadSettings } from '../config';
import { Collections } from '../types';

/**
 * Marks an order delivered and confirmed (plan §5 step 7). This is the event
 * that starts the 7-day refund window and schedules day-8 auto-settlement.
 *
 * Admin-only for the MVP; a courier app takes this over in Phase 6.
 */
export const confirmDelivery = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const orderId = req.data?.orderId as string | undefined;
  if (!orderId) {
    throw new HttpsError('invalid-argument', 'orderId is required.');
  }

  const settings = await loadSettings();

  await db.runTransaction(async (tx) => {
    const ref = db.collection(Collections.orders).doc(orderId);
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Order not found.');
    }
    const order = snap.data()!;
    if (order.paymentStatus !== 'paid') {
      throw new HttpsError('failed-precondition', 'Order is not paid.');
    }
    if (order.deliveryStatus === 'deliveryConfirmed') {
      return; // idempotent
    }

    const now = Date.now();
    const dueAt = Timestamp.fromMillis(
      now + settings.settlementDelayDays * 24 * 60 * 60 * 1000,
    );

    tx.update(ref, {
      status: 'delivered',
      deliveryStatus: 'deliveryConfirmed',
      deliveryConfirmedAt: FieldValue.serverTimestamp(),
      settlementStatus: 'scheduled',
      settlementDueAt: dueAt,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  await writeAudit({
    actorId: adminId,
    action: 'order.delivery.confirmed',
    targetType: 'order',
    targetId: orderId,
  });

  return { ok: true };
});
