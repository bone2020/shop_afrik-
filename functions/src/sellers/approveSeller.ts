import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { auth, db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { Collections } from '../types';

/**
 * Admin approves (or rejects) a seller. Approval requires verified QR Wallet
 * KYC (plan §6) and grants the `seller` role claim used by the security rules.
 */
export const approveSeller = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const sellerId = req.data?.sellerId as string | undefined;
  const approve = req.data?.approve as boolean | undefined;
  if (!sellerId || typeof approve !== 'boolean') {
    throw new HttpsError('invalid-argument', 'sellerId and approve required.');
  }

  const ref = db.collection(Collections.sellers).doc(sellerId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Seller not found.');

  if (approve && snap.data()!.kycStatus !== 'verified') {
    throw new HttpsError(
      'failed-precondition',
      'Seller KYC must be verified before approval.',
    );
  }

  if (approve) {
    // Preserve other claims (SA-062). Roles are single-valued, so refuse
    // rather than silently strip a staff role from an admin or courier.
    const existing = (await auth.getUser(sellerId)).customClaims ?? {};
    if (existing.role && existing.role !== 'seller') {
      throw new HttpsError(
        'failed-precondition',
        `This account already has the ${existing.role} role.`,
      );
    }
    await auth.setCustomUserClaims(sellerId, { ...existing, role: 'seller' });
  }

  await ref.update({
    approvalStatus: approve ? 'approved' : 'rejected',
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writeAudit({
    actorId: adminId,
    action: approve ? 'seller.approved' : 'seller.rejected',
    targetType: 'seller',
    targetId: sellerId,
  });
  await notify({
    recipientId: sellerId,
    audience: 'seller',
    title: approve ? 'Store approved' : 'Store application declined',
    body: approve
      ? 'You can now list products on Shop Afrik.'
      : 'Your seller application was not approved.',
    type: 'seller_approval',
    deepLink: '/seller',
  });

  return { ok: true };
});
