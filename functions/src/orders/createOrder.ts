import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { notify } from '../lib/notify';
import { loadSettings, marketFor, paymentFeeRateFor } from '../config';
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

interface DeliveryLocationInput {
  recipientName: string;
  phone: string;
  addressLine: string;
  city: string;
  region?: string;
  market: string;
}

/**
 * Places an order from a cart (Integration Spec v2 §5 step 1). No money is held
 * yet: the order starts in `awaitingDeliveryQuote` so an admin can quote
 * delivery before the buyer pays. The total at this point is items only
 * (subtotal + payment fee); delivery is added by `quoteDelivery`.
 *
 * Stock is validated here but only decremented once the buyer pays
 * (`payOrder`), so unplaced/unpaid carts never hold inventory.
 */
export const createOrder = onCall(async (req) => {
  const buyerId = requireAuth(req);

  const lines = (req.data?.items ?? []) as CartLine[];
  const location = req.data?.deliveryLocation as DeliveryLocationInput | undefined;
  const market = location?.market;
  if (!Array.isArray(lines) || lines.length === 0) {
    throw new HttpsError('invalid-argument', 'Cart is empty.');
  }
  if (!location || !market) {
    throw new HttpsError('invalid-argument', 'A delivery location is required.');
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
    // Items-only total for now. Delivery is quoted by an admin next and added
    // to the total when the order moves to awaitingPayment (v2 §5).
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
      deliveryLocation: {
        recipientName: location.recipientName,
        phone: location.phone,
        addressLine: location.addressLine,
        city: location.city,
        region: location.region ?? null,
        market,
      },
      deliveryQuoteNote: null,
      paymentMethod: null,
      total,
      status: 'awaitingDeliveryQuote',
      paymentStatus: 'pending',
      deliveryStatus: 'notDispatched',
      settlementStatus: 'notDue',
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    tx.set(orderRef, data);
    return { id: orderRef.id };
  });

  // The order is placed and awaiting a delivery quote — no money has moved.
  await notify({
    recipientId: buyerId,
    audience: 'buyer',
    title: 'Order placed',
    body: 'We are preparing your delivery quote. Delivery is not included yet.',
    type: 'order_placed',
    deepLink: `/buyer/orders/${order.id}`,
  });

  return { orderId: order.id, status: 'awaitingDeliveryQuote' };
});
