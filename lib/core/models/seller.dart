import 'package:flutter/foundation.dart';

import 'enums.dart';

/// A seller / store profile (plan §7 `sellers`).
@immutable
class Seller {
  const Seller({
    required this.id,
    required this.storeName,
    required this.ownerName,
    required this.market,
    this.qrWalletId,
    this.kycStatus = KycStatus.notStarted,
    this.approvalStatus = SellerApprovalStatus.pending,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.productCount = 0,
    this.logoUrl,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String storeName;
  final String ownerName;

  /// ISO country code of the seller's market (e.g. `GH`, `NG`).
  final String market;

  /// Link to the seller's QR Wallet account, used for KYC and payouts.
  final String? qrWalletId;
  final KycStatus kycStatus;
  final SellerApprovalStatus approvalStatus;
  final double ratingAverage;
  final int ratingCount;
  final int productCount;
  final String? logoUrl;
  final String? phone;
  final DateTime? createdAt;

  /// A seller may transact only when KYC is verified and the account is
  /// approved (plan §6 "Seller KYC required before approval").
  bool get canSell =>
      kycStatus == KycStatus.verified &&
      approvalStatus == SellerApprovalStatus.approved;

  Map<String, dynamic> toMap() => {
        'storeName': storeName,
        'ownerName': ownerName,
        'market': market,
        'qrWalletId': qrWalletId,
        'kycStatus': kycStatus.name,
        'approvalStatus': approvalStatus.name,
        'ratingAverage': ratingAverage,
        'ratingCount': ratingCount,
        'productCount': productCount,
        'logoUrl': logoUrl,
        'phone': phone,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Seller.fromMap(String id, Map<String, dynamic> map) => Seller(
        id: id,
        storeName: map['storeName'] as String? ?? '',
        ownerName: map['ownerName'] as String? ?? '',
        market: map['market'] as String? ?? '',
        qrWalletId: map['qrWalletId'] as String?,
        kycStatus: KycStatus.fromName(map['kycStatus'] as String?),
        approvalStatus:
            SellerApprovalStatus.fromName(map['approvalStatus'] as String?),
        ratingAverage: (map['ratingAverage'] as num?)?.toDouble() ?? 0,
        ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
        productCount: (map['productCount'] as num?)?.toInt() ?? 0,
        logoUrl: map['logoUrl'] as String?,
        phone: map['phone'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
      );
}
