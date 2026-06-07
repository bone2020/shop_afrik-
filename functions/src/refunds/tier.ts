import { PlatformSettings } from '../config';
import { RefundTier } from '../types';

/**
 * Derives the required approval tier for a refund amount (plan §10).
 * Amounts are compared in NGN-equivalent minor units against the configured
 * ceilings. Recomputed server-side — never trust a client-supplied tier.
 */
export function refundTierFor(
  amountMinorUnits: number,
  settings: PlatformSettings,
): RefundTier {
  // Ceilings in the plan are given in whole NGN; compare in minor units.
  const tier1 = settings.refundTier1Ceiling * 100;
  const tier2 = settings.refundTier2Ceiling * 100;
  if (amountMinorUnits <= tier1) return 'tier1';
  if (amountMinorUnits <= tier2) return 'tier2';
  return 'exceptional';
}

/** Whether a refund tier requires a second (supervisor) approval. */
export function requiresSecondApproval(tier: RefundTier): boolean {
  return tier === 'tier2' || tier === 'exceptional';
}
