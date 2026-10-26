import { Timestamp } from 'firebase-admin/firestore';
import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, seller } from '../helpers';
import { db } from '../../src/lib/admin';
import { resetMockBehavior } from '../../src/lib/mockBonsPay';
import { expireStale } from '../../src/orders/expireStaleOrders';
import { payOrder } from '../../src/orders/payOrder';
import { respondToRefund } from '../../src/refunds/respondToRefund';

const HOUR = 60 * 60 * 1000;
const ghs = (minorUnits: number) => ({ minorUnits, currency: 'GHS' });
const ago = (hours: number) => Timestamp.fromMillis(Date.now() - hours * HOUR);
const call = { pay: fft.wrap(payOrder), respond: fft.wrap(respondToRefund) };

beforeAll(() => { process.env.QR_WALLET_MODE = 'mock'; });
afterAll(() => { delete process.env.QR_WALLET_MODE; });
beforeEach(async () => {
  resetMockBehavior();
  await clearFirestore();
  await db.doc(`staff/${admin.uid}`).set({ role: 'admin' });
});

describe('expireStale (SA-042)', () => {
  it('cancels orders left too long without a quote or payment', async () => {
    await db.doc('orders/oldQuote').set({ buyerId: buyer.uid, status: 'awaitingDeliveryQuote', createdAt: ago(49) });
    await db.doc('orders/newQuote').set({ buyerId: buyer.uid, status: 'awaitingDeliveryQuote', createdAt: ago(10) });
    await db.doc('orders/oldPay').set({ buyerId: buyer.uid, status: 'awaitingPayment', createdAt: ago(200), quotedAt: ago(73) });
    await db.doc('orders/paying').set({
      buyerId: buyer.uid, status: 'awaitingPayment', quotedAt: ago(100), stockReserved: true,
    });
    await db.doc('orders/inDoubt').set({
      buyerId: buyer.uid, status: 'awaitingPayment', quotedAt: ago(100), paymentInDoubt: true,
    });

    expect(await expireStale(Timestamp.now())).toBe(2);
    const status = async (id: string) => (await db.doc(`orders/${id}`).get()).data()!;
    expect(await status('oldQuote')).toMatchObject({ status: 'cancelled', cancelReason: 'quoteExpired' });
    expect(await status('oldPay')).toMatchObject({ status: 'cancelled', cancelReason: 'paymentExpired' });
    expect((await status('newQuote')).status).toBe('awaitingDeliveryQuote');
    expect((await status('paying')).status).toBe('awaitingPayment');
    expect((await status('inDoubt')).status).toBe('awaitingPayment');

    const notes = await db.collection('notifications').where('type', '==', 'order_expired').get();
    expect(notes.size).toBe(2);
  });

  it('uses the timeouts from settings', async () => {
    await db.doc('settings/platform').set({ quoteExpiryHours: 4 });
    await db.doc('orders/o1').set({ buyerId: buyer.uid, status: 'awaitingDeliveryQuote', createdAt: ago(5) });
    expect(await expireStale(Timestamp.now())).toBe(1);
  });
});

describe('low-stock alerts (SA-067)', () => {
  async function order(id: string, productId: string, quantity: number) {
    await db.doc(`orders/${id}`).set({
      buyerId: buyer.uid,
      status: 'awaitingPayment',
      items: [{ productId, sellerId: seller.uid, title: productId, unitPrice: ghs(100), quantity }],
      total: ghs(100 * quantity),
    });
    await call.pay(asUser(buyer, { orderId: id, method: 'payNow' }) as never);
  }
  const sellerNotes = async () =>
    (await db.collection('notifications').where('recipientId', '==', seller.uid).get()).docs
      .map((d) => d.data())
      .filter((n) => n.type === 'low_stock')
      .map((n) => n.title)
      .sort();

  it('warns once at the low-stock level and again when sold out', async () => {
    await db.doc('products/shea').set({ sellerId: seller.uid, title: 'Shea', stock: 5, lowStockThreshold: 3 });
    await order('o1', 'shea', 1); // 5 -> 4: nothing
    expect(await sellerNotes()).toEqual([]);
    await order('o2', 'shea', 2); // 4 -> 2: low stock
    expect(await sellerNotes()).toEqual(['Low stock']);
    await order('o3', 'shea', 1); // 2 -> 1: already low, no repeat
    await order('o4', 'shea', 1); // 1 -> 0: sold out
    expect(await sellerNotes()).toEqual(['Low stock', 'Sold out']);
  });
});

describe('respondToRefund (SA-055)', () => {
  beforeEach(async () => {
    await db.doc('refund_requests/r1').set({
      orderId: 'o1', buyerId: buyer.uid, sellerIds: [seller.uid], status: 'requested', reason: 'Torn',
    });
  });
  const respond = (caller: typeof seller, data: Record<string, unknown>) =>
    call.respond(asUser(caller, { refundId: 'r1', ...data }) as never);

  it('a seller on the order replies and admins are told', async () => {
    await respond(seller, { response: 'It was checked before dispatch.' });
    const r = (await db.doc('refund_requests/r1').get()).data()!;
    expect(r.sellerResponses[seller.uid].text).toBe('It was checked before dispatch.');
    const notes = await db.collection('notifications').where('type', '==', 'refund_response').get();
    expect(notes.size).toBe(1);
  });

  it('rejects other sellers, empty replies and decided refunds', async () => {
    await expectHttpsError(respond({ uid: 'other', role: 'seller' }, { response: 'x' }), 'permission-denied');
    await expectHttpsError(respond(buyer, { response: 'x' }), 'permission-denied');
    await expectHttpsError(respond(seller, { response: '   ' }), 'invalid-argument');
    await db.doc('refund_requests/r1').update({ status: 'approved' });
    await expectHttpsError(respond(seller, { response: 'late' }), 'failed-precondition');
  });
});
