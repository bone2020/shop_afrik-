import { Timestamp } from 'firebase-admin/firestore';
import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, otherBuyer, seller } from '../helpers';
import { db } from '../../src/lib/admin';
import { resetMockBehavior, setMockBehavior } from '../../src/lib/mockBonsPay';
import { settleDue } from '../../src/settlement/settleDueOrders';
import { reconcileAll } from '../../src/platform/reconcile';
import { requestRefund } from '../../src/refunds/requestRefund';
import { decideRefund } from '../../src/refunds/decideRefund';
import { payOrder } from '../../src/orders/payOrder';
import { deleteReview, submitReview } from '../../src/reviews/submitReview';
import { syncStore } from '../../src/sellers/syncStore';
import { removeProduct } from '../../src/products/removeProduct';

const DAY = 24 * 60 * 60 * 1000;
const ghs = (minorUnits: number) => ({ minorUnits, currency: 'GHS' });
const call = {
  request: fft.wrap(requestRefund),
  decide: fft.wrap(decideRefund),
  pay: fft.wrap(payOrder),
  review: fft.wrap(submitReview),
  deleteReview: fft.wrap(deleteReview),
  remove: fft.wrap(removeProduct),
};

async function deliveredOrder(id: string, sellerId = 'sellerA', dueDaysAgo = 1, status = 'delivered') {
  await db.doc(`orders/${id}`).set({
    buyerId: buyer.uid,
    status,
    sellerIds: [sellerId],
    items: [{ productId: 'p1', sellerId, title: 'Kente', unitPrice: ghs(1000), quantity: 1, refundedQuantity: 0 }],
    subtotal: ghs(1000),
    deliveryConfirmedAt: Timestamp.fromMillis(Date.now() - DAY),
    settlementStatus: 'scheduled',
    settlementDueAt: Timestamp.fromMillis(Date.now() - dueDaysAgo * DAY),
  });
}

const adminAlerts = async () =>
  (await db.collection('notifications').where('recipientId', '==', admin.uid).get()).docs.map(
    (d) => d.data(),
  );

beforeAll(() => { process.env.QR_WALLET_MODE = 'mock'; });
afterAll(() => { delete process.env.QR_WALLET_MODE; });
beforeEach(async () => {
  resetMockBehavior();
  await clearFirestore();
  await db.doc(`staff/${admin.uid}`).set({ role: 'admin' });
  await db.doc('_mock_bonspay/balances_GHS').set({ escrow: 1000000, payable: 0, commission: 0 });
  await db.doc('sellers/sellerA').set({ approvalStatus: 'approved' });
});

describe('settlement (SA-003, SA-004, SA-136)', () => {
  it('pays every due order across pages, even behind held ones', async () => {
    await db.doc('sellers/held').set({ approvalStatus: 'suspended' });
    // The two oldest are held, so a single page of 2 would pay nothing.
    await deliveredOrder('h1', 'held', 10);
    await deliveredOrder('h2', 'held', 9);
    for (const id of ['o1', 'o2', 'o3']) await deliveredOrder(id);

    expect(await settleDue(Timestamp.now(), 2)).toBe(3);
    for (const id of ['o1', 'o2', 'o3']) {
      expect((await db.doc(`orders/${id}`).get()).data()!.settlementStatus).toBe('settled');
    }
  });

  it('alerts staff when a payout fails and keeps the detail in the audit', async () => {
    await deliveredOrder('o1');
    setMockBehavior('settleToPayable', 'fail');
    expect(await settleDue(Timestamp.now())).toBe(0);

    expect((await db.doc('orders/o1').get()).data()!.settlementStatus).toBe('scheduled');
    expect(await adminAlerts()).toEqual([expect.objectContaining({ title: 'Seller payout failed' })]);
    const audit = await db.collection('admin_audit').where('action', '==', 'settlement.failed').get();
    expect(audit.docs[0].data().metadata.error).toBe('BonsPay declined settleToPayable.');
  });
});

describe('refund payout failure (SA-136, SA-147)', () => {
  it('alerts staff, shows a plain message, and approving again retries', async () => {
    await deliveredOrder('o1');
    const { refundId } = await call.request(asUser(buyer, {
      orderId: 'o1', lines: [{ productId: 'p1', quantity: 1 }], reason: 'Torn',
    }) as never);

    setMockBehavior('refundFromEscrow', 'fail');
    await expect(
      call.decide(asUser(admin, { refundId, decision: 'approve' }) as never),
    ).rejects.toMatchObject({ code: 'aborted', message: 'The payment was declined.' });
    expect((await db.doc(`refund_requests/${refundId}`).get()).data()!.status).toBe('approved');
    expect(await adminAlerts()).toEqual([expect.objectContaining({ title: 'Refund payout failed' })]);

    resetMockBehavior();
    const res = await call.decide(asUser(admin, { refundId, decision: 'approve' }) as never);
    expect(res.status).toBe('refunded');
  });
});

describe('wallet errors reaching the app (SA-147)', () => {
  it('a declined payment says so without BonsPay internals', async () => {
    await db.doc('products/p1').set({ title: 'Kente', sellerId: 'sellerA', stock: 3 });
    await db.doc('orders/o1').set({
      buyerId: buyer.uid,
      status: 'awaitingPayment',
      items: [{ productId: 'p1', sellerId: 'sellerA', unitPrice: ghs(1000), quantity: 1 }],
      total: ghs(1000),
    });
    setMockBehavior('capture', 'fail');
    await expect(
      call.pay(asUser(buyer, { orderId: 'o1', method: 'payNow' }) as never),
    ).rejects.toMatchObject({ code: 'aborted', message: 'The payment was declined.' });
  });
});

describe('reconcileAll (SA-034)', () => {
  it('records drift and alerts staff', async () => {
    await db.doc('platform_balances/GHS').set({ escrow: 500, payable: 0, commission: 0 });
    await db.doc('_mock_bonspay/balances_GHS').set({ escrow: 0, payable: 0, commission: 0 });
    const diffs = await reconcileAll('system');
    expect(diffs[0]).toMatchObject({ currency: 'GHS', matched: false, delta: { escrow: 500 } });
    const run = (await db.collection('reconciliations').get()).docs[0].data();
    expect(run).toMatchObject({ runBy: 'system', matched: false });
    expect(await adminAlerts()).toEqual([
      expect.objectContaining({ title: 'Platform balances do not match' }),
    ]);
  });

  it('stays quiet when everything matches', async () => {
    await db.doc('platform_balances/GHS').set({ escrow: 0, payable: 0, commission: 0 });
    await db.doc('_mock_bonspay/balances_GHS').set({ escrow: 0, payable: 0, commission: 0 });
    expect((await reconcileAll('system'))[0].matched).toBe(true);
    expect(await adminAlerts()).toEqual([]);
  });
});

describe('reviews (SA-111)', () => {
  const review = (caller: typeof buyer, data: Record<string, unknown>) =>
    call.review(asUser(caller, { orderId: 'o1', productId: 'p1', ...data }) as never);
  const rating = async (path: string) => {
    const d = (await db.doc(path).get()).data()!;
    return [d.ratingCount, d.ratingAverage];
  };

  beforeEach(async () => {
    await db.doc('products/p1').set({ sellerId: 'sellerA', ratingCount: 0, ratingAverage: 0 });
  });

  it('only the buyer of a delivered order line can review', async () => {
    await deliveredOrder('o1', 'sellerA', 1, 'shipped');
    await expectHttpsError(review(buyer, { rating: 5 }), 'failed-precondition');
    await db.doc('orders/o1').update({ status: 'delivered' });
    await expectHttpsError(review(otherBuyer, { rating: 5 }), 'permission-denied');
    await expectHttpsError(review(buyer, { productId: 'nope', rating: 5 }), 'not-found');
    await expectHttpsError(review(buyer, { rating: 6 }), 'invalid-argument');
  });

  it('one review per line; edits and deletes recompute ratings', async () => {
    await deliveredOrder('o1');
    await review(buyer, { rating: 4, comment: 'Lovely' });
    expect(await rating('products/p1')).toEqual([1, 4]);
    expect(await rating('sellers/sellerA')).toEqual([1, 4]);

    const { edited, reviewId } = await review(buyer, { rating: 2 });
    expect(edited).toBe(true);
    expect(await rating('products/p1')).toEqual([1, 2]);

    await expectHttpsError(
      call.deleteReview(asUser(otherBuyer, { reviewId }) as never),
      'permission-denied',
    );
    await call.deleteReview(asUser(buyer, { reviewId }) as never);
    expect(await rating('products/p1')).toEqual([0, 0]);
  });
});

describe('public store profile (SA-141)', () => {
  it('copies only public fields and lists only approved sellers', async () => {
    await syncStore('s1', {
      storeName: 'Ama Crafts', market: 'GH', ownerName: 'Ama Mensah', phone: '+233200000000',
      qrWalletId: 'w1', kycStatus: 'verified', approvalStatus: 'approved', ratingAverage: 4.5,
      ratingCount: 2,
    });
    const store = (await db.doc('stores/s1').get()).data()!;
    expect(store).toMatchObject({ storeName: 'Ama Crafts', market: 'GH', listed: true, ratingCount: 2 });
    expect(store).not.toHaveProperty('ownerName');
    expect(store).not.toHaveProperty('phone');
    expect(store).not.toHaveProperty('qrWalletId');

    await syncStore('s1', { storeName: 'Ama Crafts', approvalStatus: 'suspended' });
    expect((await db.doc('stores/s1').get()).data()!.listed).toBe(false);
    await syncStore('s1', null);
    expect((await db.doc('stores/s1').get()).exists).toBe(false);
  });
});

describe('removeProduct (SA-044)', () => {
  it('deletes a never-ordered product and archives an ordered one', async () => {
    await db.doc('products/fresh').set({ sellerId: seller.uid, isActive: true });
    await db.doc('products/sold').set({ sellerId: seller.uid, isActive: true, hasOrders: true });

    expect((await call.remove(asUser(seller, { productId: 'fresh' }) as never)).archived).toBe(false);
    expect((await db.doc('products/fresh').get()).exists).toBe(false);

    expect((await call.remove(asUser(seller, { productId: 'sold' }) as never)).archived).toBe(true);
    expect((await db.doc('products/sold').get()).data()).toMatchObject({ archived: true, isActive: false });
  });

  it('only the owner or an admin can remove it', async () => {
    await db.doc('products/p').set({ sellerId: 'someoneElse', isActive: true });
    await expectHttpsError(call.remove(asUser(seller, { productId: 'p' }) as never), 'permission-denied');
    await call.remove(asUser(admin, { productId: 'p' }) as never);
  });
});
