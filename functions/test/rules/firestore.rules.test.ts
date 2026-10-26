import { readFileSync } from 'fs';
import { resolve } from 'path';
import {
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { PROJECT_ID } from '../helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(resolve(__dirname, '../../../firestore.rules'), 'utf8'),
    },
  });
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'orders/o1'), {
      buyerId: 'buyer1',
      sellerIds: ['seller1'],
      status: 'confirmed',
    });
    await setDoc(doc(db, 'notifications/n1'), {
      recipientId: 'buyer1',
      title: 'Hi',
      isRead: false,
    });
    await setDoc(doc(db, 'admin_audit/a1'), { actorId: 'admin1' });
    await setDoc(doc(db, 'orders/shippedA'), {
      buyerId: 'buyer1',
      sellerIds: ['seller1'],
      status: 'shipped',
      courierId: 'courierA',
    });
    await setDoc(doc(db, 'orders/confirmedA'), {
      buyerId: 'buyer1',
      sellerIds: ['seller1'],
      status: 'confirmed',
      courierId: 'courierA',
    });
    await setDoc(doc(db, 'refund_requests/r1'), {
      buyerId: 'buyer1',
      orderId: 'o1',
      sellerIds: ['seller1'],
      status: 'requested',
    });
    await setDoc(doc(db, 'staff/courierA'), { role: 'delivery' });
  });
});

const as = (uid: string, claims: Record<string, unknown> = {}) =>
  env.authenticatedContext(uid, claims).firestore();

describe('orders', () => {
  it('buyer and seller on the order can read it', async () => {
    await assertSucceeds(getDoc(doc(as('buyer1'), 'orders/o1')));
    await assertSucceeds(
      getDoc(doc(as('seller1', { role: 'seller' }), 'orders/o1')),
    );
  });

  it('other buyers and sellers cannot read it', async () => {
    await assertFails(getDoc(doc(as('buyer2'), 'orders/o1')));
    await assertFails(getDoc(doc(as('seller2', { role: 'seller' }), 'orders/o1')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'orders/o1')));
  });

  it('no client can write orders, not even an admin', async () => {
    await assertFails(
      updateDoc(doc(as('buyer1'), 'orders/o1'), { status: 'completed' }),
    );
    await assertFails(
      updateDoc(doc(as('admin1', { role: 'admin' }), 'orders/o1'), {
        status: 'completed',
      }),
    );
  });
});

describe('couriers (SA-120)', () => {
  const courier = (uid: string) => as(uid, { role: 'delivery' });

  it('the assigned courier reads their shipped order', async () => {
    await assertSucceeds(getDoc(doc(courier('courierA'), 'orders/shippedA')));
  });

  it('courier B cannot read courier A\'s delivery', async () => {
    await assertFails(getDoc(doc(courier('courierB'), 'orders/shippedA')));
  });

  it('couriers cannot read unassigned or not-yet-shipped orders', async () => {
    await assertFails(getDoc(doc(courier('courierA'), 'orders/o1')));
    await assertFails(getDoc(doc(courier('courierA'), 'orders/confirmedA')));
  });
});

describe('refund requests (SA-140)', () => {
  it('a seller on the order can read the refund', async () => {
    await assertSucceeds(
      getDoc(doc(as('seller1', { role: 'seller' }), 'refund_requests/r1')),
    );
  });

  it('buyers cannot create refund requests directly (SA-050)', async () => {
    await assertFails(
      setDoc(doc(as('buyer1'), 'refund_requests/forged'), {
        buyerId: 'buyer1',
        orderId: 'o1',
        status: 'requested',
        amount: { minorUnits: 99999999, currency: 'GHS' },
      }),
    );
  });

  it('seller B cannot read seller A\'s refund', async () => {
    await assertFails(
      getDoc(doc(as('seller2', { role: 'seller' }), 'refund_requests/r1')),
    );
  });
});

describe('staff directory', () => {
  it('admins read it; nobody else does and nobody writes it', async () => {
    await assertSucceeds(getDoc(doc(as('admin1', { role: 'admin' }), 'staff/courierA')));
    await assertFails(getDoc(doc(as('courierA', { role: 'delivery' }), 'staff/courierA')));
    await assertFails(
      setDoc(doc(as('admin1', { role: 'admin' }), 'staff/x'), { role: 'admin' }),
    );
  });
});

describe('seller applications (SA-102)', () => {
  const application = {
    storeName: 'Ama Crafts',
    kycStatus: 'notStarted',
    approvalStatus: 'pending',
  };

  it('an unverified email account cannot apply', async () => {
    const db = as('newSeller', { email: 'a@test.dev', email_verified: false });
    await assertFails(setDoc(doc(db, 'sellers/newSeller'), application));
  });

  it('verified email and phone accounts can apply', async () => {
    const verified = as('s1', { email: 'b@test.dev', email_verified: true });
    await assertSucceeds(setDoc(doc(verified, 'sellers/s1'), application));
    const phone = as('s2', { phone_number: '+233200000000' });
    await assertSucceeds(setDoc(doc(phone, 'sellers/s2'), application));
  });
});

describe('notifications', () => {
  it('recipient may only flip isRead', async () => {
    const db = as('buyer1');
    await assertSucceeds(updateDoc(doc(db, 'notifications/n1'), { isRead: true }));
    await assertFails(updateDoc(doc(db, 'notifications/n1'), { title: 'x' }));
  });

  it('others cannot read it', async () => {
    await assertFails(getDoc(doc(as('buyer2'), 'notifications/n1')));
  });
});

describe('admin_audit', () => {
  it('is admin-read-only and never client-writable', async () => {
    await assertSucceeds(
      getDoc(doc(as('admin1', { role: 'admin' }), 'admin_audit/a1')),
    );
    await assertFails(getDoc(doc(as('buyer1'), 'admin_audit/a1')));
    await assertFails(
      setDoc(doc(as('admin1', { role: 'admin' }), 'admin_audit/a2'), {
        actorId: 'admin1',
      }),
    );
  });
});

describe('products', () => {
  const seller = () => as('s1', { role: 'seller' });
  const product = (over: Record<string, unknown> = {}) => ({
    sellerId: 's1',
    title: 'Shea butter',
    market: 'GH',
    approvalStatus: 'pending',
    isActive: true,
    ratingAverage: 0,
    ratingCount: 0,
    ...over,
  });
  const seedSeller = (approvalStatus: string) =>
    env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'sellers/s1'), {
        userId: 's1',
        market: 'GH',
        approvalStatus,
      }),
    );

  it('an approved seller lists only in their own market', async () => {
    await seedSeller('approved');
    await assertSucceeds(setDoc(doc(seller(), 'products/p1'), product()));
    await assertFails(
      setDoc(doc(seller(), 'products/p2'), product({ market: 'NG' })),
    );
  });

  it('pending and suspended sellers cannot list', async () => {
    for (const status of ['pending', 'suspended']) {
      await seedSeller(status);
      await assertFails(setDoc(doc(seller(), 'products/p1'), product()));
    }
  });

  it('a seller cannot move a product to another market', async () => {
    await seedSeller('approved');
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'products/p1'), product()),
    );
    await assertSucceeds(updateDoc(doc(seller(), 'products/p1'), { title: 'New' }));
    await assertFails(updateDoc(doc(seller(), 'products/p1'), { market: 'NG' }));
  });

  it('a suspended seller cannot edit their products', async () => {
    await seedSeller('suspended');
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'products/p1'), product()),
    );
    await assertFails(updateDoc(doc(seller(), 'products/p1'), { title: 'New' }));
  });
});

describe('settlements', () => {
  it('a seller reads only their own payouts and nobody writes them', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'settlements/o1_s1'), { sellerId: 's1', status: 'settled' }),
    );
    await assertSucceeds(getDoc(doc(as('s1', { role: 'seller' }), 'settlements/o1_s1')));
    await assertFails(getDoc(doc(as('s2', { role: 'seller' }), 'settlements/o1_s1')));
    await assertFails(
      updateDoc(doc(as('s1', { role: 'seller' }), 'settlements/o1_s1'), { status: 'onHold' }),
    );
  });
});
