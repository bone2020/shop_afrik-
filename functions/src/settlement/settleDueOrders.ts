import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { writeAudit } from '../lib/audit';
import { alertAdmins, notify } from '../lib/notify';
import { commissionFor, loadSettings } from '../config';
import { formatMoney } from '../lib/currency';
import { recordLedgerMove } from '../lib/ledger';
import * as qrWallet from '../lib/qrWallet';
import { Collections, Money, OrderItem, applyRate, money } from '../types';

/**
 * Day-8 auto-settlement (plan §6). Runs daily and pays sellers their share of
 * each delivered order whose refund window has closed.
 *
 * Selection: orders with settlementStatus == 'scheduled' and a due date in the
 * past. Orders with an open refund are 'onHold'/'reversed' and are skipped by
 * this query. Settlement docs use a deterministic id (`order_seller`) so a
 * re-run never double-pays.
 */
export const settleDueOrders = onSchedule(
  // An explicit zone so the run time never depends on the platform default
  // (SA-003). Ghana is UTC+0 all year.
  { schedule: 'every day 02:00', timeZone: 'Africa/Accra', timeoutSeconds: 540 },
  async () => {
    await settleDue(Timestamp.now());
  },
);

/** Orders read per query page; every page is processed in one run (SA-004). */
export const SETTLEMENT_PAGE_SIZE = 200;

/**
 * One settlement run as of [now]; exported for tests. Pages through every due
 * order with a cursor, so held or failed orders that stay `scheduled` never
 * block the ones after them. Returns how many orders were paid in full.
 */
export async function settleDue(
  now: Timestamp,
  pageSize = SETTLEMENT_PAGE_SIZE,
): Promise<number> {
  const settings = await loadSettings();
  let paid = 0;
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let query = db
      .collection(Collections.orders)
      .where('settlementStatus', '==', 'scheduled')
      .where('settlementDueAt', '<=', now)
      .orderBy('settlementDueAt')
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const queued of page.docs) {
      if (await settleOrder(queued, settings)) paid++;
    }
    if (page.docs.length < pageSize) return paid;
    cursor = page.docs[page.docs.length - 1];
  }
}

/** Settles one order; true when every seller on it was paid. */
async function settleOrder(
  queued: FirebaseFirestore.QueryDocumentSnapshot,
  settings: Awaited<ReturnType<typeof loadSettings>>,
): Promise<boolean> {
  // Re-read: a refund opened since the query puts settlement on hold, and
  // a held order must never be paid out (SA-051).
  const orderDoc = await queued.ref.get();
  const order = orderDoc.data();
  if (!order || order.settlementStatus !== 'scheduled') return false;
  const items = (order.items ?? []) as OrderItem[];

  // Sum each seller's gross share of the subtotal.
  const grossBySeller = new Map<string, Money>();
  for (const item of items) {
    const remaining = item.quantity - (item.refundedQuantity ?? 0);
    if (remaining <= 0) continue;
    const line = money(
      item.unitPrice.minorUnits * remaining,
      item.unitPrice.currency,
    );
    const prev = grossBySeller.get(item.sellerId);
    grossBySeller.set(
      item.sellerId,
      prev
        ? money(prev.minorUnits + line.minorUnits, line.currency)
        : line,
    );
  }

  try {
    // A suspended seller's share is held until reinstated (SA-063); the
    // other sellers on the order are still paid, and the order stays
    // scheduled so the held share is retried on each run.
    let held = false;
    for (const [sellerId, gross] of grossBySeller) {
      const rate = commissionFor(settings, null);
      const commission = applyRate(gross, rate);
      const net = money(
        gross.minorUnits - commission.minorUnits,
        gross.currency,
      );

      const settlementId = `${orderDoc.id}_${sellerId}`;
      const settlementRef = db
        .collection(Collections.settlements)
        .doc(settlementId);

      // Skip if already settled (idempotent re-run).
      const existing = await settlementRef.get();
      if (existing.exists && existing.data()!.status === 'settled') continue;

      const sellerSnap = await db
        .collection(Collections.sellers)
        .doc(sellerId)
        .get();
      if (sellerSnap.data()?.approvalStatus === 'suspended') {
        held = true;
        if (existing.data()?.status !== 'onHold') {
          await settlementRef.set({
            orderId: orderDoc.id,
            sellerId,
            gross,
            commissionRate: rate,
            commission,
            net,
            status: 'onHold',
            holdReason: 'sellerSuspended',
            dueAt: order.settlementDueAt ?? null,
            createdAt: FieldValue.serverTimestamp(),
          });
          await writeAudit({
            actorId: 'system',
            action: 'settlement.held',
            targetType: 'order',
            targetId: orderDoc.id,
            metadata: { sellerId, reason: 'sellerSuspended' },
          });
        }
        continue;
      }
      const sellerWalletId =
        (sellerSnap.data()?.qrWalletId as string) ?? sellerId;

      // Move 1: settle the order's escrow into the seller's payable bucket
      // and Shop Afrik's commission bucket. escrow -gross -> payable +net,
      // commission +commission.
      const settleMoveId = `settle_${settlementId}`;
      await qrWallet.settleToPayable({
        orderId: orderDoc.id,
        sellerId,
        gross,
        commission,
        idempotencyKey: settleMoveId,
      });
      await recordLedgerMove({
        moveId: settleMoveId,
        type: 'settle',
        currency: gross.currency,
        deltas: {
          escrow: -gross.minorUnits,
          payable: net.minorUnits,
          commission: commission.minorUnits,
        },
        ref: { orderId: orderDoc.id, sellerId, settlementId },
      });

      // Move 2: pay the seller's payable out to their QR Wallet.
      // payable -net -> seller wallet.
      const payoutMoveId = `payout_${settlementId}`;
      const payoutId = await qrWallet.payoutToSeller({
        settlementId,
        sellerWalletId,
        amount: net,
        idempotencyKey: payoutMoveId,
      });
      await recordLedgerMove({
        moveId: payoutMoveId,
        type: 'payout',
        currency: net.currency,
        deltas: { payable: -net.minorUnits },
        ref: { orderId: orderDoc.id, sellerId, settlementId },
        externalTxnId: payoutId,
      });

      await settlementRef.set({
        orderId: orderDoc.id,
        sellerId,
        gross,
        commissionRate: rate,
        commission,
        net,
        status: 'settled',
        qrWalletPayoutId: payoutId,
        dueAt: order.settlementDueAt ?? null,
        settledAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });

      await notify({
        recipientId: sellerId,
        audience: 'seller',
        title: 'Payout sent',
        body: `${formatMoney(net)} settled to your wallet.`,
        type: 'settlement',
        deepLink: '/seller',
      });
    }

    if (held) return false;
    await orderDoc.ref.update({
      settlementStatus: 'settled',
      status: 'completed',
      updatedAt: FieldValue.serverTimestamp(),
    });
    await writeAudit({
      actorId: 'system',
      action: 'settlement.paid',
      targetType: 'order',
      targetId: orderDoc.id,
    });
    return true;
  } catch (e) {
    // Leave the order 'scheduled' for the next run, record the failure and
    // tell staff (SA-136).
    await writeAudit({
      actorId: 'system',
      action: 'settlement.failed',
      targetType: 'order',
      targetId: orderDoc.id,
      metadata: { error: qrWallet.failureDetail(e) },
    });
    await alertAdmins({
      title: 'Seller payout failed',
      body: `Settlement for order ${orderDoc.id} failed and will retry tomorrow.`,
      type: 'money_alert',
      deepLink: '/admin',
    });
    return false;
  }
}
