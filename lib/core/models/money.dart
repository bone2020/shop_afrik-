import 'package:flutter/foundation.dart';

/// A currency amount stored as integer minor units (e.g. pesewas, kobo) to
/// avoid floating-point rounding on money.
@immutable
class Money {
  const Money({required this.minorUnits, required this.currency});

  /// Amount in the currency's smallest unit (e.g. 1 major unit = 100 minor).
  final int minorUnits;

  /// ISO-4217 code. Money always carries its currency; amounts in different
  /// currencies are never combined or compared.
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

  /// Throws (in all build modes) if [other] is a different currency. Money in
  /// different currencies must never be combined or compared.
  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Cannot combine money across currencies: $currency vs ${other.currency}',
      );
    }
  }

  Map<String, dynamic> toMap() =>
      {'minorUnits': minorUnits, 'currency': currency};

  /// Deserializes money, requiring a currency — money without a currency is a
  /// data error, not a defaultable value.
  factory Money.fromMap(Map<String, dynamic>? map) {
    final currency = map?['currency'] as String?;
    if (currency == null || currency.isEmpty) {
      throw ArgumentError('Money is missing its currency: $map');
    }
    return Money(
      minorUnits: (map?['minorUnits'] as num?)?.toInt() ?? 0,
      currency: currency,
    );
  }

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
