import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireRole, isSupervisor } from '../lib/guards';
import { writeAudit } from '../lib/audit';
import { notify } from '../lib/notify';
import { loadSettings } from '../config';
import * as qrWallet from '../lib/qrWallet';
import { refundTierFor, requiresSecondApproval } from './tier';
import { Collections, Money } from '../types';

/**
 * Records an admin decision on a refund request, enforcing tiered approval
 * (plan §6, §10):
 *   - tier1: one admin approves.
 *   - tier2 / exceptional: two distinct approvers, the second a supervisor.
 *
 * When the required approvals are met, the refund is paid back to the buyer via
 * QR Wallet and the order's payment/settlement legs are adjusted. The approval
 * state is persisted before payout so an unconfigured QR Wallet leaves an
 * auditable "approved, awaiting payout" record rather than losing the decision.
 */
export const decideRefund = onCall(async (req) => {
  const adminId = requireRole(req, 'admin');
  const refundId = req.data?.refundId as string | undefined;
  const decision = req.data?.decision as 'approve' | 'reject' | undefined;
  const note = (req.data?.note as string | undefined) ?? null;

  if (!refundId || (decision !== 'approve' && decision !== 'reject')) {
    throw new HttpsError('invalid-argument', 'refundId and decision required.');
  }

  const settings = await loadSettings();
  const refundRef = db.collection(Collections.refundRequests).doc(refundId);

  // Step 1: record the decision / approval progress in a transaction.
  const outcome = await db.runTransaction(async (tx) => {
    const snap = await tx.get(refundRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Refund not found.');
    const r = snap.data()!;

    if (['refunded', 'rejected'].includes(r.status)) {
      throw new HttpsError('failed-precondition', 'Refund already resolved.');
    }

    const amount = r.amount as Money;
    const tier = refundTierFor(amount.minorUnits, settings);

    if (decision === 'reject') {
      tx.update(refundRef, {
        status: 'rejected',
        firstApproverId: r.firstApproverId ?? adminId,
        decisionNote: note,
        tier,
        resolvedAt: FieldValue.serverTimestamp(),
      });
      return { action: 'rejected' as const, buyerId: r.buyerId as string };
    }

    // Approve path.
    if (!requiresSecondApproval(tier)) {
      tx.update(refundRef, {
        status: 'approved',
        firstApproverId: adminId,
        decisionNote: note,
        tier,
      });
      return {
        action: 'ready' as const,
        buyerId: r.buyerId as string,
        orderId: r.orderId as string,
        amount,
      };
    }

    // Tier 2 / exceptional: needs two distinct approvers, 2nd a supervisor.
    if (!r.firstApproverId) {
      tx.update(refundRef, {
        status: 'escalated',
        firstApproverId: adminId,
        decisionNote: note,
        tier,
      });
      return { action: 'escalated' as const, buyerId: r.buyerId as string };
    }

    if (r.firstApproverId === adminId) {
      throw new HttpsError(
        'failed-precondition',
        'A second, different approver is required for this refund.',
      );
    }
    if (!isSupervisor(req)) {
      throw new HttpsError(
        'permission-denied',
        'The second approval must be made by a supervisor.',
      );
    }

    tx.update(refundRef, {
      status: 'approved',
      secondApproverId: adminId,
      decisionNote: note,
      tier,
    });
    return {
      action: 'ready' as const,
      buyerId: r.buyerId as string,
      orderId: r.orderId as string,
      amount,
    };
  });

  await writeAudit({
    actorId: adminId,
    action: `refund.${outcome.action}`,
    targetType: 'refund_request',
    targetId: refundId,
  });

  if (outcome.action === 'rejected') {
    await notify({
      recipientId: outcome.buyerId,
      audience: 'buyer',
      title: 'Refund declined',
      body: 'Your refund request was reviewed and declined.',
      type: 'refund_decision',
      deepLink: '/buyer/orders',
    });
    return { ok: true, status: 'rejected' };
  }

  if (outcome.action === 'escalated') {
    return { ok: true, status: 'escalated' };
  }

  // Step 2: required approvals met — pay the buyer and adjust the order.
  const payoutId = await qrWallet.refundToBuyer({
    buyerWalletId: outcome.buyerId,
    amount: outcome.amount,
    reference: refundId,
  });

  await finalizeRefund(refundId, outcome.orderId, outcome.amount, payoutId);
  await notify({
    recipientId: outcome.buyerId,
    audience: 'buyer',
    title: 'Refund issued',
    body: 'Your refund has been sent to your QR Wallet.',
    type: 'refund_decision',
    deepLink: `/buyer/orders/${outcome.orderId}`,
  });

  return { ok: true, status: 'refunded' };
});

/** Marks the refund refunded and adjusts the order's payment/settlement legs. */
async function finalizeRefund(
  refundId: string,
  orderId: string,
  amount: Money,
  payoutId: string,
): Promise<void> {
  await db.runTransaction(async (tx) => {
    const refundRef = db.collection(Collections.refundRequests).doc(refundId);
    const orderRef = db.collection(Collections.orders).doc(orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) throw new HttpsError('not-found', 'Order missing.');
    const order = orderSnap.data()!;

    const total = order.total as Money;
    const fullyRefunded = amount.minorUnits >= total.minorUnits;

    tx.update(refundRef, {
      status: 'refunded',
      qrWalletRefundId: payoutId,
      resolvedAt: FieldValue.serverTimestamp(),
    });

    tx.update(orderRef, {
      paymentStatus: fullyRefunded ? 'refunded' : 'partiallyRefunded',
      status: fullyRefunded ? 'refunded' : order.status,
      // Hold or reverse settlement so we never pay a seller for refunded goods.
      settlementStatus: fullyRefunded ? 'reversed' : 'onHold',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}
