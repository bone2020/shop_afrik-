import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { db } from '../lib/admin';
import { writeAudit } from '../lib/audit';
import { isSupervisor, requireRole } from '../lib/guards';
import { loadSettings, MarketConfig, RefundTierCeilings } from '../config';
import { Collections, PLATFORM_SETTINGS_DOC } from '../types';

type Patch = Partial<{
  commissionRate: number;
  paymentFeeRate: number;
  refundWindowDays: number;
  settlementDelayDays: number;
  markets: Record<string, MarketConfig>;
  refundTiersByCurrency: Record<string, RefundTierCeilings>;
}>;

const bad = (message: string) => new HttpsError('invalid-argument', message);

function rate(value: unknown, name: string, max: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0 || value > max) {
    throw bad(`${name} must be between 0 and ${max * 100}%.`);
  }
  return value;
}

function days(value: unknown, name: string, min: number, max: number): number {
  if (!Number.isInteger(value) || (value as number) < min || (value as number) > max) {
    throw bad(`${name} must be a whole number from ${min} to ${max}.`);
  }
  return value as number;
}

function market(code: string, m: MarketConfig): MarketConfig {
  if (!/^[A-Z]{2}$/.test(code) || m?.countryCode !== code) {
    throw bad(`Market ${code} must use its 2-letter country code.`);
  }
  if (!/^[A-Z]{3}$/.test(m.currency ?? '')) throw bad(`Market ${code} needs a currency code.`);
  if (!/^\+\d{1,4}$/.test(m.dialCode ?? '')) throw bad(`Market ${code} needs a dial code.`);
  if (typeof m.label !== 'string' || !m.label.trim()) throw bad(`Market ${code} needs a name.`);
  if (typeof m.enabled !== 'boolean') throw bad(`Market ${code} needs enabled set.`);
  const out: MarketConfig = {
    countryCode: code,
    currency: m.currency,
    dialCode: m.dialCode,
    label: m.label.trim(),
    enabled: m.enabled,
  };
  if (m.paymentFeeRate != null) {
    out.paymentFeeRate = rate(m.paymentFeeRate, `${code} payment fee`, 0.1);
  }
  if (m.minOrderMinor != null) {
    if (!Number.isInteger(m.minOrderMinor) || m.minOrderMinor < 0) {
      throw bad(`${code} minimum order must be a whole amount.`);
    }
    out.minOrderMinor = m.minOrderMinor;
  }
  return out;
}

/**
 * Supervisor edits platform settings (SA-133). Every field is validated and
 * the change is audited with its before and after values. Settlement, refunds
 * and checkout read settings on each run, so a change applies from the next
 * one. Clients cannot write settings directly.
 */
export const updatePlatformSettings = onCall(async (req) => {
  const actorId = requireRole(req, 'admin');
  if (!isSupervisor(req)) {
    throw new HttpsError('permission-denied', 'Only a supervisor can change settings.');
  }
  const patch = (req.data?.patch ?? {}) as Patch;
  const current = await loadSettings();
  const update: Record<string, unknown> = {};

  if (patch.commissionRate !== undefined) {
    update.commissionRate = rate(patch.commissionRate, 'Commission', 0.5);
  }
  if (patch.paymentFeeRate !== undefined) {
    update.paymentFeeRate = rate(patch.paymentFeeRate, 'Payment fee', 0.1);
  }
  if (patch.refundWindowDays !== undefined) {
    update.refundWindowDays = days(patch.refundWindowDays, 'Refund window', 1, 30);
  }
  if (patch.settlementDelayDays !== undefined) {
    update.settlementDelayDays = days(patch.settlementDelayDays, 'Settlement delay', 1, 60);
  }
  const window = (update.refundWindowDays as number | undefined) ?? current.refundWindowDays;
  const delay = (update.settlementDelayDays as number | undefined) ?? current.settlementDelayDays;
  if (delay <= window) {
    // Paying out before the refund window closes would leave refunds unfunded.
    throw bad('Settlement delay must be longer than the refund window.');
  }

  if (patch.markets !== undefined) {
    const markets: Record<string, MarketConfig> = {};
    for (const [code, m] of Object.entries(patch.markets ?? {})) {
      markets[code] = market(code, m);
    }
    if (!Object.values(markets).some((m) => m.enabled)) {
      throw bad('At least one market must stay enabled.');
    }
    for (const code of Object.keys(current.markets)) {
      if (!markets[code]) throw bad(`Market ${code} cannot be removed; disable it instead.`);
      if (markets[code].currency !== current.markets[code].currency) {
        throw bad(`Market ${code} cannot change currency.`);
      }
    }
    update.markets = markets;
  }

  if (patch.refundTiersByCurrency !== undefined) {
    const tiers: Record<string, RefundTierCeilings> = {};
    for (const [currency, t] of Object.entries(patch.refundTiersByCurrency ?? {})) {
      if (!/^[A-Z]{3}$/.test(currency)) throw bad(`Unknown currency ${currency}.`);
      if (!(t?.tier1 > 0) || !(t?.tier2 > t.tier1)) {
        throw bad(`${currency} refund tiers must be positive with tier 2 above tier 1.`);
      }
      tiers[currency] = { tier1: t.tier1, tier2: t.tier2 };
    }
    update.refundTiersByCurrency = tiers;
  }

  // Every enabled market's currency needs refund tiers.
  const markets = (update.markets as Record<string, MarketConfig>) ?? current.markets;
  const tiers =
    (update.refundTiersByCurrency as Record<string, RefundTierCeilings>) ??
    current.refundTiersByCurrency;
  for (const m of Object.values(markets)) {
    if (m.enabled && !tiers[m.currency]) {
      throw bad(`Set refund tiers for ${m.currency} before enabling ${m.label}.`);
    }
  }

  const changed = Object.keys(update).filter(
    (k) =>
      JSON.stringify(update[k]) !==
      JSON.stringify((current as unknown as Record<string, unknown>)[k]),
  );
  if (changed.length === 0) return { ok: true, changed };

  await db
    .collection(Collections.settings)
    .doc(PLATFORM_SETTINGS_DOC)
    .set(Object.fromEntries(changed.map((k) => [k, update[k]])), { merge: true });

  await writeAudit({
    actorId,
    action: 'settings.updated',
    targetType: 'settings',
    targetId: PLATFORM_SETTINGS_DOC,
    metadata: {
      changed,
      before: Object.fromEntries(
        changed.map((k) => [k, (current as unknown as Record<string, unknown>)[k] ?? null]),
      ),
      after: Object.fromEntries(changed.map((k) => [k, update[k]])),
    },
  });

  return { ok: true, changed };
});
