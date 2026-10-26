import { Timestamp } from 'firebase-admin/firestore';
import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, seller } from '../helpers';
import { db } from '../../src/lib/admin';
import { resetMockBehavior } from '../../src/lib/mockBonsPay';
import { suspendSeller } from '../../src/sellers/suspendSeller';
import { settleDue } from '../../src/settlement/settleDueOrders';

const suspend = fft.wrap(suspendSeller);
const DAY = 24 * 60 * 60 * 1000;
const ghs = (minorUnits: number) => ({ minorUnits, currency: 'GHS' });

const call = (caller: typeof admin, data: Record<string, unknown>) =>
  suspend(asUser(caller, data) as never);

async function seed() {
  await db.doc('sellers/sellerA').set({ approvalStatus: 'approved', qrWalletId: 'wA' });
  await db.doc('sellers/sellerB').set({ approvalStatus: 'approved', qrWalletId: 'wB' });
  await db.doc('products/live').set({ sellerId: 'sellerA', isActive: true, approvalStatus: 'approved' });
  await db.doc('products/paused').set({ sellerId: 'sellerA', isActive: false, approvalStatus: 'approved' });
  await db.doc('products/other').set({ sellerId: 'sellerB', isActive: true, approvalStatus: 'approved' });
}

beforeAll(() => { process.env.QR_WALLET_MODE = 'mock'; });
afterAll(() => { delete process.env.QR_WALLET_MODE; });
beforeEach(async () => {
  resetMockBehavior();
  await clearFirestore();
  await seed();
});

const active = async (id: string) => (await db.doc(`products/${id}`).get()).data()!.isActive;

describe('suspendSeller (SA-063)', () => {
  it('hides the seller\'s products and reinstating brings back only those', async () => {
    await call(admin, { sellerId: 'sellerA', suspend: true, reason: 'Counterfeit goods' });
    expect((await db.doc('sellers/sellerA').get()).data()).toMatchObject({
      approvalStatus: 'suspended',
      suspensionReason: 'Counterfeit goods',
    });
    expect(await active('live')).toBe(false);
    expect(await active('other')).toBe(true);

    await call(admin, { sellerId: 'sellerA', suspend: false });
    expect((await db.doc('sellers/sellerA').get()).data()!.approvalStatus).toBe('approved');
    expect(await active('live')).toBe(true);
    // A product the seller had paused themselves stays paused.
    expect(await active('paused')).toBe(false);

    const audit = await db.collection('admin_audit').where('targetId', '==', 'sellerA').get();
    expect(audit.docs.map((d) => d.data().action).sort())
      .toEqual(['seller.reinstated', 'seller.suspended']);
  });

  it('is admin-only and needs a reason', async () => {
    await expectHttpsError(
      call(seller, { sellerId: 'sellerA', suspend: true, reason: 'x' }),
      'permission-denied',
    );
    await expectHttpsError(call(admin, { sellerId: 'sellerA', suspend: true }), 'invalid-argument');
  });

  it('refuses to suspend a seller who is not approved, or reinstate one not suspended', async () => {
    await db.doc('sellers/sellerA').update({ approvalStatus: 'pending' });
    await expectHttpsError(
      call(admin, { sellerId: 'sellerA', suspend: true, reason: 'x' }),
      'failed-precondition',
    );
    await expectHttpsError(call(admin, { sellerId: 'sellerB', suspend: false }), 'failed-precondition');
  });

  it('holds a suspended seller\'s payout, pays the others, and pays it after reinstatement', async () => {
    await db.doc('_mock_bonspay/balances_GHS').set({ escrow: 100000, payable: 0, commission: 0 });
    await db.doc('orders/o1').set({
      buyerId: buyer.uid,
      status: 'delivered',
      sellerIds: ['sellerA', 'sellerB'],
      items: [
        { productId: 'live', sellerId: 'sellerA', unitPrice: ghs(5000), quantity: 1, refundedQuantity: 0 },
        { productId: 'other', sellerId: 'sellerB', unitPrice: ghs(2000), quantity: 1, refundedQuantity: 0 },
      ],
      settlementStatus: 'scheduled',
      settlementDueAt: Timestamp.fromMillis(Date.now() - DAY),
    });
    await call(admin, { sellerId: 'sellerA', suspend: true, reason: 'Under review' });

    await settleDue(Timestamp.now());
    const settlement = async (sellerId: string) =>
      (await db.doc(`settlements/o1_${sellerId}`).get()).data()!;
    expect(await settlement('sellerA')).toMatchObject({ status: 'onHold', holdReason: 'sellerSuspended' });
    expect((await settlement('sellerB')).status).toBe('settled');
    expect((await db.doc('orders/o1').get()).data()!.settlementStatus).toBe('scheduled');

    // A second run while still suspended changes nothing.
    await settleDue(Timestamp.now());
    expect((await settlement('sellerA')).status).toBe('onHold');

    await call(admin, { sellerId: 'sellerA', suspend: false });
    await settleDue(Timestamp.now());
    const paid = await settlement('sellerA');
    expect(paid.status).toBe('settled');
    expect(paid.holdReason).toBeUndefined();
    expect((await db.doc('orders/o1').get()).data()!.settlementStatus).toBe('settled');
  });
});
