import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { alertAdmins } from '../lib/notify';
import { Collections } from '../types';

/**
 * A seller on the order gives their side of an open refund request (SA-055).
 * The reply is shown to the admins deciding it; sending again replaces it.
 * The decision itself stays with the admins.
 */
export const respondToRefund = onCall(async (req) => {
  const sellerId = requireRole(req, 'seller');
  const refundId = req.data?.refundId as string | undefined;
  const text = ((req.data?.response as string | undefined) ?? '').trim();
  if (!refundId || !text) {
    throw new HttpsError('invalid-argument', 'Write a reply before sending.');
  }
  if (text.length > 1000) {
    throw new HttpsError('invalid-argument', 'Keep the reply under 1000 characters.');
  }

  const ref = db.collection(Collections.refundRequests).doc(refundId);
  const refund = (await ref.get()).data();
  if (!refund || !((refund.sellerIds ?? []) as string[]).includes(sellerId)) {
    throw new HttpsError('permission-denied', 'This refund is not on your order.');
  }
  // Once approved the money is moving, so replies close with the decision.
  if (!['requested', 'underReview', 'escalated'].includes(refund.status)) {
    throw new HttpsError('failed-precondition', 'This refund has already been decided.');
  }

  await ref.update({
    [`sellerResponses.${sellerId}`]: { text, at: new Date().toISOString() },
  });
  await writeAudit({
    actorId: sellerId,
    action: 'refund.seller_responded',
    targetType: 'refund_request',
    targetId: refundId,
  });
  await alertAdmins({
    title: 'Seller replied to a refund',
    body: `The seller replied on the refund for order ${refund.orderId}.`,
    type: 'refund_response',
    deepLink: '/admin',
  });
  return { ok: true };
});
