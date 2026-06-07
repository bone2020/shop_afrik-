import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { auth } from '../lib/admin';
import { writeAudit } from '../lib/audit';
import { requireRole } from '../lib/guards';
import { AdminTier, UserRole } from '../types';

/**
 * Sets a user's role (and optional admin tier) via custom claims. Admin-only.
 *
 * Roles drive both the app's routing and the Firestore/Storage security rules,
 * so this is the single authority for granting them. Sellers are normally
 * promoted to the `seller` role through the seller-approval flow; this callable
 * also lets an existing admin provision other admins/supervisors.
 */
export const setUserRole = onCall(async (req) => {
  requireRole(req, 'admin');

  const targetUid = req.data?.uid as string | undefined;
  const role = req.data?.role as UserRole | undefined;
  const adminTier = req.data?.adminTier as AdminTier | undefined;

  if (!targetUid || !role) {
    throw new HttpsError('invalid-argument', 'uid and role are required.');
  }
  if (!['buyer', 'seller', 'admin'].includes(role)) {
    throw new HttpsError('invalid-argument', `Unknown role: ${role}`);
  }

  const claims: Record<string, unknown> = { role };
  if (role === 'admin') {
    claims.adminTier = adminTier ?? 'admin';
  }

  await auth.setCustomUserClaims(targetUid, claims);
  await writeAudit({
    actorId: req.auth!.uid,
    action: 'user.role.set',
    targetType: 'user',
    targetId: targetUid,
    metadata: { role, adminTier: claims.adminTier ?? null },
  });

  return { ok: true };
});
