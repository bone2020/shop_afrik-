import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'money.dart';

/// One line of an order being refunded (partial refunds, plan §6).
@immutable
class RefundLine {
  const RefundLine({
    required this.productId,
    required this.quantity,
    required this.amount,
  });

  final String productId;
  final int quantity;
  final Money amount;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'quantity': quantity,
        'amount': amount.toMap(),
      };

  factory RefundLine.fromMap(Map<String, dynamic> map) => RefundLine(
        productId: map['productId'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        amount: Money.fromMap(map['amount'] as Map<String, dynamic>?),
      );
}

/// A buyer refund request with tiered admin approval (plan §6, §7, §10).
@immutable
class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.buyerId,
    required this.lines,
    required this.amount,
    required this.reason,
    required this.tier,
    this.status = RefundStatus.requested,
    this.evidenceUrls = const [],
    this.firstApproverId,
    this.secondApproverId,
    this.decisionNote,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String orderId;
  final String buyerId;
  final List<RefundLine> lines;
  final Money amount;
  final String reason;

  /// Approval tier derived from [amount] (plan §10).
  final RefundTier tier;
  final RefundStatus status;
  final List<String> evidenceUrls;

  /// Admin who first reviewed (tier 1) or initiated tier-2 escalation.
  final String? firstApproverId;

  /// Supervisor who provided the second approval for tier-2 refunds.
  final String? secondApproverId;
  final String? decisionNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  /// Tier-2 refunds require two distinct approvers before they can be paid.
  bool get hasRequiredApprovals {
    if (tier == RefundTier.tier1) return firstApproverId != null;
    return firstApproverId != null &&
        secondApproverId != null &&
        firstApproverId != secondApproverId;
  }

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'buyerId': buyerId,
        'lines': lines.map((l) => l.toMap()).toList(),
        'amount': amount.toMap(),
        'reason': reason,
        'tier': tier.name,
        'status': status.name,
        'evidenceUrls': evidenceUrls,
        'firstApproverId': firstApproverId,
        'secondApproverId': secondApproverId,
        'decisionNote': decisionNote,
        'createdAt': createdAt?.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  factory RefundRequest.fromMap(String id, Map<String, dynamic> map) =>
      RefundRequest(
        id: id,
        orderId: map['orderId'] as String? ?? '',
        buyerId: map['buyerId'] as String? ?? '',
        lines: (map['lines'] as List?)
                ?.map((l) => RefundLine.fromMap(l as Map<String, dynamic>))
                .toList() ??
            const [],
        amount: Money.fromMap(map['amount'] as Map<String, dynamic>?),
        reason: map['reason'] as String? ?? '',
        tier: RefundTier.fromName(map['tier'] as String?),
        status: RefundStatus.fromName(map['status'] as String?),
        evidenceUrls: (map['evidenceUrls'] as List?)?.cast<String>() ?? const [],
        firstApproverId: map['firstApproverId'] as String?,
        secondApproverId: map['secondApproverId'] as String?,
        decisionNote: map['decisionNote'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
        resolvedAt: DateTime.tryParse(map['resolvedAt'] as String? ?? ''),
      );
}
