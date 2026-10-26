import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, seller, supervisor } from '../helpers';
import { auth, db } from '../../src/lib/admin';
import { setUserRole } from '../../src/auth/setUserRole';

const call = fft.wrap(setUserRole);

async function newUser(claims?: Record<string, unknown>) {
  const user = await auth.createUser({
    email: `u${Date.now()}${Math.random().toString(36).slice(2)}@test.dev`,
  });
  if (claims) await auth.setCustomUserClaims(user.uid, claims);
  return user.uid;
}

beforeEach(clearFirestore);

describe('setUserRole (SA-130)', () => {
  it('rejects buyers, sellers and ordinary admins', async () => {
    const target = await newUser();
    for (const caller of [buyer, seller, admin]) {
      await expectHttpsError(
        call(asUser(caller, { uid: target, role: 'admin', adminTier: 'supervisor' }) as never),
        'permission-denied',
      );
    }
    expect((await auth.getUser(target)).customClaims ?? {}).toEqual({});
  });

  it('rejects changing your own claims, even as a supervisor', async () => {
    await expectHttpsError(
      call(asUser(supervisor, { uid: supervisor.uid, role: 'buyer' }) as never),
      'permission-denied',
    );
  });

  it('lets a supervisor grant a courier role, mirrored to staff and audited', async () => {
    const target = await newUser({ betaTester: true });
    await call(asUser(supervisor, { uid: target, role: 'delivery' }) as never);

    expect((await auth.getUser(target)).customClaims).toEqual({
      betaTester: true, // other claims survive (SA-062)
      role: 'delivery',
    });
    expect((await db.doc(`staff/${target}`).get()).data()).toMatchObject({
      role: 'delivery',
    });
    const audit = await db.collection('admin_audit').where('targetId', '==', target).get();
    expect(audit.docs[0].data()).toMatchObject({
      actorId: supervisor.uid,
      action: 'user.role.set',
    });
  });

  it('revokes a staff role when granting buyer', async () => {
    const target = await newUser({ role: 'admin', adminTier: 'supervisor' });
    await db.doc(`staff/${target}`).set({ role: 'admin' });

    await call(asUser(supervisor, { uid: target, role: 'buyer' }) as never);

    expect((await auth.getUser(target)).customClaims).toEqual({});
    expect((await db.doc(`staff/${target}`).get()).exists).toBe(false);
    const audit = await db.collection('admin_audit').where('targetId', '==', target).get();
    expect(audit.docs[0].data()).toMatchObject({
      action: 'user.role.revoked',
      metadata: { previousRole: 'admin', previousAdminTier: 'supervisor' },
    });
  });
});
