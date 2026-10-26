import { Money } from '../types';

// ISO 4217 exponents (mirrors Dart `CurrencyMeta`). Only non-2-decimal
// currencies are listed; everything else defaults to 2. MRU and MGA
// subdivide by 5, which has no power-of-ten minor unit, so they are tracked
// as whole units (exponent 0). Never assume two decimals.
const EXPONENT_OVERRIDES: Record<string, number> = {
  TND: 3,
  LYD: 3,
  DJF: 0,
  KMF: 0,
  MRU: 0,
  MGA: 0,
};

/** Number of decimal places (ISO 4217 exponent) for [currency]; 2 by default. */
export function decimalsFor(currency: string): number {
  return EXPONENT_OVERRIDES[currency] ?? 2;
}

/** Number of minor units in one major unit (10^exponent). */
export function minorUnitsPer(currency: string): number {
  return 10 ** decimalsFor(currency);
}

/** Converts a whole-currency amount to integer minor units. */
export function majorToMinor(major: number, currency: string): number {
  return Math.round(major * minorUnitsPer(currency));
}

/** Converts integer minor units to a whole-currency amount. */
export function minorToMajor(minorUnits: number, currency: string): number {
  return minorUnits / minorUnitsPer(currency);
}

/** Formats like Dart `Money.toString()`, e.g. `GHS 12.50`, `TND 1.250`. */
export function formatMoney(m: Money): string {
  const major = minorToMajor(m.minorUnits, m.currency);
  return `${m.currency} ${major.toFixed(decimalsFor(m.currency))}`;
}
