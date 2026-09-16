/// Currency minor-unit metadata (ISO 4217 exponents).
///
/// Money is stored in integer minor units, but the number of minor units per
/// major unit is **not** always 100 — assuming two decimals silently corrupts
/// amounts. The exponent comes from each currency's ISO 4217 definition.
///
/// Only non-2-decimal currencies are listed; everything else defaults to 2.
/// MRU (ouguiya) and MGA (ariary) legally subdivide by 5 (khoums /
/// iraimbilanja), which has no clean power-of-ten minor unit, so they are
/// tracked as whole units (exponent 0).
abstract final class CurrencyMeta {
  static const Map<String, int> _exponentOverrides = {
    // 3-decimal currencies in Shop Afrik's markets.
    'TND': 3,
    'LYD': 3,
    // 0-decimal currencies.
    'DJF': 0,
    'KMF': 0,
    // Non-decimal subdivisions (subdivide by 5) — treated as 0 decimals.
    'MRU': 0,
    'MGA': 0,
  };

  /// Number of decimal places (ISO 4217 exponent) for [currency]; 2 by default.
  static int decimalsFor(String currency) => _exponentOverrides[currency] ?? 2;

  /// Number of minor units in one major unit (10^exponent).
  static int minorUnitsPer(String currency) {
    var factor = 1;
    for (var i = 0; i < decimalsFor(currency); i++) {
      factor *= 10;
    }
    return factor;
  }
}
