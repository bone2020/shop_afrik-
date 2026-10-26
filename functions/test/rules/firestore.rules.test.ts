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
