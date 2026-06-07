import { db } from './lib/admin';
import { Collections, PLATFORM_SETTINGS_DOC } from './types';

/** Per-country market configuration (mirrors Dart `MarketConfig`). */
export interface MarketConfig {
  countryCode: string;
  currency: string;
  dialCode: string;
  label: string;
  enabled: boolean;
  /** Optional per-market payment-fee rate override (falls back to global). */
  paymentFeeRate?: number;
  /** Optional minimum order amount in minor units of `currency`. */
  minOrderMinor?: number;
}

/** Refund ceilings for one currency, in MAJOR units (mirrors Dart). */
export interface RefundTierCeilings {
  tier1: number;
  tier2: number;
}

/** Admin-configurable platform settings (mirrors Dart `PlatformSettings`). */
export interface PlatformSettings {
  commissionRate: number;
  paymentFeeRate: number;
  /** Every market Shop Afrik operates in, keyed by ISO country code. */
  markets: Record<string, MarketConfig>;
  /** Refund ceilings keyed by currency — never compared across currencies. */
  refundTiersByCurrency: Record<string, RefundTierCeilings>;
  refundWindowDays: number;
  settlementDelayDays: number;
  lowStockThresholdRatio: number;
  maxProductsPerSeller: number;
  commissionByCategory: Record<string, number>;
}

// Seed defaults from the project plan (§6, §10). The Firestore document at
// settings/platform overrides these at runtime. Shop Afrik serves every
// country QR Wallet operates in; Ghana and Nigeria are merely the first two
// market rows. Adding a country is a config change here (or in Firestore),
// never a code change.
export const DEFAULT_SETTINGS: PlatformSettings = {
  commissionRate: 0.15,
  paymentFeeRate: 0.015,
  markets: {
    GH: {
      countryCode: 'GH',
      currency: 'GHS',
      dialCode: '+233',
      label: 'Ghana',
      enabled: true,
    },
    NG: {
      countryCode: 'NG',
      currency: 'NGN',
      dialCode: '+234',
      label: 'Nigeria',
      enabled: true,
    },
  },
  refundTiersByCurrency: {
    NGN: { tier1: 50000, tier2: 300000 },
    GHS: { tier1: 600, tier2: 3600 },
  },
  refundWindowDays: 7,
  settlementDelayDays: 8,
  lowStockThresholdRatio: 0.2,
  maxProductsPerSeller: 500,
  commissionByCategory: {},
};

/** Loads platform settings, falling back to plan defaults for missing keys. */
export async function loadSettings(): Promise<PlatformSettings> {
  const snap = await db
    .collection(Collections.settings)
    .doc(PLATFORM_SETTINGS_DOC)
    .get();
  return { ...DEFAULT_SETTINGS, ...(snap.data() ?? {}) } as PlatformSettings;
}

export function commissionFor(
  settings: PlatformSettings,
  categoryId?: string | null,
): number {
  if (categoryId && settings.commissionByCategory[categoryId] != null) {
    return settings.commissionByCategory[categoryId];
  }
  return settings.commissionRate;
}

export function marketFor(
  settings: PlatformSettings,
  countryCode: string,
): MarketConfig | undefined {
  return settings.markets[countryCode];
}

/** Effective payment-fee rate for a market (per-market override or global). */
export function paymentFeeRateFor(
  settings: PlatformSettings,
  countryCode: string,
): number {
  return settings.markets[countryCode]?.paymentFeeRate ?? settings.paymentFeeRate;
}

export function refundTiersFor(
  settings: PlatformSettings,
  currency: string,
): RefundTierCeilings | undefined {
  return settings.refundTiersByCurrency[currency];
}
