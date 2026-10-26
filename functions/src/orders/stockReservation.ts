import { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue, Timestamp, Transaction } from 'firebase-admin/firestore';
import { db } from '../lib/admin';
import { Collections } from '../types';

/** How long reserved stock waits for a payment to complete. */
export const RESERVATION_MINUTES = 15;

interface Line {
  productId: string;
  quantity: number;
  title?: string;
}

/**
 * Takes [lines] out of stock inside [tx], or rejects without changing anything
 * if any product is short (SA-040). Never clamps to zero: overselling is an
 * error, not a rounding problem.
 */
export async function reserveStock(tx: Transaction, lines: Line[]): Promise<void> {
  const snaps = await Promise.all(
    lines.map((l) => tx.get(db.collection(Collections.products).doc(l.productId))),
  );
  snaps.forEach((p, i) => {
    const available = (p.data()?.stock as number | undefined) ?? 0;
    if (!p.exists || available < lines[i].quantity) {
      throw new HttpsError(
        'failed-precondition',
        `Sorry, ${lines[i].title ?? 'an item'} just sold out.`,
      );
    }
  });
  snaps.forEach((p, i) => {
    tx.update(p.ref, {
      stock: FieldValue.increment(-lines[i].quantity),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

/** Puts reserved [lines] back into stock inside [tx]. */
export async function releaseStock(tx: Transaction, lines: Line[]): Promise<void> {
  const snaps = await Promise.all(
    lines.map((l) => tx.get(db.collection(Collections.products).doc(l.productId))),
  );
  snaps.forEach((p, i) => {
    if (!p.exists) return;
    tx.update(p.ref, {
      stock: FieldValue.increment(lines[i].quantity),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

export function reservationExpiry(): Timestamp {
  return Timestamp.fromMillis(Date.now() + RESERVATION_MINUTES * 60 * 1000);
}
