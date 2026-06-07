import { onSchedule } from 'firebase-functions/v2/scheduler';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { commissionFor, loadSettings } from '../config';
import { formatMoney } from '../lib/currency';
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
export const settleDueOrders = onSchedule('every day 02:00', async () => {
  const settings = await loadSettings();
  const now = Timestamp.now();

  const due = await db
    .collection(Collections.orders)
    .where('settlementStatus', '==', 'scheduled')
    .where('settlementDueAt', '<=', now)
    .limit(200)
    .get();

  for (const orderDoc of due.docs) {
    const order = orderDoc.data();
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
        const sellerWalletId =
          (sellerSnap.data()?.qrWalletId as string) ?? sellerId;

        const payoutId = await qrWallet.settleToSeller({
          sellerWalletId,
          amount: net,
          reference: settlementId,
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
    } catch (e) {
      // Leave the order 'scheduled' for the next run and record the failure.
      await writeAudit({
        actorId: 'system',
        action: 'settlement.failed',
        targetType: 'order',
        targetId: orderDoc.id,
        metadata: { error: (e as Error).message },
      });
    }
  }
});
