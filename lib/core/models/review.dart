import 'package:flutter/foundation.dart';

/// A verified-buyer product review (plan §7 `reviews`).
///
/// Only buyers with a delivered order containing the product may post a
/// review (enforced server-side), so [verifiedPurchase] is always true for
/// records written through the normal flow.
@immutable
class Review {
  const Review({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.orderId,
    required this.rating,
    required this.buyerName,
    this.comment,
    this.verifiedPurchase = true,
    this.createdAt,
  });

  final String id;
  final String productId;
  final String buyerId;
  final String orderId;

  /// 1–5 stars.
  final int rating;
  final String buyerName;
  final String? comment;
  final bool verifiedPurchase;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'buyerId': buyerId,
        'orderId': orderId,
        'rating': rating,
        'buyerName': buyerName,
        'comment': comment,
        'verifiedPurchase': verifiedPurchase,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(
        id: id,
        productId: map['productId'] as String? ?? '',
        buyerId: map['buyerId'] as String? ?? '',
        orderId: map['orderId'] as String? ?? '',
        rating: (map['rating'] as num?)?.toInt() ?? 0,
        buyerName: map['buyerName'] as String? ?? '',
        comment: map['comment'] as String?,
        verifiedPurchase: map['verifiedPurchase'] as bool? ?? true,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      );
}
