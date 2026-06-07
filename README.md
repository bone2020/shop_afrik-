# Shop Afrik

A multi-seller African e-commerce marketplace, mobile-first in Flutter and
integrated with **QR Wallet** for payments, refunds, and day-8 seller
settlement.

See [`docs/planning/Shop_Afrik_Project_Plan_and_Roadmap.pdf`](docs/planning/Shop_Afrik_Project_Plan_and_Roadmap.pdf)
for the full product plan and technical roadmap.

## Status

**Phase 1 — Project setup** ✅

- Brand theme tokens and a Material 3 dark theme (plan §8).
- `go_router` routing shell with buyer / seller / admin route trees.
- Role + session model and a placeholder sign-in / role picker.
- MVP configuration defaults from the plan (commission, refund window,
  settlement delay, refund tiers, markets).
- Firebase dependencies wired (initialization deferred until
  `flutterfire configure` is run — see below).

**Phase 2 — Backend data foundation** ✅

- Domain models for every collection in plan §7 (`lib/core/models`), with
  status enums encoding the order / refund / settlement state machines.
- Firestore security rules (`firestore.rules`) and Cloud Storage rules
  (`storage.rules`), role-driven via custom claims.
- Composite indexes (`firestore.indexes.json`) and emulator config
  (`firebase.json`).
- Cloud Functions (`functions/`, TypeScript) for the money-critical flows:
  order creation + QR payload, payment confirmation, delivery confirmation,
  tiered refund decisions, seller approval, role management, and the daily
  day-8 settlement job. The QR Wallet integration is isolated behind one
  module (`functions/src/lib/qrWallet.ts`) to be wired to the QR Wallet
  project (plan §4 business-wallet pattern).

### Backend

```bash
cd functions
npm install
npm run build        # tsc typecheck/compile
npm run lint
firebase emulators:start   # auth + firestore + functions + storage
```

Roles live in custom auth claims (`role`, `adminTier`); the `setUserRole` and
`approveSeller` functions are the only places they are granted. The security
rules and Storage rules read those claims.

## Project structure

```
lib/
  main.dart                  App entry point
  app.dart                   Root MaterialApp.router
  core/
    config/app_config.dart   MVP defaults (commission, refunds, markets)
    data/                    Firestore collection name constants
    models/                  Domain models + status enums (plan §7)
    router/                   Routes + go_router config
    theme/                   Brand colors + dark theme
  features/
    auth/                    Sign-in / role picker
    buyer/                   Buyer experience (Phase 3)
    seller/                  Seller dashboard (Phase 4)
    admin/                   Admin console (Phase 5)
    shared/                  Shared widgets
  services/
    firebase_bootstrap.dart   Firebase init
    session_controller.dart   Riverpod session state

functions/src/               Cloud Functions (TypeScript)
  orders/                    createOrder, confirmPayment, confirmDelivery
  refunds/                   decideRefund (tiered approval)
  settlement/                settleDueOrders (day-8 scheduled job)
  sellers/                   approveSeller
  auth/                      setUserRole (custom claims)
  lib/                       admin SDK, qrWallet seam, audit, notify, guards

firestore.rules              Firestore security rules
storage.rules                Cloud Storage rules
firestore.indexes.json       Composite indexes
firebase.json                Firebase project + emulator config
```

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(>=3.22) with Dart >=3.4.

```bash
flutter pub get
flutter run
flutter test
```

### Firebase

This app targets a **dedicated Shop Afrik Firebase project**, separate from
QR Wallet (plan §10). Generate the per-environment options:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This writes `lib/firebase_options.dart` (git-ignored). Then enable the
`ensureFirebaseInitialized()` call in `lib/main.dart`.

## Roadmap

| Phase | Outcome |
|-------|---------|
| 1 | Project setup ✅ |
| 2 | Backend data model, security rules, Cloud Functions ✅ |
| 3 | Buyer MVP — shopping, cart, QR checkout, orders *(next)* |
| 4 | Seller MVP — onboarding, product CRUD, orders, payouts |
| 5 | Admin MVP — approvals, refunds, commissions, audit logs |
| 6 | Enhancements — deep links, pay on delivery, analytics |
