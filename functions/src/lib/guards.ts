import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';
import { UserRole } from '../types';

/**
 * Returns the caller's uid, or rejects an unauthenticated call. Roles come
 * only from custom auth claims (`role`, `adminTier`), never from client data.
 */
export function requireAuth(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in to continue.');
  }
  return uid;
}

/** Returns the caller's uid if their `role` claim is [role]; rejects otherwise. */
export function requireRole(req: CallableRequest, role: UserRole): string {
  const uid = requireAuth(req);
  if (req.auth?.token.role !== role) {
    throw new HttpsError(
      'permission-denied',
      'You do not have permission to do this.',
    );
  }
  return uid;
}

/** Whether the caller is an admin with the `supervisor` tier. */
export function isSupervisor(req: CallableRequest): boolean {
  const token = req.auth?.token;
  return token?.role === 'admin' && token?.adminTier === 'supervisor';
}
