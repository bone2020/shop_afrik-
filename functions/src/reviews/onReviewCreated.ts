import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { FieldValue } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { Collections } from '../types';

/**
 * Recomputes the product's and seller's aggregate rating when a review is
 * created. Uses incremental averages in a transaction so concurrent reviews
 * stay consistent. Money-independent.
 */
export const onReviewCreated = onDocumentCreated(
  `${Collections.reviews}/{reviewId}`,
  async (event) => {
    const review = event.data?.data();
    if (!review) return;
    const productId = review.productId as string;
    const rating = (review.rating as number) ?? 0;
    if (!productId || rating < 1) return;

    const productRef = db.collection(Collections.products).doc(productId);

    await db.runTransaction(async (tx) => {
      const productSnap = await tx.get(productRef);
      if (!productSnap.exists) return;
      const p = productSnap.data()!;
      const sellerId = p.sellerId as string | undefined;

      // Read the seller in the same transaction (before any writes).
      const sellerRef = sellerId
        ? db.collection(Collections.sellers).doc(sellerId)
        : null;
      const sellerSnap = sellerRef ? await tx.get(sellerRef) : null;

      tx.update(productRef, _nextAggregate(p, rating));

      if (sellerRef && sellerSnap?.exists) {
        tx.update(sellerRef, _nextAggregate(sellerSnap.data()!, rating));
      }
    });
  },
);

function _nextAggregate(
  data: FirebaseFirestore.DocumentData,
  rating: number,
): Record<string, unknown> {
  const count = (data.ratingCount as number) ?? 0;
  const avg = (data.ratingAverage as number) ?? 0;
  const nextCount = count + 1;
  const nextAvg = (avg * count + rating) / nextCount;
  return {
    ratingCount: nextCount,
    ratingAverage: nextAvg,
    updatedAt: FieldValue.serverTimestamp(),
  };
}
