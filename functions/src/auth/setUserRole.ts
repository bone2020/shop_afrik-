import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { auth, db } from '../lib/admin';
import { writeAudit } from '../lib/audit';
import { isSupervisor, requireRole } from '../lib/guards';
import { AdminTier, Collections, UserRole } from '../types';

/**
 * Sets or revokes a user's role (and admin tier) via custom claims.
 * Supervisor-only (SA-130): an ordinary admin cannot grant roles, so nobody can
 * mint a second account to approve tier-2 refunds alone. Nobody may change
 * their own claims. Granting `buyer` revokes any staff role.
 *
 * Other custom claims are preserved (SA-062). Each change is mirrored to
 * `staff/{uid}` so admins can pick couriers and review who holds which role.
 */
export const setUserRole = onCall(async (req) => {
  const actorId = requireRole(req, 'admin');
  if (!isSupervisor(req)) {
    throw new HttpsError(
      'permission-denied',
      'Only a supervisor can grant or revoke roles.',
    );
  }

  const targetUid = req.data?.uid as string | undefined;
  const role = req.data?.role as UserRole | undefined;
  const adminTier = req.data?.adminTier as AdminTier | undefined;

  if (!targetUid || !role) {
    throw new HttpsError('invalid-argument', 'uid and role are required.');
  }
  if (!['buyer', 'seller', 'admin', 'delivery'].includes(role)) {
    throw new HttpsError('invalid-argument', `Unknown role: ${role}`);
  }
  if (adminTier && !['admin', 'supervisor'].includes(adminTier)) {
    throw new HttpsError('invalid-argument', `Unknown admin tier: ${adminTier}`);
  }
  if (targetUid === actorId) {
    throw new HttpsError(
      'permission-denied',
      'You cannot change your own role.',
    );
  }

  const user = await auth.getUser(targetUid);
  const previous = user.customClaims ?? {};
  const claims: Record<string, unknown> = { ...previous };
  delete claims.role;
  delete claims.adminTier;
  if (role !== 'buyer') claims.role = role;
  if (role === 'admin') claims.adminTier = adminTier ?? 'admin';

  await auth.setCustomUserClaims(targetUid, claims);

  const staffRef = db.collection(Collections.staff).doc(targetUid);
  if (role === 'admin' || role === 'delivery') {
    await staffRef.set({
      role,
      adminTier: claims.adminTier ?? null,
      email: user.email ?? null,
      phone: user.phoneNumber ?? null,
      displayName: user.displayName ?? null,
      updatedAt: new Date().toISOString(),
    });
  } else {
    await staffRef.delete();
  }

  await writeAudit({
    actorId,
    action: role === 'buyer' ? 'user.role.revoked' : 'user.role.set',
    targetType: 'user',
    targetId: targetUid,
    metadata: {
      role,
      adminTier: claims.adminTier ?? null,
      previousRole: previous.role ?? null,
      previousAdminTier: previous.adminTier ?? null,
    },
  });

  return { ok: true };
});
