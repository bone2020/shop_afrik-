import { Timestamp } from 'firebase-admin/firestore';
import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, seller } from '../helpers';
import { db } from '../../src/lib/admin';
import { resetMockBehavior, setMockBehavior } from '../../src/lib/mockBonsPay';
import { createOrder } from '../../src/orders/createOrder';
import { quoteDelivery } from '../../src/orders/quoteDelivery';
import { payOrder } from '../../src/orders/payOrder';
import { assignCourier } from '../../src/orders/assignCourier';
import { markShipped, submitProofOfDelivery } from '../../src/orders/transitions';
import { requestRefund } from '../../src/refunds/requestRefund';
import { decideRefund } from '../../src/refunds/decideRefund';
import { settleDue } from '../../src/settlement/settleDueOrders';
import { reconcilePlatformAccount } from '../../src/platform/reconcile';

const call = {
  createOrder: fft.wrap(createOrder),
  quote: fft.wrap(quoteDelivery),
  pay: fft.wrap(payOrder),
  assign: fft.wrap(assignCourier),
  ship: fft.wrap(markShipped),
  proof: fft.wrap(submitProofOfDelivery),
  requestRefund: fft.wrap(requestRefund),
  decide: fft.wrap(decideRefund),
  reconcile: fft.wrap(reconcilePlatformAccount),
};
const courier = { uid: 'courier1', role: 'delivery' };
const DAY = 24 * 60 * 60 * 1000;
const ghs = (minorUnits: number) => ({ minorUnits, currency: 'GHS' });

async function seedCatalog() {
  await db.doc('products/p1').set({
    title: 'Kente cloth',
    sellerId: seller.uid,
    price: ghs(5000),
    stock: 5,
    approvalStatus: 'approved',
    isActive: true,
    images: [],
  });
  await db.doc('products/p2').set({
    title: 'Shea butter',
    sellerId: seller.uid,
    price: ghs(2000),
    stock: 10,
    approvalStatus: 'approved',
    isActive: true,
    images: [],
  });
  await db.doc(`sellers/${seller.uid}`).set({ qrWalletId: 'wallet_seller1' });
  await db.doc('staff/courier1').set({ role: 'delivery' });
}

async function placeAndQuote(
  items: Array<{ productId: string; quantity: number }>,
): Promise<string> {
  const { orderId } = await call.createOrder(asUser(buyer, {
    items,
    deliveryLocation: {
      recipientName: 'Ama', phone: '+233200000000', addressLine: '1 Oxford St',
      city: 'Accra', market: 'GH',
    },
  }) as never);
  await call.quote(asUser(admin, { orderId, deliveryFeeMinor: 1000 }) as never);
  return orderId;
}

const order = async (id: string) => (await db.doc(`orders/${id}`).get()).data()!;
const stock = async () => (await db.doc('products/p1').get()).data()!.stock;

beforeAll(() => { process.env.QR_WALLET_MODE = 'mock'; });
afterAll(() => { delete process.env.QR_WALLET_MODE; });
beforeEach(async () => {
  resetMockBehavior();
  await clearFirestore();
  await seedCatalog();
});

describe('order lifecycle against the fake BonsPay (SA-023)', () => {
  it('pay now → ship → deliver → partial refund → settle → reconcile with zero drift', async () => {
    const id = await placeAndQuote([
      { productId: 'p1', quantity: 2 },
      { productId: 'p2', quantity: 1 },
    ]);
    // 2 × 50.00 + 20.00 = 120.00 items, + 1.5% fee (1.80) + 10.00 delivery.
    expect((await order(id)).total).toEqual(ghs(13180));

    await call.pay(asUser(buyer, { orderId: id, method: 'payNow' }) as never);
    expect(await order(id)).toMatchObject({ status: 'confirmed', paymentStatus: 'captured' });
    expect(await stock()).toBe(3);

    await call.assign(asUser(admin, { orderId: id, courierId: courier.uid }) as never);
    await call.ship(asUser(seller, { orderId: id }) as never);
    await call.proof(asUser(courier, { orderId: id, barcode: id }) as never);
    expect((await order(id)).status).toBe('delivered');

    const { refundId } = await call.requestRefund(asUser(buyer, {
      orderId: id, lines: [{ productId: 'p1', quantity: 1 }], reason: 'Wrong colour',
    }) as never);
    await call.decide(asUser(admin, { refundId, decision: 'approve' }) as never);
    const afterRefund = await order(id);
    expect(afterRefund.paymentStatus).toBe('partiallyRefunded');
    expect(afterRefund.items[0].refundedQuantity).toBe(1);
    expect(afterRefund.settlementStatus).toBe('scheduled');

    await settleDue(Timestamp.fromMillis(Date.now() + 9 * DAY));
    const settlement = (await db.doc(`settlements/${id}_${seller.uid}`).get()).data()!;
    // Seller is paid for what was kept: 1 × 50.00 + 20.00 = 70.00 gross,
    // 15% commission.
    expect(settlement).toMatchObject({
      status: 'settled',
      gross: ghs(7000),
      commission: ghs(1050),
      net: ghs(5950),
    });
    expect((await order(id)).status).toBe('completed');

    const { diffs } = await call.reconcile(asUser(admin, {}) as never);
    expect(diffs).toEqual([
      expect.objectContaining({
        currency: 'GHS',
        matched: true,
        // Escrow keeps the payment fee and delivery fee until D-02 / SA-030.
        ledger: { escrow: 1180, payable: 0, commission: 1050 },
      }),
    ]);
  });

  it('a declined payment leaves the order unpaid and stock untouched', async () => {
    const id = await placeAndQuote([{ productId: 'p1', quantity: 2 }]);
    setMockBehavior('capture', 'fail');
    await expectHttpsError(
      call.pay(asUser(buyer, { orderId: id, method: 'payNow' }) as never),
      'aborted',
    );
    expect((await order(id)).status).toBe('awaitingPayment');
    expect(await stock()).toBe(5);
    expect((await db.collection('platform_ledger').get()).empty).toBe(true);
  });

  it('retrying a payment never charges twice', async () => {
    const id = await placeAndQuote([{ productId: 'p1', quantity: 1 }]);
    await call.pay(asUser(buyer, { orderId: id, method: 'payNow' }) as never);
    await expectHttpsError(
      call.pay(asUser(buyer, { orderId: id, method: 'payNow' }) as never),
      'failed-precondition',
    );
    const { diffs } = await call.reconcile(asUser(admin, {}) as never);
    expect(diffs[0]).toMatchObject({ matched: true, ledger: { escrow: 6075 } });
  });

  it('reconciliation flags money that moved when the response was lost', async () => {
    const id = await placeAndQuote([{ productId: 'p1', quantity: 1 }]);
    setMockBehavior('capture', 'timeout');
    await expectHttpsError(
      call.pay(asUser(buyer, { orderId: id, method: 'payNow' }) as never),
      'deadline-exceeded',
    );
    // BonsPay holds the buyer's money but Shop Afrik did not record it: the
    // drift is detected. Automatic recovery is SA-029.
    const { diffs } = await call.reconcile(asUser(admin, {}) as never);
    expect(diffs).toEqual([]); // no ledger row yet for GHS
    await db.doc('platform_balances/GHS').set({ escrow: 0, payable: 0, commission: 0 });
    const second = await call.reconcile(asUser(admin, {}) as never);
    expect(second.diffs[0]).toMatchObject({
      matched: false,
      delta: { escrow: -6075, payable: 0, commission: 0 },
    });
  });
});
