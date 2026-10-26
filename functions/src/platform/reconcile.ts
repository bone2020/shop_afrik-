import { onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { alertAdmins } from '../lib/notify';
import * as qrWallet from '../lib/qrWallet';
import { Collections } from '../types';

interface BucketDiff {
  currency: string;
  ledger: { escrow: number; payable: number; commission: number };
  account?: { escrow: number; payable: number; commission: number };
  delta?: { escrow: number; payable: number; commission: number };
  matched: boolean;
  error?: string;
}

/**
 * Reconciles Shop Afrik's own per-currency bucket ledger against the
 * authoritative QR Wallet platform account. For each currency it reads the
 * account balances and compares them to the local mirror; any non-zero delta
 * is a discrepancy to investigate. Results are written to `reconciliations`.
 * Currencies are never blended. Runs daily and on demand from the admin
 * console; any drift or failed read alerts staff (SA-034, SA-136).
 */
export const reconcilePlatformAccount = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  return { diffs: await reconcileAll(adminId) };
});

export const reconcilePlatformAccountDaily = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'Africa/Accra' },
  async () => {
    await reconcileAll('system');
  },
);

/** One reconciliation run; exported for tests. */
export async function reconcileAll(runBy: string): Promise<BucketDiff[]> {
  const balancesSnap = await db.collection(Collections.platformBalances).get();
  const diffs: BucketDiff[] = [];

  for (const doc of balancesSnap.docs) {
    const currency = doc.id;
    const d = doc.data();
    const ledger = {
      escrow: (d.escrow as number) ?? 0,
      payable: (d.payable as number) ?? 0,
      commission: (d.commission as number) ?? 0,
    };

    try {
      const account = await qrWallet.getBalances(currency);
      const acc = {
        escrow: account.escrow.minorUnits,
        payable: account.payable.minorUnits,
        commission: account.commission.minorUnits,
      };
      const delta = {
        escrow: ledger.escrow - acc.escrow,
        payable: ledger.payable - acc.payable,
        commission: ledger.commission - acc.commission,
      };
      const matched =
        delta.escrow === 0 && delta.payable === 0 && delta.commission === 0;
      diffs.push({ currency, ledger, account: acc, delta, matched });
    } catch (e) {
      diffs.push({
        currency,
        ledger,
        matched: false,
        error: qrWallet.failureDetail(e),
      });
    }
  }

  const mismatched = diffs.filter((d) => !d.matched).map((d) => d.currency);
  await db.collection(Collections.reconciliations).add({
    runBy,
    diffs,
    matched: mismatched.length === 0,
    createdAt: FieldValue.serverTimestamp(),
  });
  await writeAudit({
    actorId: runBy,
    action: mismatched.length ? 'platform.reconcile.drift' : 'platform.reconciled',
    metadata: { currencies: diffs.map((d) => d.currency), mismatched },
  });
  if (mismatched.length) {
    await alertAdmins({
      title: 'Platform balances do not match',
      body: `Reconciliation found a difference in ${mismatched.join(', ')}. Check the Balances tab.`,
      type: 'money_alert',
      deepLink: '/admin',
    });
  }
  return diffs;
}
