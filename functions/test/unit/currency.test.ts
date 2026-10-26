import {
  decimalsFor,
  formatMoney,
  majorToMinor,
  minorToMajor,
} from '../../src/lib/currency';
import { refundTierFor } from '../../src/refunds/tier';
import { DEFAULT_SETTINGS } from '../../src/config';

describe('currency exponents (never assume 2 decimals)', () => {
  it('defaults to 2 decimals', () => {
    expect(decimalsFor('GHS')).toBe(2);
    expect(majorToMinor(12.5, 'GHS')).toBe(1250);
  });

  it('handles 3- and 0-decimal currencies', () => {
    expect(majorToMinor(1.25, 'TND')).toBe(1250);
    expect(majorToMinor(100, 'DJF')).toBe(100);
    expect(minorToMajor(100, 'MGA')).toBe(100);
  });

  it('formats like Dart Money.toString()', () => {
    expect(formatMoney({ minorUnits: 1250, currency: 'GHS' })).toBe('GHS 12.50');
    expect(formatMoney({ minorUnits: 1250, currency: 'TND' })).toBe('TND 1.250');
    expect(formatMoney({ minorUnits: 7, currency: 'KMF' })).toBe('KMF 7');
  });
});

describe('refund tiers are per currency', () => {
  it('uses the currency\'s own ceilings in minor units', () => {
    // GHS ceilings: 600 / 3600 major.
    expect(refundTierFor(60000, 'GHS', DEFAULT_SETTINGS)).toBe('tier1');
    expect(refundTierFor(60001, 'GHS', DEFAULT_SETTINGS)).toBe('tier2');
    expect(refundTierFor(360001, 'GHS', DEFAULT_SETTINGS)).toBe('exceptional');
  });

  it('rejects an unconfigured currency instead of defaulting', () => {
    expect(() => refundTierFor(1, 'XOF', DEFAULT_SETTINGS)).toThrow(
      /No refund tier ceilings/,
    );
  });
});
