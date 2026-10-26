import { Timestamp } from 'firebase-admin/firestore';
import { admin, asUser, buyer, clearFirestore, expectHttpsError, fft, seller, supervisor } from '../helpers';
import { auth, db } from '../../src/lib/admin';
import { resetMockBehavior } from '../../src/lib/mockBonsPay';
import { findUser } from '../../src/admin/findUser';
import { updatePlatformSettings } from '../../src/admin/updatePlatformSettings';
import { settleDue } from '../../src/settlement/settleDueOrders';
import { DEFAULT_SETTINGS } from '../../src/config';

const find = fft.wrap(findUser);
const update = fft.wrap(updatePlatformSettings);
const patch = (caller: typeof admin, p: Record<string, unknown>) =>
  update(asUser(caller, { patch: p }) as never);
const settings = async () => (await db.doc('settings/platform').get()).data() ?? {};

beforeAll(() => { process.env.QR_WALLET_MODE = 'mock'; });
afterAll(() => { delete process.env.QR_WALLET_MODE; });
beforeEach(async () => {
  resetMockBehavior();
  await clearFirestore();
});

describe('findUser (SA-132)', () => {
  it('finds an account by email, phone or uid and reports its role', async () => {
    const tag = Math.random().toString(36).slice(2);
    const phone = `+23320${Math.floor(1000000 + Math.random() * 8999999)}`;
    const u = await auth.createUser({ email: `find${tag}@test.dev`, phoneNumber: phone });
    await auth.setCustomUserClaims(u.uid, { role: 'delivery' });

    for (const query of [`FIND${tag}@test.dev`, phone, u.uid]) {
      const { user } = await find(asUser(admin, { query }) as never);
      expect(user).toMatchObject({ uid: u.uid, role: 'delivery', phone });
    }
    expect((await find(asUser(admin, { query: 'nobody@test.dev' }) as never)).user).toBeNull();
  });

  it('is admin-only', async () => {
    for (const caller of [buyer, seller]) {
      await expectHttpsError(find(asUser(caller, { query: 'x@test.dev' }) as never), 'permission-denied');
    }
  });
});

describe('updatePlatformSettings (SA-133)', () => {
  it('only a supervisor can change settings', async () => {
    await expectHttpsError(patch(admin, { commissionRate: 0.1 }), 'permission-denied');
    await expectHttpsError(patch(seller, { commissionRate: 0.1 }), 'permission-denied');
  });

  it('rejects invalid values and leaves settings unchanged', async () => {
    const bad: Record<string, unknown>[] = [
      { commissionRate: 0.9 },
      { commissionRate: -0.1 },
      { paymentFeeRate: 0.5 },
      { refundWindowDays: 0 },
      { settlementDelayDays: 7 }, // not longer than the 7-day window
      { refundWindowDays: 10 }, // now longer than the 8-day delay
      { refundTiersByCurrency: { GHS: { tier1: 500, tier2: 100 } } },
      { markets: { GH: { ...DEFAULT_SETTINGS.markets.GH, enabled: false } } }, // NG removed
      { markets: { ...DEFAULT_SETTINGS.markets, GH: { ...DEFAULT_SETTINGS.markets.GH, currency: 'USD' } } },
      {
        markets: {
          GH: { ...DEFAULT_SETTINGS.markets.GH, enabled: false },
          NG: { ...DEFAULT_SETTINGS.markets.NG, enabled: false },
        },
      },
      {
        markets: {
          ...DEFAULT_SETTINGS.markets,
          KE: { countryCode: 'KE', currency: 'KES', dialCode: '+254', label: 'Kenya', enabled: true },
        },
      }, // no KES refund tiers
    ];
    for (const p of bad) await expectHttpsError(patch(supervisor, p), 'invalid-argument');
    expect(await settings()).toEqual({});
  });

  it('adds a market once its currency has refund tiers', async () => {
    await patch(supervisor, {
      refundTiersByCurrency: { ...DEFAULT_SETTINGS.refundTiersByCurrency, KES: { tier1: 5000, tier2: 30000 } },
      markets: {
        ...DEFAULT_SETTINGS.markets,
        KE: { countryCode: 'KE', currency: 'KES', dialCode: '+254', label: 'Kenya', enabled: true },
      },
    });
    expect((await settings()).markets.KE).toMatchObject({ currency: 'KES', enabled: true });
  });

  it('audits the change and the next settlement uses the new commission', async () => {
    const { changed } = await patch(supervisor, { commissionRate: 0.1, paymentFeeRate: 0.015 });
    // paymentFeeRate was already 1.5%, so only commission is recorded.
    expect(changed).toEqual(['commissionRate']);

    const audit = await db.collection('admin_audit').where('action', '==', 'settings.updated').get();
    expect(audit.size).toBe(1);
    expect(audit.docs[0].data()).toMatchObject({
      actorId: supervisor.uid,
      metadata: { changed: ['commissionRate'], before: { commissionRate: 0.15 }, after: { commissionRate: 0.1 } },
    });

    await db.doc('_mock_bonspay/balances_GHS').set({ escrow: 10000, payable: 0, commission: 0 });
    await db.doc('sellers/sellerA').set({ approvalStatus: 'approved' });
    await db.doc('orders/o1').set({
      buyerId: buyer.uid,
      status: 'delivered',
      sellerIds: ['sellerA'],
      items: [{ productId: 'p', sellerId: 'sellerA', unitPrice: { minorUnits: 10000, currency: 'GHS' }, quantity: 1, refundedQuantity: 0 }],
      settlementStatus: 'scheduled',
      settlementDueAt: Timestamp.fromMillis(Date.now() - 1000),
    });
    await settleDue(Timestamp.now());
    expect((await db.doc('settlements/o1_sellerA').get()).data()).toMatchObject({
      commissionRate: 0.1,
      commission: { minorUnits: 1000, currency: 'GHS' },
      net: { minorUnits: 9000, currency: 'GHS' },
    });
  });
});
