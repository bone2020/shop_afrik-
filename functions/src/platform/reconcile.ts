import { onCall } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole } from '../lib/guards';
import { writeAudit } from '../lib/audit';
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
 * authoritative QR Wallet platform account. Admin-only. For each currency it
 * reads the account balances and compares them to the local mirror; any
 * non-zero delta is a discrepancy to investigate. Results are written to the
 * `reconciliations` collection and returned. Currencies are never blended.
 */
export const reconcilePlatformAccount = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');

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
        error: (e as Error).message,
      });
    }
  }

  await db.collection(Collections.reconciliations).add({
    runBy: adminId,
    diffs,
    createdAt: FieldValue.serverTimestamp(),
  });
  await writeAudit({
    actorId: adminId,
    action: 'platform.reconciled',
    metadata: { currencies: diffs.map((d) => d.currency) },
  });

  return { diffs };
});
