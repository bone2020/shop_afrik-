import { PlatformSettings, refundTiersFor } from '../config';
import { majorToMinor } from '../lib/currency';
import { RefundTier } from '../types';

/**
 * Derives the required approval tier for a refund (plan §10), comparing the
 * amount against the ceilings configured **for its own currency**. Thresholds
 * are never compared across currencies, and the currency must be configured —
 * an unknown currency is a configuration error, not a silent default.
 */
export function refundTierFor(
  amountMinorUnits: number,
  currency: string,
  settings: PlatformSettings,
): RefundTier {
  const ceilings = refundTiersFor(settings, currency);
  if (!ceilings) {
    throw new Error(
      `No refund tier ceilings configured for currency ${currency}. ` +
        'Add a row to platform settings refundTiersByCurrency.',
    );
  }
  // Ceilings are in whole-currency units; compare in minor units using the
  // currency's own exponent (never assume two decimals).
  const tier1 = majorToMinor(ceilings.tier1, currency);
  const tier2 = majorToMinor(ceilings.tier2, currency);
  if (amountMinorUnits <= tier1) return 'tier1';
  if (amountMinorUnits <= tier2) return 'tier2';
  return 'exceptional';
}

/** Whether a refund tier requires a second (supervisor) approval. */
export function requiresSecondApproval(tier: RefundTier): boolean {
  return tier === 'tier2' || tier === 'exceptional';
}
