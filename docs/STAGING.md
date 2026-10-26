# Staging

Staging is a private copy of KartAfrik on the internet: its own Firebase
project (`kartafrik-staging`), its own test accounts, and the **fake BonsPay**
instead of real money. Nothing done there reaches real customers or money.

## One-time setup (project owner)

1. Create the Firebase project with the ID exactly `kartafrik-staging`. The
   fake BonsPay refuses to run in a project without "staging" in its ID.
2. Upgrade it to the Blaze plan and add a budget alert (about $10/month) under
   Usage and billing → Account & budgets.
3. Authentication → Sign-in method: enable Email/Password and Phone.
4. Create the Firestore database and Storage, both in `europe-west1`,
   production mode (our rules replace the defaults on the first deploy).
5. Deploy key:
   - Project settings → Service accounts → Generate new private key.
   - Google Cloud console → IAM: give the `firebase-adminsdk-…` account the
     **Editor**, **Service Account User**, **Project IAM Admin**, **Cloud
     Functions Admin** and **Cloud Run Admin** roles. The first functions
     deploy needs all five: it grants Google's own services their roles and
     lets the app call the functions. Once a deploy has passed, remove
     **Project IAM Admin** again: later deploys only check those grants, and
     the key stored in GitHub should not be able to change who has access.
   - Google Cloud console → APIs: enable the **Cloud Billing API** (the deploy
     checks the project is on Blaze).
   - GitHub → Settings → Secrets and variables → **Actions** (not Codespaces
     or Dependabot) → New repository secret
     `FIREBASE_SERVICE_ACCOUNT_STAGING`, paste the whole key file.
   - Delete the downloaded key file.
6. GitHub Actions secret `STAGING_TEST_PASSWORD`: the password every test
   account uses.
7. Run Staging → **deploy and load test data**, then → **register apps**, and
   put the printed `apiKey`, `appId` and `messagingSenderId` values into
   `lib/core/config/staging_firebase_options.dart`.

If the very first deploy fails on an "Eventarc Service Agent" permission,
wait a few minutes and run it again; Google is still setting the project up.

## The Staging button

GitHub → Actions → **Staging** → Run workflow, then pick:

| Action | What it does |
| --- | --- |
| deploy | Installs the latest `main` on staging: database rules and indexes, storage rules, server functions with the fake BonsPay on. |
| deploy and load test data | Both. Use this the first time. |
| load test data | Refreshes the test data only (see below). Safe to repeat. |
| register apps | Registers the staging Android and iOS apps and prints their settings (needed once, for `lib/core/config/staging_firebase_options.dart`). |
| backfill stores | Builds shop profiles for sellers created before the `stores/` list existed. |

Pick the branch to run from in the same dialog; normally `main`.

## Test data

All accounts use the `STAGING_TEST_PASSWORD` password and have verified email.

| Account | Role |
| --- | --- |
| `admin@kartafrik-staging.test` | Supervisor admin |
| `courier@kartafrik-staging.test` | Courier |
| `buyer@kartafrik-staging.test` | Buyer |
| `seller1@kartafrik-staging.test` | Accra Threads (fashion) |
| `seller2@kartafrik-staging.test` | Kumasi Pantry (food, beauty) |
| `seller3@kartafrik-staging.test` | Cape Coast Home (home, crafts) |

Each seller has four products in Ghana, priced in cedis, 20 in stock. Loading
the data again resets those accounts, products and the platform settings; it
never touches orders, payments or reviews.

The fake BonsPay's behaviour can be switched per operation for testing
failures, in Firestore at `_mock_bonspay/config`:
`{ behavior: { capture: 'fail' } }` (or `'timeout'`, or `'ok'`).

## Running the staging app

```
flutter run --dart-define=KARTAFRIK_ENV=staging
```

The app shows a **STAGING** ribbon. On Android it installs as a separate app,
"KartAfrik Staging", next to the normal one. On iPhone it replaces the normal
build, because both share one bundle ID until release signing is set up.

## Moving to BonsPay's staging

When BonsPay's own staging is ready, remove `QR_WALLET_MODE=mock` from
`functions/.env.kartafrik-staging`, add their staging connection settings, and
run **deploy**.
