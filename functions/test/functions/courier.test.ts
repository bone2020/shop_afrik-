import { admin, asUser, clearFirestore, expectHttpsError, fft } from '../helpers';
import { db } from '../../src/lib/admin';
import { assignCourier } from '../../src/orders/assignCourier';
import { submitProofOfDelivery } from '../../src/orders/transitions';

const assign = fft.wrap(assignCourier);
const submitProof = fft.wrap(submitProofOfDelivery);

const courierA = { uid: 'courierA', role: 'delivery' };
const courierB = { uid: 'courierB', role: 'delivery' };

beforeEach(async () => {
  await clearFirestore();
  await db.doc('staff/courierA').set({ role: 'delivery' });
  await db.doc('staff/courierB').set({ role: 'delivery' });
  await db.doc('orders/o1').set({
    buyerId: 'buyer1',
    status: 'shipped',
    paymentMethod: 'payNow',
    total: { minorUnits: 1000, currency: 'GHS' },
  });
});

describe('assignCourier (SA-120)', () => {
  it('is admin-only', async () => {
    await expectHttpsError(
      assign(asUser(courierA, { orderId: 'o1', courierId: 'courierA' }) as never),
      'permission-denied',
    );
  });

  it('only assigns users who are couriers', async () => {
    await expectHttpsError(
      assign(asUser(admin, { orderId: 'o1', courierId: 'buyer1' }) as never),
      'failed-precondition',
    );
  });

  it('records the courier and audits it', async () => {
    await assign(asUser(admin, { orderId: 'o1', courierId: 'courierA' }) as never);
    expect((await db.doc('orders/o1').get()).data()!.courierId).toBe('courierA');
    const audit = await db.collection('admin_audit').where('action', '==', 'order.courier.assigned').get();
    expect(audit.size).toBe(1);
  });
});

describe('submitProofOfDelivery (SA-120)', () => {
  beforeEach(() =>
    assign(asUser(admin, { orderId: 'o1', courierId: 'courierA' }) as never));

  it('courier B cannot confirm courier A\'s delivery', async () => {
    await expectHttpsError(
      submitProof(asUser(courierB, { orderId: 'o1', barcode: 'o1' }) as never),
      'permission-denied',
    );
    expect((await db.doc('orders/o1').get()).data()!.status).toBe('shipped');
  });

  it('the assigned courier can confirm it', async () => {
    await submitProof(asUser(courierA, { orderId: 'o1', barcode: 'o1' }) as never);
    const order = (await db.doc('orders/o1').get()).data()!;
    expect(order.status).toBe('delivered');
    expect(order.deliveryProof.deliveryPersonId).toBe('courierA');
  });
});
