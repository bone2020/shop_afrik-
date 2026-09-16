import 'package:flutter/foundation.dart';

import 'money.dart';

/// Shop Afrik's three platform-account buckets for a single currency, mirrored
/// from the QR Wallet platform account (one document per currency, keyed by the
/// currency code).
///
/// Currencies are never blended, and only [commission] is revenue — [escrow]
/// and [payable] are liabilities (buyer funds held / seller earnings owed).
@immutable
class PlatformBalance {
  const PlatformBalance({
    required this.currency,
    required this.escrow,
    required this.payable,
    required this.commission,
    this.updatedAt,
  });

  final String currency;

  /// Buyer funds held until settlement or refund (a liability).
  final Money escrow;

  /// Seller earnings owed but not yet paid out (a liability).
  final Money payable;

  /// Shop Afrik's earned commission — the only bucket that is revenue.
  final Money commission;

  final DateTime? updatedAt;

  factory PlatformBalance.fromMap(String currency, Map<String, dynamic> map) {
    Money bucket(String key) => Money(
          minorUnits: (map[key] as num?)?.toInt() ?? 0,
          currency: currency,
        );
    return PlatformBalance(
      currency: currency,
      escrow: bucket('escrow'),
      payable: bucket('payable'),
      commission: bucket('commission'),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
    );
  }
}
