import 'package:flutter/foundation.dart';

/// A currency amount stored as integer minor units (e.g. pesewas, kobo) to
/// avoid floating-point rounding on money.
@immutable
class Money {
  const Money({required this.minorUnits, required this.currency});

  /// Amount in the currency's smallest unit (1 GHS = 100 pesewas).
  final int minorUnits;

  /// ISO-4217 code, e.g. `GHS`, `NGN`.
  final String currency;

  double get major => minorUnits / 100.0;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  /// Multiply by a quantity (e.g. unit price × qty).
  Money operator *(int factor) =>
      Money(minorUnits: minorUnits * factor, currency: currency);

  /// Apply a rate (e.g. commission), rounding to the nearest minor unit.
  Money applyRate(double rate) =>
      Money(minorUnits: (minorUnits * rate).round(), currency: currency);

  void _assertSameCurrency(Money other) {
    assert(
      currency == other.currency,
      'Currency mismatch: $currency vs ${other.currency}',
    );
  }

  Map<String, dynamic> toMap() =>
      {'minorUnits': minorUnits, 'currency': currency};

  factory Money.fromMap(Map<String, dynamic>? map) => Money(
        minorUnits: (map?['minorUnits'] as num?)?.toInt() ?? 0,
        currency: map?['currency'] as String? ?? 'GHS',
      );

  static Money zero(String currency) =>
      Money(minorUnits: 0, currency: currency);

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '$currency ${major.toStringAsFixed(2)}';
}
