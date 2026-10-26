/*
 * One-off: builds the public stores/ profile for every existing seller.
 *
 * Shop pages read stores/{sellerId}, which the syncStoreProfile trigger keeps
 * up to date from then on. Sellers created before that trigger was deployed
 * have no profile yet; run this once after deploying it.
 *
 *   cd functions && npm run build
 *   GCLOUD_PROJECT=<project> GOOGLE_APPLICATION_CREDENTIALS=key.json \
 *     node scripts/backfill-stores.js
 *
 * Safe to run again. Unlike the seed script it is meant for any project,
 * including the real one, because it only copies data that already exists.
 */
const { db } = require('../lib/lib/admin');
const { syncStore } = require('../lib/sellers/syncStore');

async function main() {
  const sellers = await db.collection('sellers').get();
  for (const doc of sellers.docs) {
    await syncStore(doc.id, doc.data());
  }
  console.log(`Updated ${sellers.size} store profiles.`);
}

main().then(() => process.exit(0), (e) => {
  console.error(e);
  process.exit(1);
});
