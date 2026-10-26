import { admin, asUser, clearFirestore, expectHttpsError, fft } from '../helpers';
import { auth, db } from '../../src/lib/admin';
import { approveSeller } from '../../src/sellers/approveSeller';

const call = fft.wrap(approveSeller);

async function applicant(claims?: Record<string, unknown>) {
  const user = await auth.createUser({
    email: `s${Date.now()}${Math.random().toString(36).slice(2)}@test.dev`,
  });
  if (claims) await auth.setCustomUserClaims(user.uid, claims);
  await db.doc(`sellers/${user.uid}`).set({
    kycStatus: 'verified',
    approvalStatus: 'pending',
  });
  return user.uid;
}

beforeEach(clearFirestore);

describe('approveSeller (SA-062)', () => {
  it('keeps other claims when granting seller', async () => {
    const uid = await applicant({ betaTester: true });
    await call(asUser(admin, { sellerId: uid, approve: true }) as never);
    expect((await auth.getUser(uid)).customClaims).toEqual({
      betaTester: true,
      role: 'seller',
    });
  });

  it('refuses to strip a staff role, leaving the application pending', async () => {
    const uid = await applicant({ role: 'admin', adminTier: 'admin' });
    await expectHttpsError(
      call(asUser(admin, { sellerId: uid, approve: true }) as never),
      'failed-precondition',
    );
    expect((await auth.getUser(uid)).customClaims).toMatchObject({ role: 'admin' });
    expect((await db.doc(`sellers/${uid}`).get()).data()!.approvalStatus).toBe('pending');
  });
});
