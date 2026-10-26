import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { requireAuth } from '../lib/guards';
import { Collections, OrderItem } from '../types';

const REVIEWABLE = ['delivered', 'completed'];

/**
 * A buyer reviews a product from one of their delivered orders (SA-111).
 * There is one review per order line (id `orderId_productId`), so sending
 * again edits it. Product and seller ratings are recomputed from all their
 * reviews, so edits and deletes keep them right.
 */
export const submitReview = onCall(async (req) => {
  const buyerId = requireAuth(req);
  const orderId = req.data?.orderId as string | undefined;
  const productId = req.data?.productId as string | undefined;
  const rating = req.data?.rating as number | undefined;
  const comment = ((req.data?.comment as string | undefined) ?? '').trim().slice(0, 1000);
  if (!orderId || !productId || !Number.isInteger(rating) || rating! < 1 || rating! > 5) {
    throw new HttpsError('invalid-argument', 'Choose 1 to 5 stars for an item you received.');
  }

  const order = (await db.collection(Collections.orders).doc(orderId).get()).data();
  if (!order || order.buyerId !== buyerId) {
    throw new HttpsError('permission-denied', 'You can only review your own orders.');
  }
  if (!REVIEWABLE.includes(order.status)) {
    throw new HttpsError('failed-precondition', 'You can review items once they are delivered.');
  }
  const line = ((order.items ?? []) as OrderItem[]).find((i) => i.productId === productId);
  if (!line) throw new HttpsError('not-found', 'That item is not in this order.');

  const ref = db.collection(Collections.reviews).doc(`${orderId}_${productId}`);
  const existing = await ref.get();
  const token = req.auth?.token as { name?: string } | undefined;
  await ref.set({
    productId,
    sellerId: line.sellerId,
    buyerId,
    orderId,
    rating,
    comment: comment || null,
    buyerName: (token?.name ?? '').trim().slice(0, 60) || 'Buyer',
    verifiedPurchase: true,
    createdAt: existing.data()?.createdAt ?? new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  });
  await recomputeRatings(productId, line.sellerId);
  return { ok: true, reviewId: ref.id, edited: existing.exists };
});

/** The author or an admin removes a review; ratings are recomputed. */
export const deleteReview = onCall(async (req) => {
  const uid = requireAuth(req);
  const reviewId = req.data?.reviewId as string | undefined;
  if (!reviewId) throw new HttpsError('invalid-argument', 'reviewId required.');
  const ref = db.collection(Collections.reviews).doc(reviewId);
  const review = (await ref.get()).data();
  if (!review) throw new HttpsError('not-found', 'Review not found.');
  if (review.buyerId !== uid && req.auth?.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'You can only delete your own review.');
  }
  await ref.delete();
  await recomputeRatings(review.productId, review.sellerId);
  return { ok: true };
});

/** Sets ratingAverage and ratingCount on the product and seller from scratch. */
export async function recomputeRatings(productId: string, sellerId?: string): Promise<void> {
  const aggregate = async (field: string, value: string) => {
    const snap = await db.collection(Collections.reviews).where(field, '==', value).get();
    const ratings = snap.docs.map((d) => d.data().rating as number);
    const count = ratings.length;
    return {
      ratingCount: count,
      ratingAverage: count ? ratings.reduce((a, b) => a + b, 0) / count : 0,
      updatedAt: FieldValue.serverTimestamp(),
    };
  };
  const productRef = db.collection(Collections.products).doc(productId);
  if ((await productRef.get()).exists) {
    await productRef.update(await aggregate('productId', productId));
  }
  if (sellerId) {
    const sellerRef = db.collection(Collections.sellers).doc(sellerId);
    if ((await sellerRef.get()).exists) {
      await sellerRef.update(await aggregate('sellerId', sellerId));
    }
  }
}
