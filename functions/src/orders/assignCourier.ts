import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { Collections } from '../types';

/**
 * Admin assigns a confirmed or shipped order to one courier (SA-120). Only the
 * assigned courier can read the order (rules) and submit its proof of delivery
 * (`submitProofOfDelivery`). Reassigning replaces the previous courier.
 */
export const assignCourier = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const orderId = req.data?.orderId as string | undefined;
  const courierId = req.data?.courierId as string | undefined;
  if (!orderId || !courierId) {
    throw new HttpsError('invalid-argument', 'orderId and courierId required.');
  }

  const courier = await db.collection(Collections.staff).doc(courierId).get();
  if (!courier.exists || courier.data()!.role !== 'delivery') {
    throw new HttpsError(
      'failed-precondition',
      'That user is not a courier.',
    );
  }

  const previous = await db.runTransaction(async (tx) => {
    const ref = db.collection(Collections.orders).doc(orderId);
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
    const order = snap.data()!;
    if (!['confirmed', 'shipped'].includes(order.status)) {
      throw new HttpsError(
        'failed-precondition',
        `Cannot assign a courier to an order in state ${order.status}.`,
      );
    }
    tx.update(ref, {
      courierId,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return (order.courierId as string | undefined) ?? null;
  });

  await writeAudit({
    actorId: adminId,
    action: 'order.courier.assigned',
    targetType: 'order',
    targetId: orderId,
    metadata: { courierId, previousCourierId: previous },
  });
  await notify({
    recipientId: courierId,
    audience: 'delivery',
    title: 'New delivery assigned',
    body: 'An order has been assigned to you.',
    type: 'delivery_assigned',
    deepLink: '/delivery',
  });
  return { ok: true };
});
