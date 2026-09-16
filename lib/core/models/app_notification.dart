import 'package:flutter/foundation.dart';

import 'enums.dart';

/// An in-app notification record (plan §7 `notifications`).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.audience,
    required this.title,
    required this.body,
    this.type,
    this.deepLink,
    this.isRead = false,
    this.createdAt,
  });

  final String id;

  /// The user (buyer/seller/admin) the notification belongs to.
  final String recipientId;
  final NotificationAudience audience;
  final String title;
  final String body;

  /// Logical category, e.g. `order_paid`, `refund_decision`, `settlement`.
  final String? type;
  final String? deepLink;
  final bool isRead;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'recipientId': recipientId,
        'audience': audience.name,
        'title': title,
        'body': body,
        'type': type,
        'deepLink': deepLink,
        'isRead': isRead,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        recipientId: map['recipientId'] as String? ?? '',
        audience: NotificationAudience.fromName(map['audience'] as String?),
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        type: map['type'] as String?,
        deepLink: map['deepLink'] as String?,
        isRead: map['isRead'] as bool? ?? false,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      );
}
