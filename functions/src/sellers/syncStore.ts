import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { db } from '../lib/admin';
import { Collections } from '../types';

/** The only seller fields anyone may read (SA-141). */
const PUBLIC_FIELDS = [
  'storeName',
  'market',
  'logoUrl',
  'ratingAverage',
  'ratingCount',
  'productCount',
] as const;

/**
 * Keeps `stores/{sellerId}` as the public store profile. The seller document
 * itself (owner name, phone, wallet and KYC details) is private to the seller
 * and admins. A store is listed only while the seller is approved.
 */
export const syncStoreProfile = onDocumentWritten(
  `${Collections.sellers}/{sellerId}`,
  async (event) => {
    await syncStore(event.params.sellerId, event.data?.after?.data() ?? null);
  },
);

/** Writes or removes the public profile for one seller; exported for tests. */
export async function syncStore(
  sellerId: string,
  seller: FirebaseFirestore.DocumentData | null,
): Promise<void> {
  const ref = db.collection(Collections.stores).doc(sellerId);
  if (!seller) {
    await ref.delete();
    return;
  }
  const profile: Record<string, unknown> = {
    listed: seller.approvalStatus === 'approved',
  };
  for (const field of PUBLIC_FIELDS) profile[field] = seller[field] ?? null;
  await ref.set(profile);
}
