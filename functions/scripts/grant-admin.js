/*
 * One-time admin bootstrap.
 *
 * Because `setUserRole` is admin-only, the very first admin has to be crowned by
 * hand. Create your real account in the app first (email or phone), find its
 * uid in Firebase console → Authentication, then run this once.
 *
 * Auth: point GOOGLE_APPLICATION_CREDENTIALS at a service-account key for the
 * Shop Afrik Firebase project (Project settings → Service accounts → Generate
 * new private key), or run somewhere with application-default credentials.
 *
 *   cd functions
 *   npm install
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json node scripts/grant-admin.js <uid>
 *
 * Grants { role: 'admin', adminTier: 'supervisor' }. The user must refresh
 * their ID token (the app force-refreshes on resume) or sign out/in to pick it
 * up. After this, provision further admins/sellers/delivery via setUserRole.
 */
const admin = require('firebase-admin');

async function main() {
  const uid = process.argv[2];
  if (!uid) {
    console.error('Usage: node scripts/grant-admin.js <uid>');
    process.exit(1);
  }

  admin.initializeApp();
  await admin.auth().setCustomUserClaims(uid, {
    role: 'admin',
    adminTier: 'supervisor',
  });
  console.log(`Granted role=admin, adminTier=supervisor to ${uid}.`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
