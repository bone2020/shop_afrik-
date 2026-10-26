import { Timestamp } from 'firebase-admin/firestore';
import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, otherBuyer } from '../helpers';
import { db } from '../../src/lib/admin';
import { requestRefund } from '../../src/refunds/requestRefund';
import { decideRefund } from '../../src/refunds/decideRefund';
import { settleDue } from '../../src/settlement/settleDueOrders';

const request = fft.wrap(requestRefund);
const decide = fft.wrap(decideRefund);

const DAY = 24 * 60 * 60 * 1000;
const ghs = (minorUnits: number) => ({ minorUnits, currency: 'GHS' });

async function seedDeliveredOrder(daysAgo: number, items?: unknown[]) {
  await db.doc('orders/o1').set({
    buyerId: buyer.uid,
    status: 'delivered',
    sellerIds: ['sellerA', 'sellerB'],
    items: items ?? [
      { productId: 'p1', sellerId: 'sellerA', title: 'Kente', unitPrice: ghs(5000), quantity: 2, refundedQuantity: 0 },
      { productId: 'p2', sellerId: 'sellerB', title: 'Shea', unitPrice: ghs(1500), quantity: 1, refundedQuantity: 0 },
    ],
    subtotal: ghs(11500),
    deliveryConfirmedAt: Timestamp.fromMillis(Date.now() - daysAgo * DAY),
    settlementStatus: 'scheduled',
    settlementDueAt: Timestamp.fromMillis(Date.now() - (daysAgo - 8) * DAY),
  });
}

const ask = (caller = buyer, data: Record<string, unknown> = {}) =>
  request(asUser(caller, {
    orderId: 'o1',
    lines: [{ productId: 'p1', quantity: 1 }],
    reason: 'Torn on arrival',
    ...data,
  }) as never);

beforeEach(clearFirestore);

describe('requestRefund (SA-050)', () => {
  it('computes the amount server-side and holds settlement (SA-051)', async () => {
    await seedDeliveredOrder(2);
    const { refundId } = await ask(buyer, { amount: ghs(99999999) });

    const refund = (await db.doc(`refund_requests/${refundId}`).get()).data()!;
    expect(refund).toMatchObject({
      buyerId: buyer.uid,
      status: 'requested',
      amount: ghs(5000),
      sellerIds: ['sellerA'],
      tier: 'tier1',
    });
    expect((await db.doc('orders/o1').get()).data()!.settlementStatus).toBe('onHold');
  });

  it('rejects another buyer', async () => {
    await seedDeliveredOrder(2);
    await expectHttpsError(ask(otherBuyer), 'permission-denied');
  });

  it('rejects requests after the refund window', async () => {
    await seedDeliveredOrder(8);
    await expectHttpsError(ask(), 'failed-precondition');
  });

  it('rejects orders that are not delivered yet', async () => {
    await seedDeliveredOrder(2);
    await db.doc('orders/o1').update({ status: 'shipped' });
    await expectHttpsError(ask(), 'failed-precondition');
  });

  it('rejects a duplicate while one is open', async () => {
    await seedDeliveredOrder(2);
    await ask();
    await expectHttpsError(
      ask(buyer, { lines: [{ productId: 'p2', quantity: 1 }] }),
      'already-exists',
    );
  });

  it('rejects more than the remaining quantity', async () => {
    await seedDeliveredOrder(2);
    await expectHttpsError(
      ask(buyer, { lines: [{ productId: 'p1', quantity: 3 }] }),
      'failed-precondition',
    );
  });

  it('rejects items that are not in the order', async () => {
    await seedDeliveredOrder(2);
    await expectHttpsError(
      ask(buyer, { lines: [{ productId: 'nope', quantity: 1 }] }),
      'invalid-argument',
    );
  });

  it('refunds a single-item order only in full', async () => {
    await seedDeliveredOrder(2, [
      { productId: 'p1', sellerId: 'sellerA', title: 'Kente', unitPrice: ghs(5000), quantity: 2, refundedQuantity: 0 },
    ]);
    await expectHttpsError(ask(), 'failed-precondition');
    await ask(buyer, { lines: [{ productId: 'p1', quantity: 2 }] });
  });
});

describe('open refund pauses the seller payout (SA-051)', () => {
  it('requested on day 6, decided on day 9: no payout before the decision', async () => {
    await seedDeliveredOrder(6);
    const { refundId } = await ask();

    // Day 9: the settlement run finds nothing to pay.
    await settleDue(Timestamp.fromMillis(Date.now() + 3 * DAY));
    expect((await db.collection('settlements').get()).empty).toBe(true);
    const attempts = await db
      .collection('admin_audit')
      .where('targetId', '==', 'o1')
      .where('action', 'in', ['settlement.paid', 'settlement.failed'])
      .get();
    expect(attempts.empty).toBe(true);

    // Rejecting the refund resumes settlement for the next run.
    await decide(asUser(admin, { refundId, decision: 'reject' }) as never);
    const order = (await db.doc('orders/o1').get()).data()!;
    expect(order.settlementStatus).toBe('scheduled');
  });
});
