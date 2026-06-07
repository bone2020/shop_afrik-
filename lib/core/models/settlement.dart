import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'money.dart';

/// A day-8 payout record from Shop Afrik to a seller (plan §6, §7).
///
/// One settlement covers a single seller's share of a single order. The gross
/// is the seller's portion of the order subtotal; commission is deducted to
/// give the net paid to the seller's QR Wallet.
@immutable
class Settlement {
  const Settlement({
    required this.id,
    required this.orderId,
    required this.sellerId,
    required this.gross,
    required this.commissionRate,
    required this.commission,
    required this.net,
    this.status = SettlementStatus.scheduled,
    this.qrWalletPayoutId,
    this.dueAt,
    this.settledAt,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String sellerId;

  /// Seller's share of the order subtotal before commission.
  final Money gross;
  final double commissionRate;

  /// Platform commission withheld (gross × rate).
  final Money commission;

  /// Amount paid to the seller (gross − commission).
  final Money net;
  final SettlementStatus status;

  /// QR Wallet payout transaction id, set once paid.
  final String? qrWalletPayoutId;
  final DateTime? dueAt;
  final DateTime? settledAt;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'sellerId': sellerId,
        'gross': gross.toMap(),
        'commissionRate': commissionRate,
        'commission': commission.toMap(),
        'net': net.toMap(),
        'status': status.name,
        'qrWalletPayoutId': qrWalletPayoutId,
        'dueAt': dueAt?.toIso8601String(),
        'settledAt': settledAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Settlement.fromMap(String id, Map<String, dynamic> map) => Settlement(
        id: id,
        orderId: map['orderId'] as String? ?? '',
        sellerId: map['sellerId'] as String? ?? '',
        gross: Money.fromMap(map['gross'] as Map<String, dynamic>?),
        commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0,
        commission: Money.fromMap(map['commission'] as Map<String, dynamic>?),
        net: Money.fromMap(map['net'] as Map<String, dynamic>?),
        status: SettlementStatus.fromName(map['status'] as String?),
        qrWalletPayoutId: map['qrWalletPayoutId'] as String?,
        dueAt: DateTime.tryParse(map['dueAt'] as String? ?? ''),
        settledAt: DateTime.tryParse(map['settledAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      );
}
