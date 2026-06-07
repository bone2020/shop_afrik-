import 'package:flutter/foundation.dart';

/// A shipping/contact address (plan §7 `buyers` -> addresses).
@immutable
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.market,
    this.line2,
    this.region,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String recipientName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String? region;

  /// ISO country code of the delivery market.
  final String market;
  final bool isDefault;

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'recipientName': recipientName,
        'phone': phone,
        'line1': line1,
        'line2': line2,
        'city': city,
        'region': region,
        'market': market,
        'isDefault': isDefault,
      };

  factory Address.fromMap(Map<String, dynamic> map) => Address(
        id: map['id'] as String? ?? '',
        label: map['label'] as String? ?? '',
        recipientName: map['recipientName'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        line1: map['line1'] as String? ?? '',
        line2: map['line2'] as String?,
        city: map['city'] as String? ?? '',
        region: map['region'] as String?,
        market: map['market'] as String? ?? '',
        isDefault: map['isDefault'] as bool? ?? false,
      );
}

/// A buyer / customer profile (plan §7 `buyers`).
@immutable
class Buyer {
  const Buyer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.addresses = const [],
    this.wishlist = const [],
    this.pushEnabled = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final List<Address> addresses;

  /// Product IDs saved to the wishlist.
  final List<String> wishlist;
  final bool pushEnabled;
  final DateTime? createdAt;

  Address? get defaultAddress {
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'addresses': addresses.map((a) => a.toMap()).toList(),
        'wishlist': wishlist,
        'pushEnabled': pushEnabled,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Buyer.fromMap(String id, Map<String, dynamic> map) => Buyer(
        id: id,
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        addresses: (map['addresses'] as List?)
                ?.map((a) => Address.fromMap(a as Map<String, dynamic>))
                .toList() ??
            const [],
        wishlist: (map['wishlist'] as List?)?.cast<String>() ?? const [],
        pushEnabled: map['pushEnabled'] as bool? ?? true,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      );
}
