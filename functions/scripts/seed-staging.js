/*
 * Loads test data into kartafrik-staging (docs/STAGING.md).
 *
 * Creates, or refreshes if they already exist:
 *   - the platform settings (markets, fees, refund and settlement rules)
 *   - product categories
 *   - test accounts, all with the password in STAGING_TEST_PASSWORD:
 *       admin@kartafrik-staging.test    supervisor admin
 *       courier@kartafrik-staging.test  courier
 *       buyer@kartafrik-staging.test    buyer
 *       seller1..3@kartafrik-staging.test  approved sellers in Ghana
 *   - a few products for each seller
 *
 * Safe to run again: it updates the same accounts and documents rather than
 * adding duplicates. Orders, payments and reviews are never touched.
 *
 *   cd functions && npm run build
 *   GCLOUD_PROJECT=kartafrik-staging STAGING_TEST_PASSWORD=... \
 *     GOOGLE_APPLICATION_CREDENTIALS=key.json node scripts/seed-staging.js
 */
const { stagingProjectId } = require('./staging-guard');

const project = stagingProjectId();
const password = process.env.STAGING_TEST_PASSWORD;
if (!password || password.length < 8) {
  console.error('Set STAGING_TEST_PASSWORD (at least 8 characters).');
  process.exit(1);
}

const { auth, db } = require('../lib/lib/admin');
const { DEFAULT_SETTINGS } = require('../lib/config');

const DOMAIN = 'kartafrik-staging.test';
const now = () => new Date().toISOString();

const CATEGORIES = [
  ['fashion', 'Fashion', 'checkroom'],
  ['food', 'Food & groceries', 'local_grocery_store'],
  ['home', 'Home & kitchen', 'kitchen'],
  ['beauty', 'Beauty & care', 'spa'],
  ['crafts', 'Arts & crafts', 'palette'],
];

// Prices in pesewas (GHS minor units).
const SELLERS = [
  {
    key: 'seller1',
    storeName: 'Accra Threads',
    ownerName: 'Ama Mensah',
    products: [
      ['Kente stole', 'fashion', 18000],
      ['Ankara shirt', 'fashion', 15000],
      ['Batik wrap skirt', 'fashion', 12000],
      ['Beaded bracelet', 'crafts', 4500],
    ],
  },
  {
    key: 'seller2',
    storeName: 'Kumasi Pantry',
    ownerName: 'Kwame Owusu',
    products: [
      ['Shito, 500 g jar', 'food', 3500],
      ['Gari, 2 kg bag', 'food', 2800],
      ['Shea butter, 250 g', 'beauty', 4000],
      ['Black soap bar', 'beauty', 1500],
    ],
  },
  {
    key: 'seller3',
    storeName: 'Cape Coast Home',
    ownerName: 'Efua Asante',
    products: [
      ['Woven storage basket', 'home', 9000],
      ['Clay cooking pot', 'home', 7500],
      ['Carved serving bowl', 'crafts', 11000],
      ['Wax print cushion cover', 'home', 6000],
    ],
  },
];

async function upsertUser(key, displayName, claims) {
  const email = `${key}@${DOMAIN}`;
  let user;
  try {
    user = await auth.getUserByEmail(email);
    user = await auth.updateUser(user.uid, { password, displayName, emailVerified: true });
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await auth.createUser({ email, password, displayName, emailVerified: true });
  }
  await auth.setCustomUserClaims(user.uid, claims);
  return user;
}

async function staff(user, role, adminTier) {
  await db.collection('staff').doc(user.uid).set({
    role,
    adminTier: adminTier ?? null,
    email: user.email,
    phone: null,
    displayName: user.displayName,
    updatedAt: now(),
  });
}

async function main() {
  console.log(`Seeding ${project}…`);

  await db.collection('settings').doc('platform').set(DEFAULT_SETTINGS);

  for (const [id, name, iconName] of CATEGORIES) {
    await db.collection('categories').doc(id).set({
      name, parentId: null, iconName, sortOrder: CATEGORIES.findIndex((c) => c[0] === id), isActive: true,
    });
  }

  const admin = await upsertUser('admin', 'Staging Admin', { role: 'admin', adminTier: 'supervisor' });
  await staff(admin, 'admin', 'supervisor');
  const courier = await upsertUser('courier', 'Staging Courier', { role: 'delivery' });
  await staff(courier, 'delivery');
  const buyer = await upsertUser('buyer', 'Staging Buyer', {});
  await db.collection('buyers').doc(buyer.uid).set(
    { displayName: 'Staging Buyer', email: buyer.email, market: 'GH', createdAt: now() },
    { merge: true },
  );

  let productCount = 0;
  for (const s of SELLERS) {
    const user = await upsertUser(s.key, s.ownerName, { role: 'seller' });
    // Writing the seller also refreshes its public stores/ profile through
    // the syncStoreProfile trigger.
    await db.collection('sellers').doc(user.uid).set({
      storeName: s.storeName,
      ownerName: s.ownerName,
      market: 'GH',
      qrWalletId: `mock-wallet-${s.key}`,
      kycStatus: 'verified',
      approvalStatus: 'approved',
      ratingAverage: 0,
      ratingCount: 0,
      productCount: s.products.length,
      logoUrl: null,
      phone: null,
      createdAt: now(),
    }, { merge: true });

    for (const [i, [title, categoryId, priceMinor]] of s.products.entries()) {
      await db.collection('products').doc(`${s.key}-p${i + 1}`).set({
        sellerId: user.uid,
        title,
        description: `${title} from ${s.storeName}. Test item on staging.`,
        price: { minorUnits: priceMinor, currency: 'GHS' },
        categoryId,
        images: [],
        stock: 20,
        initialStock: 20,
        approvalStatus: 'approved',
        isActive: true,
        ratingAverage: 0,
        ratingCount: 0,
        lowStockThreshold: 4,
        market: 'GH',
        createdAt: now(),
        updatedAt: now(),
      }, { merge: true });
      productCount++;
    }
  }

  console.log(
    `Done: settings, ${CATEGORIES.length} categories, 6 accounts ` +
      `(admin, courier, buyer, seller1-3 @${DOMAIN}), ${productCount} products.`,
  );
}

main().then(() => process.exit(0), (e) => {
  console.error(e);
  process.exit(1);
});
