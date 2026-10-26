import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { Collections } from '../types';

/**
 * A seller (or admin) removes a product (SA-044). A product that has ever
 * been ordered is archived instead of deleted, so order history, refunds and
 * reviews keep pointing at it; one that was never ordered is deleted.
 */
export const removeProduct = onCall(async (req) => {
  const uid = requireAuth(req);
  const productId = req.data?.productId as string | undefined;
  if (!productId) throw new HttpsError('invalid-argument', 'productId required.');

  const ref = db.collection(Collections.products).doc(productId);
  const product = (await ref.get()).data();
  if (!product) throw new HttpsError('not-found', 'Product not found.');
  const isAdmin = req.auth?.token.role === 'admin';
  if (product.sellerId !== uid && !isAdmin) {
    throw new HttpsError('permission-denied', 'You can only remove your own products.');
  }

  const archived = product.hasOrders === true;
  if (archived) {
    await ref.update({
      archived: true,
      isActive: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
  } else {
    await ref.delete();
  }
  await writeAudit({
    actorId: uid,
    action: archived ? 'product.archived' : 'product.deleted',
    targetType: 'product',
    targetId: productId,
  });
  return { ok: true, archived };
});
