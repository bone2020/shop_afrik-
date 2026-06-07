# CLAUDE.md

Guidance for working in the Shop Afrik repository.

## What this is

Shop Afrik is a Flutter + Firebase multi-seller e-commerce marketplace for
African markets, integrated with **QR Wallet** for payments. The
authoritative spec is `docs/planning/Shop_Afrik_Project_Plan_and_Roadmap.pdf`
— read it before making product decisions.

## Multi-country (read this first)

Shop Afrik targets **every country QR Wallet operates in** (~20–22). Ghana and
Nigeria are only the first launch markets. Therefore:

- **Country and currency are data, not assumptions.** Supported markets,
  currency codes, payment-fee %, delivery fees, refund-tier thresholds, and
  validation come from config / `platform_settings`, keyed by country code or
  currency — never hardcoded, never branched on (`if GH …`).
- **Adding a country is a config change only** (a new market row), never a code
  change. The seed market rows live in exactly one place per language:
  `AppConfig.seedMarkets` (Dart) and `DEFAULT_SETTINGS.markets` (TS).
- **No logic may assume a fixed number of markets** or compare across markets.
- **Money always carries its currency** (`Money`); amounts in different
  currencies are never combined or compared (the `Money` types throw if you
  try). Refund tiers are configured per currency.

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

App:

```bash
flutter pub get      # install deps
flutter run          # run the app
flutter test         # run tests
flutter analyze      # static analysis
```

Backend (Cloud Functions, in `functions/`):

```bash
npm install
npm run build        # tsc compile + typecheck
npm run lint
firebase emulators:start
```

## Backend conventions

- **Roles are custom auth claims** (`role`, `adminTier`). They are granted only
  by `setUserRole` and `approveSeller`. The Firestore and Storage rules read
  these claims — never trust client-set role fields.
- **Money flows through Cloud Functions only.** Orders, settlements, refund
  decisions, and audit entries are server-written; the rules make those paths
  read-only/closed to clients (the Admin SDK bypasses rules).
- **All QR Wallet calls go through `functions/src/lib/qrWallet.ts`** — the one
  seam to the QR Wallet project. Do not call QR Wallet elsewhere.
- **Money is integer minor units** (`Money` in Dart, `Money` in TS). Never use
  floats for amounts.
- Keep the Dart enums (`lib/core/models/enums.dart`) and the TS types
  (`functions/src/types.ts`) in sync — they encode the same state machines.
- `admin_audit` is append-only: never update or delete entries.

## Key business rules (plan §6)

- Commission: 15% default, admin-configurable.
- Refund window: 7 days from courier-confirmed delivery.
- Settlement: day 8 after delivery (after refund window closes).
- Partial refunds allowed for multi-item orders; single-item is all-or-nothing.
- Refund approval is tiered, with ceilings configured **per currency** in
  `refundTiersByCurrency` (plan §10 seeds: NGN 50,000 / 300,000). Tier 2
  requires admin + supervisor. Thresholds are never compared across currencies.
- Seller KYC required (via QR Wallet) before seller approval.

## Secrets

Never commit `firebase_options.dart`, `google-services.json`,
`GoogleService-Info.plist`, or `.env*` — they are git-ignored.
