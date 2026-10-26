import functionsTest from 'firebase-functions-test';

export const PROJECT_ID = 'demo-shop-afrik';

// Must run before any module under src/ initializes the Admin SDK.
process.env.GCLOUD_PROJECT = PROJECT_ID;
export const fft = functionsTest({ projectId: PROJECT_ID });

/** Wipes the Firestore emulator between tests. */
export async function clearFirestore(): Promise<void> {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  if (!host) throw new Error('Run tests with `npm test` (needs the emulator).');
  await fetch(
    `http://${host}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
}

export interface Caller {
  uid: string;
  role?: string;
  adminTier?: string;
}

/** Builds a callable request as a signed-in user with the given claims. */
export function asUser(caller: Caller, data: Record<string, unknown>) {
  const token: Record<string, unknown> = { uid: caller.uid };
  if (caller.role) token.role = caller.role;
  if (caller.adminTier) token.adminTier = caller.adminTier;
  return { data, auth: { uid: caller.uid, token } };
}

export const buyer: Caller = { uid: 'buyer1' };
export const otherBuyer: Caller = { uid: 'buyer2' };
export const seller: Caller = { uid: 'seller1', role: 'seller' };
export const admin: Caller = { uid: 'admin1', role: 'admin', adminTier: 'admin' };
export const supervisor: Caller = {
  uid: 'super1',
  role: 'admin',
  adminTier: 'supervisor',
};

/** Expects [p] to reject with an HttpsError carrying [code]. */
export async function expectHttpsError(
  p: Promise<unknown>,
  code: string,
): Promise<void> {
  await expect(p).rejects.toMatchObject({ code });
}
