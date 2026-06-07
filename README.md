# Shop Afrik

A multi-seller African e-commerce marketplace, mobile-first in Flutter and
integrated with **QR Wallet** for payments, refunds, and day-8 seller
settlement.

See [`docs/planning/Shop_Afrik_Project_Plan_and_Roadmap.pdf`](docs/planning/Shop_Afrik_Project_Plan_and_Roadmap.pdf)
for the full product plan and technical roadmap.

## Status

**Phase 1 — Project setup.** The Flutter app foundation is in place:

- Brand theme tokens and a Material 3 dark theme (plan §8).
- `go_router` routing shell with buyer / seller / admin route trees.
- Role + session model and a placeholder sign-in / role picker.
- MVP configuration defaults from the plan (commission, refund window,
  settlement delay, refund tiers, markets).
- Firebase dependencies wired (initialization deferred until
  `flutterfire configure` is run — see below).

## Project structure

```
lib/
  main.dart                  App entry point
  app.dart                   Root MaterialApp.router
  core/
    config/app_config.dart   MVP defaults (commission, refunds, markets)
    models/user_role.dart     UserRole / AdminTier
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
| 1 | Project setup *(current)* |
| 2 | Backend data model, security rules, Cloud Functions |
| 3 | Buyer MVP — shopping, cart, QR checkout, orders |
| 4 | Seller MVP — onboarding, product CRUD, orders, payouts |
| 5 | Admin MVP — approvals, refunds, commissions, audit logs |
| 6 | Enhancements — deep links, pay on delivery, analytics |
