import { db } from './lib/admin';
import { Collections, PLATFORM_SETTINGS_DOC } from './types';

/** Admin-configurable platform settings (mirrors Dart `PlatformSettings`). */
export interface PlatformSettings {
  commissionRate: number;
  paymentFeeRate: number;
  deliveryFeeByMarket: Record<string, number>;
  refundWindowDays: number;
  settlementDelayDays: number;
  refundTier1Ceiling: number;
  refundTier2Ceiling: number;
  lowStockThresholdRatio: number;
  maxProductsPerSeller: number;
  commissionByCategory: Record<string, number>;
}

// Seed defaults from the project plan (§6, §10). The Firestore document at
// settings/platform overrides these at runtime.
export const DEFAULT_SETTINGS: PlatformSettings = {
  commissionRate: 0.15,
  paymentFeeRate: 0.015,
  deliveryFeeByMarket: { GH: 1500, NG: 150000 },
  refundWindowDays: 7,
  settlementDelayDays: 8,
  refundTier1Ceiling: 50000,
  refundTier2Ceiling: 300000,
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
