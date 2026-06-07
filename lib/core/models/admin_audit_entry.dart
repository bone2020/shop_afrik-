import 'package:flutter/foundation.dart';

/// An append-only audit record for admin and financial actions (plan §7
/// `admin_audit`). These are written server-side only and are never updated
/// or deleted (enforced in the security rules).
@immutable
class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.actorId,
    required this.action,
    this.targetType,
    this.targetId,
    this.metadata = const {},
    this.createdAt,
  });

  final String id;

  /// The admin (or `system` for automated jobs) who performed the action.
  final String actorId;

  /// Verb describing what happened, e.g. `seller.approved`,
  /// `refund.tier2.approved`, `settlement.paid`.
  final String action;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'actorId': actorId,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'metadata': metadata,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory AdminAuditEntry.fromMap(String id, Map<String, dynamic> map) =>
      AdminAuditEntry(
        id: id,
        actorId: map['actorId'] as String? ?? '',
        action: map['action'] as String? ?? '',
        targetType: map['targetType'] as String?,
        targetId: map['targetId'] as String?,
        metadata: (map['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      );
}
