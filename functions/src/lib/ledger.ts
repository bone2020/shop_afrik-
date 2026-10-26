import { db } from './admin';
import { Collections } from '../types';

export type Bucket = 'escrow' | 'payable' | 'commission';

export type LedgerMoveType =
  | 'escrow_hold'
  | 'settle'
  | 'payout'
  | 'refund_release';

export interface LedgerMoveInput {
  /** Deterministic id; recording the same move twice is a no-op. */
  moveId: string;
  type: LedgerMoveType;
  currency: string;
  /** Signed change per bucket, in minor units of [currency]. */
  deltas: Partial<Record<Bucket, number>>;
  ref: Record<string, string>;
  externalTxnId?: string | null;
}

/**
 * Records a platform-account move in Shop Afrik's own mirror: one
 * `platform_ledger` entry plus the matching change to the currency's
 * `platform_balances` row, in one transaction. Idempotent on [moveId], so a
 * retried function never double-counts. Currencies are never blended: each
 * currency has its own balances document.
 */
export async function recordLedgerMove(input: LedgerMoveInput): Promise<void> {
  const moveRef = db.collection(Collections.platformLedger).doc(input.moveId);
  const balanceRef = db
    .collection(Collections.platformBalances)
    .doc(input.currency);

  await db.runTransaction(async (tx) => {
    const [moveSnap, balanceSnap] = await Promise.all([
      tx.get(moveRef),
      tx.get(balanceRef),
    ]);
    if (moveSnap.exists) return; // already recorded

    const now = new Date().toISOString();
    const current = balanceSnap.data() ?? {};
    const next: Record<string, unknown> = { currency: input.currency };
    for (const bucket of ['escrow', 'payable', 'commission'] as Bucket[]) {
      next[bucket] =
        ((current[bucket] as number | undefined) ?? 0) +
        (input.deltas[bucket] ?? 0);
    }
    next.updatedAt = now;

    tx.set(moveRef, {
      type: input.type,
      currency: input.currency,
      deltas: input.deltas,
      ref: input.ref,
      externalTxnId: input.externalTxnId ?? null,
      createdAt: now,
    });
    tx.set(balanceRef, next);
  });
}
