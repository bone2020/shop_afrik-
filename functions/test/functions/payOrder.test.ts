import { asUser, buyer, clearFirestore, expectHttpsError, fft, otherBuyer } from '../helpers';
import { db } from '../../src/lib/admin';
import { payOrder } from '../../src/orders/payOrder';

const pay = fft.wrap(payOrder);

async function seedOrder() {
  await db.doc('products/p1').set({ title: 'Kente', stock: 5, sellerId: 'seller1' });
  await db.doc('orders/o1').set({
    buyerId: buyer.uid,
    status: 'awaitingPayment',
    items: [{ productId: 'p1', quantity: 2 }],
    total: { minorUnits: 10000, currency: 'GHS' },
  });
}

beforeEach(async () => {
  await clearFirestore();
  await seedOrder();
});

describe('payOrder', () => {
  it('requires sign-in', async () => {
    await expectHttpsError(
      pay({ data: { orderId: 'o1', method: 'payNow' } } as never),
      'unauthenticated',
    );
  });

  it('rejects another buyer', async () => {
    await expectHttpsError(
      pay(asUser(otherBuyer, { orderId: 'o1', method: 'payNow' }) as never),
      'permission-denied',
    );
  });

  it('never fakes success while payments are not connected', async () => {
    await expectHttpsError(
      pay(asUser(buyer, { orderId: 'o1', method: 'payNow' }) as never),
      'unavailable',
    );
    const order = (await db.doc('orders/o1').get()).data()!;
    const product = (await db.doc('products/p1').get()).data()!;
    expect(order.status).toBe('awaitingPayment');
    expect(product.stock).toBe(5);
    expect((await db.collection('platform_ledger').get()).empty).toBe(true);
  });
});
