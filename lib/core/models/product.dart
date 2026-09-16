import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'money.dart';

/// A catalog product (plan §7 `products`).
@immutable
class Product {
  const Product({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.price,
    required this.categoryId,
    required this.images,
    required this.stock,
    required this.initialStock,
    this.approvalStatus = ProductApprovalStatus.pending,
    this.isActive = true,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.lowStockThreshold,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String title;
  final String description;
  final Money price;
  final String categoryId;
  final List<String> images;
  final int stock;

  /// Stock at creation/restock, used to compute the low-stock threshold.
  final int initialStock;
  final ProductApprovalStatus approvalStatus;
  final bool isActive;
  final double ratingAverage;
  final int ratingCount;

  /// Seller-defined minimum quantity; falls back to a ratio of [initialStock]
  /// (plan §10) when null.
  final int? lowStockThreshold;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isOutOfStock => stock <= 0;

  /// Visible to buyers only when approved, active, and in stock.
  bool get isPurchasable =>
      approvalStatus == ProductApprovalStatus.approved && isActive && !isOutOfStock;

  Map<String, dynamic> toMap() => {
        'sellerId': sellerId,
        'title': title,
        'description': description,
        'price': price.toMap(),
        'categoryId': categoryId,
        'images': images,
        'stock': stock,
        'initialStock': initialStock,
        'approvalStatus': approvalStatus.name,
        'isActive': isActive,
        'ratingAverage': ratingAverage,
        'ratingCount': ratingCount,
        'lowStockThreshold': lowStockThreshold,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        sellerId: map['sellerId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        price: Money.fromMap(map['price'] as Map<String, dynamic>?),
        categoryId: map['categoryId'] as String? ?? '',
        images: (map['images'] as List?)?.cast<String>() ?? const [],
        stock: (map['stock'] as num?)?.toInt() ?? 0,
        initialStock: (map['initialStock'] as num?)?.toInt() ?? 0,
        approvalStatus:
            ProductApprovalStatus.fromName(map['approvalStatus'] as String?),
        isActive: map['isActive'] as bool? ?? true,
        ratingAverage: (map['ratingAverage'] as num?)?.toDouble() ?? 0,
        ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
      );
}
