import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, seller } from '../helpers';
import { auth, db } from '../../src/lib/admin';
import { setUserRole } from '../../src/auth/setUserRole';

const call = fft.wrap(setUserRole);

beforeEach(clearFirestore);

describe('setUserRole', () => {
  it('rejects non-admins', async () => {
    for (const caller of [buyer, seller]) {
      await expectHttpsError(
        call(asUser(caller, { uid: caller.uid, role: 'admin' }) as never),
        'permission-denied',
      );
    }
  });

  it('lets an admin grant a role and audits it', async () => {
    const user = await auth.createUser({ email: `c${Date.now()}@test.dev` });
    await call(asUser(admin, { uid: user.uid, role: 'delivery' }) as never);

    const fresh = await auth.getUser(user.uid);
    expect(fresh.customClaims).toMatchObject({ role: 'delivery' });
    const audit = await db
      .collection('admin_audit')
      .where('targetId', '==', user.uid)
      .get();
    expect(audit.docs[0].data()).toMatchObject({
      actorId: admin.uid,
      action: 'user.role.set',
    });
  });
});
