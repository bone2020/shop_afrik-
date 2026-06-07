# CLAUDE.md

Guidance for working in the Shop Afrik repository.

## What this is

Shop Afrik is a Flutter + Firebase multi-seller e-commerce marketplace for
African markets, integrated with **QR Wallet** for payments. The
authoritative spec is `docs/planning/Shop_Afrik_Project_Plan_and_Roadmap.pdf`
— read it before making product decisions.

## Architecture (plan §4)

- **Shop Afrik Flutter app** — buyer, seller, and admin experiences.
- **Shop Afrik Firebase project** — its own project, separate from QR Wallet.
  Holds products, orders, sellers, buyers, refunds, settlements, audit logs.
- **Shop Afrik Cloud Functions** — order creation, QR payload generation,
  payment confirmation, settlement jobs, refund workflow, permissions.
- **QR Wallet Firebase project** — business wallet, QR signing, sendMoney,
  refunds, holds, KYC. Integrate via Cloud Functions; do **not** refactor
  QR Wallet. Use the business-wallet pattern (the lower-risk decision in §4).

## Conventions

- **State management:** Riverpod (`flutter_riverpod`).
- **Routing:** `go_router`; paths live in `lib/core/router/routes.dart`.
- **Theme:** never hard-code colors — use `AppColors` / `AppTheme`.
- **Config:** MVP business defaults live in `lib/core/config/app_config.dart`,
  but the runtime source of truth for admin-configurable values (commission,
  refund tiers, low-stock threshold) is the platform settings doc in Firestore.
- **Feature-first layout:** `lib/features/<role>/presentation/...`.
- Lints are enforced via `analysis_options.yaml` (single quotes, const).

## Commands

```bash
flutter pub get      # install deps
flutter run          # run the app
flutter test         # run tests
flutter analyze      # static analysis
```

## Key business rules (plan §6)

- Commission: 15% default, admin-configurable.
- Refund window: 7 days from courier-confirmed delivery.
- Settlement: day 8 after delivery (after refund window closes).
- Partial refunds allowed for multi-item orders; single-item is all-or-nothing.
- Refund approval is tiered: tier 1 ≤ NGN 50,000; tier 2 (admin+supervisor)
  ≤ NGN 300,000.
- Seller KYC required (via QR Wallet) before seller approval.

## Secrets

Never commit `firebase_options.dart`, `google-services.json`,
`GoogleService-Info.plist`, or `.env*` — they are git-ignored.
