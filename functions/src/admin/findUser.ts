import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { UserRecord } from 'firebase-admin/auth';
import { auth } from '../lib/admin';
import { requireRole } from '../lib/guards';

/**
 * Admin looks up an account by email, phone number (+country code) or uid
 * (SA-132), so a supervisor can grant roles and admins can search orders by
 * buyer. Returns null when nothing matches.
 */
export const findUser = onCall(async (req) => {
  requireRole(req, 'admin');
  const query = (req.data?.query as string | undefined)?.trim();
  if (!query) throw new HttpsError('invalid-argument', 'Enter an email, phone or user id.');

  let user: UserRecord | null = null;
  try {
    if (query.includes('@')) user = await auth.getUserByEmail(query.toLowerCase());
    else if (query.startsWith('+')) user = await auth.getUserByPhoneNumber(query.replace(/[\s-]/g, ''));
    else user = await auth.getUser(query);
  } catch (e) {
    if ((e as { code?: string }).code !== 'auth/user-not-found') {
      if ((e as { code?: string }).code?.startsWith('auth/invalid')) {
        throw new HttpsError('invalid-argument', 'That does not look like an email, phone or user id.');
      }
      throw e;
    }
  }
  if (!user) return { user: null };

  const claims = user.customClaims ?? {};
  return {
    user: {
      uid: user.uid,
      email: user.email ?? null,
      phone: user.phoneNumber ?? null,
      displayName: user.displayName ?? null,
      role: (claims.role as string | undefined) ?? 'buyer',
      adminTier: (claims.adminTier as string | undefined) ?? null,
      disabled: user.disabled,
    },
  };
});
