import { HttpsError } from 'firebase-functions/v2/https';
import { Transaction } from 'firebase-admin/firestore';
import { db } from './admin';
import { Money } from '../types';
import type {
  BuyerMoveInput,
  CaptureHoldInput,
  PayoutInput,
  PlatformBalances,
  QrWalletBackend,
  SettleInput,
} from './qrWallet';

// Fake BonsPay platform account (SA-023). It keeps its own escrow / payable /
// commission buckets per currency and its holds in Firestore under
// `_mock_bonspay`, so it behaves the same across function instances in the
// emulator and in kartafrik-staging. Like the real API it is idempotent: a
// repeated idempotency key returns the original transaction id and moves no
// money a second time.
//
// Each operation can be told how to respond, to exercise failure handling:
//   ok       - apply the move and return a transaction id (default)
//   fail     - decline without moving money
//   timeout  - apply the move, then lose the response (the caller sees a
//              timeout but the money did move; recovery must reconcile)
// Set behaviours in tests with setMockBehavior(), or in staging by writing
// `_mock_bonspay/config` { behavior: { capture: 'fail', ... } }.

export type MockOperation =
  | 'capture'
  | 'hold'
  | 'captureHold'
  | 'releaseHold'
  | 'refundFromEscrow'
  | 'settleToPayable'
  | 'payoutToSeller'
  | 'getBalances';

export type MockBehavior = 'ok' | 'fail' | 'timeout';

const COLLECTION = '_mock_bonspay';
const overrides = new Map<MockOperation, MockBehavior>();

/** Sets how [op] responds until reset. Test helper. */
export function setMockBehavior(op: MockOperation, behavior: MockBehavior): void {
  overrides.set(op, behavior);
}

/** Restores every operation to `ok`. Test helper. */
export function resetMockBehavior(): void {
  overrides.clear();
}

async function behaviorFor(op: MockOperation): Promise<MockBehavior> {
  const local = overrides.get(op);
  if (local) return local;
  const config = await db.collection(COLLECTION).doc('config').get();
  return (config.data()?.behavior?.[op] as MockBehavior | undefined) ?? 'ok';
}

type Buckets = { escrow: number; payable: number; commission: number };
type Apply = (
  tx: Transaction,
  bucketsFor: (currency: string) => Promise<Buckets>,
) => Promise<void>;

/**
 * Runs one money move: declines or applies it per the configured behaviour,
 * at most once per idempotency key, and returns the transaction id.
 */
async function move(
  op: MockOperation,
  idempotencyKey: string,
  apply: Apply,
): Promise<string> {
  const behavior = await behaviorFor(op);
  if (behavior === 'fail') {
    throw new HttpsError('aborted', `BonsPay declined ${op}.`);
  }

  const txnRef = db.collection(COLLECTION).doc(`txn_${idempotencyKey}`);
  const txnId = await db.runTransaction(async (tx) => {
    const existing = await tx.get(txnRef);
    if (existing.exists) return existing.data()!.txnId as string;

    // Reads first (Firestore transactions), then writes.
    const touched = new Map<string, Buckets>();
    const bucketsFor = async (currency: string): Promise<Buckets> => {
      if (!touched.has(currency)) {
        const snap = await tx.get(db.collection(COLLECTION).doc(`balances_${currency}`));
        const d = snap.data() ?? {};
        touched.set(currency, {
          escrow: d.escrow ?? 0,
          payable: d.payable ?? 0,
          commission: d.commission ?? 0,
        });
      }
      return touched.get(currency)!;
    };
    await apply(tx, bucketsFor);

    for (const [currency, b] of touched) {
      tx.set(db.collection(COLLECTION).doc(`balances_${currency}`), b);
    }
    const id = `mock_${op}_${idempotencyKey}`;
    tx.set(txnRef, { txnId: id, op, createdAt: new Date().toISOString() });
    return id;
  });

  if (behavior === 'timeout') {
    throw new HttpsError('deadline-exceeded', `BonsPay ${op} timed out.`);
  }
  return txnId;
}

function holdRef(orderId: string) {
  return db.collection(COLLECTION).doc(`hold_${orderId}`);
}

function requireFunds(available: number, needed: Money, bucket: string): void {
  if (available < needed.minorUnits) {
    throw new HttpsError(
      'failed-precondition',
      `BonsPay ${bucket} has insufficient ${needed.currency}.`,
    );
  }
}

export const mockBonsPay: QrWalletBackend = {
  capture: (input: BuyerMoveInput) =>
    move('capture', input.idempotencyKey, async (_tx, bucketsFor) => {
      (await bucketsFor(input.amount.currency)).escrow += input.amount.minorUnits;
    }),

  hold: (input: BuyerMoveInput) =>
    move('hold', input.idempotencyKey, async (tx) => {
      tx.set(holdRef(input.orderId), { amount: input.amount, status: 'held' });
    }),

  captureHold: (input: CaptureHoldInput) =>
    move('captureHold', input.idempotencyKey, async (tx, bucketsFor) => {
      const hold = await tx.get(holdRef(input.orderId));
      if (hold.data()?.status !== 'held') {
        throw new HttpsError('failed-precondition', 'No active hold to capture.');
      }
      const b = await bucketsFor(input.amount.currency);
      b.escrow += input.amount.minorUnits;
      tx.update(holdRef(input.orderId), { status: 'captured' });
    }),

  releaseHold: (input: BuyerMoveInput) =>
    move('releaseHold', input.idempotencyKey, async (tx) => {
      const hold = await tx.get(holdRef(input.orderId));
      if (hold.data()?.status !== 'held') {
        throw new HttpsError('failed-precondition', 'No active hold to release.');
      }
      tx.update(holdRef(input.orderId), { status: 'released' });
    }),

  refundFromEscrow: (input: BuyerMoveInput) =>
    move('refundFromEscrow', input.idempotencyKey, async (_tx, bucketsFor) => {
      const b = await bucketsFor(input.amount.currency);
      requireFunds(b.escrow, input.amount, 'escrow');
      b.escrow -= input.amount.minorUnits;
    }),

  settleToPayable: (input: SettleInput) =>
    move('settleToPayable', input.idempotencyKey, async (_tx, bucketsFor) => {
      if (input.gross.currency !== input.commission.currency) {
        throw new HttpsError('invalid-argument', 'Currency mismatch.');
      }
      const b = await bucketsFor(input.gross.currency);
      requireFunds(b.escrow, input.gross, 'escrow');
      b.escrow -= input.gross.minorUnits;
      b.payable += input.gross.minorUnits - input.commission.minorUnits;
      b.commission += input.commission.minorUnits;
    }),

  payoutToSeller: (input: PayoutInput) =>
    move('payoutToSeller', input.idempotencyKey, async (_tx, bucketsFor) => {
      const b = await bucketsFor(input.amount.currency);
      requireFunds(b.payable, input.amount, 'payable');
      b.payable -= input.amount.minorUnits;
    }),

  getBalances: async (currency: string): Promise<PlatformBalances> => {
    if ((await behaviorFor('getBalances')) !== 'ok') {
      throw new HttpsError('unavailable', 'BonsPay balances unavailable.');
    }
    const d = (await db.collection(COLLECTION).doc(`balances_${currency}`).get()).data() ?? {};
    const m = (minorUnits: number): Money => ({ minorUnits, currency });
    return {
      escrow: m(d.escrow ?? 0),
      payable: m(d.payable ?? 0),
      commission: m(d.commission ?? 0),
    };
  },
};
