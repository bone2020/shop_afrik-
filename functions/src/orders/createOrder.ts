import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { loadSettings, marketFor, paymentFeeRateFor } from '../config';
import * as qrWallet from '../lib/qrWallet';
import {
  Collections,
  Money,
  OrderItem,
  addMoney,
  applyRate,
  money,
} from '../types';

interface CartLine {
  productId: string;
  quantity: number;
}

/**
 * Creates a pending-payment order from a cart and returns a QR Wallet payload
 * for the buyer to pay (plan §5 steps 1–3).
 *
 * Stock is validated here but only decremented once payment is confirmed, so
 * unpaid carts never hold inventory. Totals follow plan §5 step 2:
 * subtotal + payment fee + delivery fee.
 */
export const createOrder = onCall(async (req) => {
  const buyerId = requireAuth(req);

  const lines = (req.data?.items ?? []) as CartLine[];
  const market = req.data?.market as string | undefined;
  if (!Array.isArray(lines) || lines.length === 0) {
    throw new HttpsError('invalid-argument', 'Cart is empty.');
  }
  if (!market) {
    throw new HttpsError('invalid-argument', 'Delivery market is required.');
  }

  const settings = await loadSettings();

  // Market is data: it must be a configured, enabled country. No GH/NG (or
  // any country) branching — behaviour is read from the market row.
  const marketCfg = marketFor(settings, market);
  if (!marketCfg || !marketCfg.enabled) {
    throw new HttpsError(
      'failed-precondition',
      `Market ${market} is not available.`,
    );
  }

  const order = await db.runTransaction(async (tx) => {
    const items: OrderItem[] = [];
    let subtotal: Money | null = null;

    for (const line of lines) {
      if (!line.productId || !line.quantity || line.quantity < 1) {
        throw new HttpsError('invalid-argument', 'Invalid cart line.');
      }
      const ref = db.collection(Collections.products).doc(line.productId);
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', `Product ${line.productId} missing.`);
      }
      const p = snap.data()!;

      if (p.approvalStatus !== 'approved' || p.isActive !== true) {
        throw new HttpsError(
          'failed-precondition',
          `Product ${p.title} is not available.`,
        );
      }
      if ((p.stock ?? 0) < line.quantity) {
        throw new HttpsError(
          'failed-precondition',
          `Insufficient stock for ${p.title}.`,
        );
      }

      const unitPrice = p.price as Money;
      const lineTotal = money(
        unitPrice.minorUnits * line.quantity,
        unitPrice.currency,
      );
      subtotal = subtotal ? addMoney(subtotal, lineTotal) : lineTotal;

      items.push({
        productId: line.productId,
        sellerId: p.sellerId,
        title: p.title,
        unitPrice,
        quantity: line.quantity,
        imageUrl: (p.images?.[0] as string) ?? null,
        refundedQuantity: 0,
      });
    }

    const sub = subtotal!;
    // The cart currency must match the market currency — never mix currencies.
    if (sub.currency !== marketCfg.currency) {
      throw new HttpsError(
        'failed-precondition',
        `Cart currency ${sub.currency} does not match market ${market} ` +
          `currency ${marketCfg.currency}.`,
      );
    }

    // Optional per-market minimum order amount.
    if (marketCfg.minOrderMinor != null && sub.minorUnits < marketCfg.minOrderMinor) {
      throw new HttpsError(
        'failed-precondition',
        'Order is below the minimum for this market.',
      );
    }

    const paymentFee = applyRate(sub, paymentFeeRateFor(settings, market));
    // Delivery is admin-set per order (not a flat market fee) and is NOT baked
    // into the up-front total: the product-vs-quote checkout flow that decides
    // how delivery is charged is not yet finalized.
    const total = addMoney(sub, paymentFee);

    const orderRef = db.collection(Collections.orders).doc();
    const sellerIds = [...new Set(items.map((i) => i.sellerId))];
    const data = {
      buyerId,
      items,
      sellerIds,
      market,
      subtotal: sub,
      paymentFee,
      deliveryFee: null,
      total,
      status: 'pendingPayment',
      paymentStatus: 'pending',
      deliveryStatus: 'notDispatched',
      settlementStatus: 'notDue',
      qrWalletTxnId: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.set(orderRef, data);
    return { id: orderRef.id, total };
  });

  // Request a QR payload for the buyer to pay (plan §5 step 3). Until the QR
  // Wallet endpoints are wired, this is reported as unconfigured rather than
  // failing order creation.
  try {
    const qr = await qrWallet.generateBusinessQrPayload({
      reference: order.id,
      amount: order.total,
    });
    return { orderId: order.id, qr, paymentConfigured: true };
  } catch (e) {
    return {
      orderId: order.id,
      qr: null,
      paymentConfigured: false,
      message: (e as Error).message,
    };
  }
});
