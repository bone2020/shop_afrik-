import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { Collections } from '../types';

/**
 * Admin approves or rejects a seller-submitted product. Products start pending
 * and are hidden from buyers until approved (the catalog query filters on
 * approvalStatus). Mirrors the seller-approval flow.
 */
export const approveProduct = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const productId = req.data?.productId as string | undefined;
  const approve = req.data?.approve as boolean | undefined;
  if (!productId || typeof approve !== 'boolean') {
    throw new HttpsError('invalid-argument', 'productId and approve required.');
  }

  const ref = db.collection(Collections.products).doc(productId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Product not found.');
  const product = snap.data()!;

  await ref.update({
    approvalStatus: approve ? 'approved' : 'rejected',
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writeAudit({
    actorId: adminId,
    action: approve ? 'product.approved' : 'product.rejected',
    targetType: 'product',
    targetId: productId,
  });
  await notify({
    recipientId: product.sellerId as string,
    audience: 'seller',
    title: approve ? 'Product approved' : 'Product rejected',
    body: approve
        ? `"${product.title}" is now live.`
        : `"${product.title}" was not approved.`,
    type: 'product_approval',
    deepLink: '/seller',
  });

  return { ok: true };
});
