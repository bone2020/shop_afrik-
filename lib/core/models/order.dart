import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'money.dart';

/// A single line in an order. Product details are denormalized so the order is
/// a stable historical record even if the product later changes.
@immutable
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.sellerId,
    required this.title,
    required this.unitPrice,
    required this.quantity,
    this.imageUrl,
    this.refundedQuantity = 0,
  });

  final String productId;
  final String sellerId;
  final String title;
  final Money unitPrice;
  final int quantity;
  final String? imageUrl;

  /// How many units of this line have been refunded (partial refunds, §6).
  final int refundedQuantity;

  Money get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'sellerId': sellerId,
        'title': title,
        'unitPrice': unitPrice.toMap(),
        'quantity': quantity,
        'imageUrl': imageUrl,
        'refundedQuantity': refundedQuantity,
      };

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        productId: map['productId'] as String? ?? '',
        sellerId: map['sellerId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        unitPrice: Money.fromMap(map['unitPrice'] as Map<String, dynamic>?),
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        imageUrl: map['imageUrl'] as String?,
        refundedQuantity: (map['refundedQuantity'] as num?)?.toInt() ?? 0,
      );
}

/// A buyer order (plan §7 `orders`). Tracks payment, delivery, and settlement
/// legs independently (plan §5 flow, §6 settlement).
@immutable
class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.buyerId,
    required this.items,
    required this.subtotal,
    required this.paymentFee,
    required this.total,
    this.deliveryFee,
    this.status = OrderStatus.pendingPayment,
    this.paymentStatus = PaymentStatus.pending,
    this.deliveryStatus = DeliveryStatus.notDispatched,
    this.settlementStatus = SettlementStatus.notDue,
    this.qrWalletTxnId,
    this.deliveryConfirmedAt,
    this.settlementDueAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String buyerId;
  final List<OrderItem> items;

  // Totals. The buyer pays the payment processing fee as a separate line item
  // (plan §6). [total] is the up-front amount and intentionally EXCLUDES
  // delivery: delivery is admin-set per order (not auto-calculated), and the
  // product-vs-quote checkout flow that decides when/how it is charged is not
  // yet finalized.
  final Money subtotal;
  final Money paymentFee;
  final Money total;

  /// Admin-set delivery amount, populated once a delivery quote is agreed.
  /// Null until then; never auto-derived from a flat market fee.
  final Money? deliveryFee;

  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DeliveryStatus deliveryStatus;
  final SettlementStatus settlementStatus;

  /// QR Wallet transaction that paid this order (plan §5 step 5).
  final String? qrWalletTxnId;

  /// When the courier confirmed delivery — starts the 7-day refund window.
  final DateTime? deliveryConfirmedAt;

  /// When auto-settlement is due (delivery + 8 days, plan §6).
  final DateTime? settlementDueAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Distinct sellers represented in this order (multi-seller carts).
  Set<String> get sellerIds => {for (final i in items) i.sellerId};

  bool get isMultiItem => items.length > 1;

  Map<String, dynamic> toMap() => {
        'buyerId': buyerId,
        'items': items.map((i) => i.toMap()).toList(),
        'sellerIds': sellerIds.toList(),
        'subtotal': subtotal.toMap(),
        'paymentFee': paymentFee.toMap(),
        'deliveryFee': deliveryFee?.toMap(),
        'total': total.toMap(),
        'status': status.name,
        'paymentStatus': paymentStatus.name,
        'deliveryStatus': deliveryStatus.name,
        'settlementStatus': settlementStatus.name,
        'qrWalletTxnId': qrWalletTxnId,
        'deliveryConfirmedAt': deliveryConfirmedAt?.toIso8601String(),
        'settlementDueAt': settlementDueAt?.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ShopOrder.fromMap(String id, Map<String, dynamic> map) => ShopOrder(
        id: id,
        buyerId: map['buyerId'] as String? ?? '',
        items: (map['items'] as List?)
                ?.map((i) => OrderItem.fromMap(i as Map<String, dynamic>))
                .toList() ??
            const [],
        subtotal: Money.fromMap(map['subtotal'] as Map<String, dynamic>?),
        paymentFee: Money.fromMap(map['paymentFee'] as Map<String, dynamic>?),
        deliveryFee: map['deliveryFee'] == null
            ? null
            : Money.fromMap(map['deliveryFee'] as Map<String, dynamic>?),
        total: Money.fromMap(map['total'] as Map<String, dynamic>?),
        status: OrderStatus.fromName(map['status'] as String?),
        paymentStatus: PaymentStatus.fromName(map['paymentStatus'] as String?),
        deliveryStatus:
            DeliveryStatus.fromName(map['deliveryStatus'] as String?),
        settlementStatus:
            SettlementStatus.fromName(map['settlementStatus'] as String?),
        qrWalletTxnId: map['qrWalletTxnId'] as String?,
        deliveryConfirmedAt:
            DateTime.tryParse(map['deliveryConfirmedAt'] as String? ?? ''),
        settlementDueAt:
            DateTime.tryParse(map['settlementDueAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
      );
}
