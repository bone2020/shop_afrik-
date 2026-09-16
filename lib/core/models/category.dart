import 'package:flutter/foundation.dart';

/// A catalog category for browse and filtering (plan §7 `categories`).
///
/// Categories form a shallow tree: a top-level category has a null [parentId];
/// sub-categories reference their parent.
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    this.parentId,
    this.iconName,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? parentId;
  final String? iconName;
  final int sortOrder;
  final bool isActive;

  bool get isTopLevel => parentId == null;

  Map<String, dynamic> toMap() => {
        'name': name,
        'parentId': parentId,
        'iconName': iconName,
        'sortOrder': sortOrder,
        'isActive': isActive,
      };

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
        id: id,
        name: map['name'] as String? ?? '',
        parentId: map['parentId'] as String?,
        iconName: map['iconName'] as String?,
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
        isActive: map['isActive'] as bool? ?? true,
      );
}
