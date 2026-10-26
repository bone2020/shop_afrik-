import { buyer, clearFirestore, expectHttpsError, fft } from '../helpers';
import { db } from '../../src/lib/admin';
import { createOrder } from '../../src/orders/createOrder';

const call = fft.wrap(createOrder);

function asBuyer(token: Record<string, unknown>) {
  return {
    data: {
      items: [{ productId: 'p1', quantity: 1 }],
      deliveryLocation: {
        recipientName: 'Ama', phone: '+233200000000', addressLine: '1 Oxford St',
        city: 'Accra', market: 'GH',
      },
    },
    auth: { uid: buyer.uid, token: { uid: buyer.uid, ...token } },
  } as never;
}

beforeEach(async () => {
  await clearFirestore();
  await db.doc('products/p1').set({
    title: 'Kente', sellerId: 'seller1', price: { minorUnits: 5000, currency: 'GHS' },
    stock: 5, approvalStatus: 'approved', isActive: true, images: [],
  });
});

describe('createOrder email verification (SA-102)', () => {
  it('rejects an unverified email account', async () => {
    await expectHttpsError(
      call(asBuyer({ email: 'a@test.dev', email_verified: false })),
      'failed-precondition',
    );
    expect((await db.collection('orders').get()).empty).toBe(true);
  });

  it('accepts a verified email account', async () => {
    const res = await call(asBuyer({ email: 'a@test.dev', email_verified: true }));
    expect(res.status).toBe('awaitingDeliveryQuote');
  });

  it('accepts a phone account (no email claim)', async () => {
    const res = await call(asBuyer({ phone_number: '+233200000000' }));
    expect(res.status).toBe('awaitingDeliveryQuote');
  });

  it('marks ordered products so removing them archives instead (SA-044)', async () => {
    await call(asBuyer({ phone_number: '+233200000000' }));
    expect((await db.doc('products/p1').get()).data()!.hasOrders).toBe(true);
  });
});
