import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { Collections } from '../types';

/**
 * Admin suspends or reinstates an approved seller (SA-063).
 *
 * Suspending hides every active product (flagged `suspendedWithSeller` so
 * reinstating brings back only those), and the rules stop the seller listing
 * or editing. createOrder already refuses inactive products, so no new orders
 * reach the seller. Payouts for orders already delivered are held by
 * settleDue until the seller is reinstated.
 */
export const suspendSeller = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const sellerId = req.data?.sellerId as string | undefined;
  const suspend = req.data?.suspend as boolean | undefined;
  const reason = (req.data?.reason as string | undefined)?.trim() ?? '';
  if (!sellerId || typeof suspend !== 'boolean') {
    throw new HttpsError('invalid-argument', 'sellerId and suspend required.');
  }
  if (suspend && !reason) {
    throw new HttpsError('invalid-argument', 'A reason is required.');
  }

  const ref = db.collection(Collections.sellers).doc(sellerId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Seller not found.');
  const status = snap.data()!.approvalStatus;
  if (suspend && status !== 'approved') {
    throw new HttpsError(
      'failed-precondition',
      'Only an approved seller can be suspended.',
    );
  }
  if (!suspend && status !== 'suspended') {
    throw new HttpsError('failed-precondition', 'Seller is not suspended.');
  }

  await ref.update({
    approvalStatus: suspend ? 'suspended' : 'approved',
    suspensionReason: suspend ? reason : FieldValue.delete(),
    suspendedAt: suspend ? FieldValue.serverTimestamp() : FieldValue.delete(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  const products = suspend
    ? await db
        .collection(Collections.products)
        .where('sellerId', '==', sellerId)
        .where('isActive', '==', true)
        .get()
    : await db
        .collection(Collections.products)
        .where('sellerId', '==', sellerId)
        .where('suspendedWithSeller', '==', true)
        .get();
  for (let i = 0; i < products.docs.length; i += 400) {
    const batch = db.batch();
    for (const p of products.docs.slice(i, i + 400)) {
      batch.update(p.ref, {
        isActive: !suspend,
        suspendedWithSeller: suspend ? true : FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  await writeAudit({
    actorId: adminId,
    action: suspend ? 'seller.suspended' : 'seller.reinstated',
    targetType: 'seller',
    targetId: sellerId,
    metadata: { reason, products: products.size },
  });
  await notify({
    recipientId: sellerId,
    audience: 'seller',
    title: suspend ? 'Store suspended' : 'Store reinstated',
    body: suspend
      ? `Your store is suspended: ${reason}. Your products are hidden and payouts are on hold.`
      : 'Your store is live again and held payouts will resume.',
    type: 'seller_approval',
    deepLink: '/seller',
  });

  return { ok: true, products: products.size };
});
