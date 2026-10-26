import { Timestamp } from 'firebase-admin/firestore';
import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, otherBuyer, seller } from '../helpers';
import { db } from '../../src/lib/admin';
import { resetMockBehavior, setMockBehavior } from '../../src/lib/mockBonsPay';
import { payOrder } from '../../src/orders/payOrder';
import { assignCourier } from '../../src/orders/assignCourier';
import { cancelOrder, markShipped, submitProofOfDelivery } from '../../src/orders/transitions';
import { releaseExpired } from '../../src/orders/releaseExpiredReservations';

const pay = fft.wrap(payOrder);
const cancel = fft.wrap(cancelOrder);
const assign = fft.wrap(assignCourier);
const ship = fft.wrap(markShipped);
const proof = fft.wrap(submitProofOfDelivery);
const courier = { uid: 'courier1', role: 'delivery' };
const ghs = (minorUnits: number) => ({ minorUnits, currency: 'GHS' });

async function seedOrder(id: string, buyerId: string, quantity = 1) {
  await db.doc(`orders/${id}`).set({
    buyerId,
    status: 'awaitingPayment',
    sellerIds: [seller.uid],
    items: [{
      productId: 'p1', sellerId: seller.uid, title: 'Kente',
      unitPrice: ghs(5000), quantity, refundedQuantity: 0,
    }],
    subtotal: ghs(5000 * quantity),
    total: ghs(5000 * quantity),
  });
}
const stock = async () => (await db.doc('products/p1').get()).data()!.stock;
const order = async (id: string) => (await db.doc(`orders/${id}`).get()).data()!;
const mockEscrow = async () =>
  ((await db.doc('_mock_bonspay/balances_GHS').get()).data()?.escrow as number) ?? 0;

beforeAll(() => { process.env.QR_WALLET_MODE = 'mock'; });
afterAll(() => { delete process.env.QR_WALLET_MODE; });
beforeEach(async () => {
  resetMockBehavior();
  await clearFirestore();
  await db.doc('products/p1').set({ title: 'Kente', sellerId: seller.uid, stock: 1 });
  await db.doc('staff/courier1').set({ role: 'delivery' });
  await db.doc('staff/admin1').set({ role: 'admin' });
});

describe('stock reservation (SA-040)', () => {
  it('two buyers, one unit: exactly one is confirmed and the other is never charged', async () => {
    await seedOrder('oA', buyer.uid);
    await seedOrder('oB', otherBuyer.uid);

    const results = await Promise.allSettled([
      pay(asUser(buyer, { orderId: 'oA', method: 'payNow' }) as never),
      pay(asUser(otherBuyer, { orderId: 'oB', method: 'payNow' }) as never),
    ]);

    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const statuses = [(await order('oA')).status, (await order('oB')).status].sort();
    expect(statuses).toEqual(['awaitingPayment', 'confirmed']);
    expect(await stock()).toBe(0);
    // The fake BonsPay recorded exactly one capture.
    expect(await mockEscrow()).toBe(5000);
    const captures = await db.collection('_mock_bonspay').where('op', '==', 'capture').get();
    expect(captures.size).toBe(1);
  });

  it('a declined payment releases the reservation', async () => {
    await seedOrder('oA', buyer.uid);
    setMockBehavior('capture', 'fail');
    await expectHttpsError(pay(asUser(buyer, { orderId: 'oA', method: 'payNow' }) as never), 'aborted');
    expect(await stock()).toBe(1);
    expect((await order('oA')).stockReserved).toBe(false);
  });

  it('an abandoned reservation is released when it expires, with nothing captured', async () => {
    await seedOrder('oA', buyer.uid);
    await db.doc('orders/oA').update({
      stockReserved: true,
      reservationExpiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
    await db.doc('products/p1').update({ stock: 0 });

    expect(await releaseExpired(Timestamp.now())).toBe(1);
    expect(await stock()).toBe(1);
    expect(await mockEscrow()).toBe(0);
  });

  it('a payment in doubt keeps its stock and blocks cancellation', async () => {
    await seedOrder('oA', buyer.uid);
    setMockBehavior('capture', 'timeout');
    await expectHttpsError(
      pay(asUser(buyer, { orderId: 'oA', method: 'payNow' }) as never),
      'deadline-exceeded',
    );
    expect((await order('oA')).paymentInDoubt).toBe(true);
    expect(await stock()).toBe(0);
    expect(await releaseExpired(Timestamp.fromMillis(Date.now() + 60 * 60 * 1000))).toBe(0);
    await expectHttpsError(cancel(asUser(buyer, { orderId: 'oA' }) as never), 'failed-precondition');
  });

  it('cancelling a confirmed order refunds escrow and returns the stock', async () => {
    await seedOrder('oA', buyer.uid);
    await pay(asUser(buyer, { orderId: 'oA', method: 'payNow' }) as never);
    await cancel(asUser(buyer, { orderId: 'oA' }) as never);
    expect(await order('oA')).toMatchObject({ status: 'cancelled', paymentStatus: 'refunded' });
    expect(await stock()).toBe(1);
    expect(await mockEscrow()).toBe(0);
  });
});

describe('pay on delivery (SA-028)', () => {
  async function deliverPodOrder() {
    await seedOrder('oA', buyer.uid);
    await pay(asUser(buyer, { orderId: 'oA', method: 'payOnDelivery' }) as never);
    await assign(asUser(admin, { orderId: 'oA', courierId: courier.uid }) as never);
    await ship(asUser(seller, { orderId: 'oA' }) as never);
    await proof(asUser(courier, { orderId: 'oA', barcode: 'oA' }) as never);
  }

  it('schedules settlement only after the hold is captured', async () => {
    await deliverPodOrder();
    const o = await order('oA');
    expect(o).toMatchObject({
      status: 'delivered',
      paymentStatus: 'captured',
      settlementStatus: 'scheduled',
    });
    expect(o.settlementDueAt).toBeDefined();
    expect(await mockEscrow()).toBe(5000);
  });

  it('a failed capture leaves settlement unscheduled and alerts staff', async () => {
    setMockBehavior('captureHold', 'fail');
    await deliverPodOrder();
    const o = await order('oA');
    expect(o.status).toBe('delivered');
    expect(o.paymentStatus).toBe('captureFailed');
    expect(o.settlementStatus).not.toBe('scheduled');
    expect(o.settlementDueAt).toBeUndefined();

    const alerts = await db
      .collection('notifications')
      .where('recipientId', '==', 'admin1')
      .where('type', '==', 'capture_failed')
      .get();
    expect(alerts.size).toBe(1);
  });
});
