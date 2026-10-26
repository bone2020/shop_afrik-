import { clearFirestore } from '../helpers';
import { db } from '../../src/lib/admin';
import { recordLedgerMove } from '../../src/lib/ledger';

beforeEach(clearFirestore);

describe('recordLedgerMove', () => {
  it('updates the currency balances once per move id', async () => {
    const move = {
      moveId: 'escrow_capture_o1',
      type: 'escrow_hold' as const,
      currency: 'GHS',
      deltas: { escrow: 5000 },
      ref: { orderId: 'o1' },
    };
    await recordLedgerMove(move);
    await recordLedgerMove(move); // retried function: must not double-count

    const bal = (await db.doc('platform_balances/GHS').get()).data()!;
    expect(bal).toMatchObject({ escrow: 5000, payable: 0, commission: 0 });
    const entry = (await db.doc('platform_ledger/escrow_capture_o1').get()).data()!;
    expect(entry).toMatchObject({ type: 'escrow_hold', currency: 'GHS' });
  });

  it('keeps each currency separate and applies settle deltas', async () => {
    await recordLedgerMove({
      moveId: 'a', type: 'escrow_hold', currency: 'GHS',
      deltas: { escrow: 10000 }, ref: {},
    });
    await recordLedgerMove({
      moveId: 'b', type: 'escrow_hold', currency: 'NGN',
      deltas: { escrow: 999 }, ref: {},
    });
    await recordLedgerMove({
      moveId: 'c', type: 'settle', currency: 'GHS',
      deltas: { escrow: -10000, payable: 8500, commission: 1500 }, ref: {},
    });

    const ghs = (await db.doc('platform_balances/GHS').get()).data()!;
    const ngn = (await db.doc('platform_balances/NGN').get()).data()!;
    expect(ghs).toMatchObject({ escrow: 0, payable: 8500, commission: 1500 });
    expect(ngn).toMatchObject({ escrow: 999, payable: 0, commission: 0 });
  });
});
