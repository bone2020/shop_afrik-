import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/money.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/models/product.dart';

/// Builds a minimal approved, in-stock product for tests.
Product testProduct({
  required String id,
  required String sellerId,
  required int priceMinor,
  required String currency,
  int stock = 10,
}) {
  return Product(
    id: id,
    sellerId: sellerId,
    title: 'Product $id',
    description: 'desc',
    price: Money(minorUnits: priceMinor, currency: currency),
    categoryId: 'cat1',
    images: const [],
    stock: stock,
    initialStock: stock,
    approvalStatus: ProductApprovalStatus.approved,
  );
}

/// Builds an order line for a seller.
OrderItem testItem({
  required String sellerId,
  required int unitPriceMinor,
  required String currency,
  int quantity = 1,
  int refundedQuantity = 0,
}) {
  return OrderItem(
    productId: 'p',
    sellerId: sellerId,
    title: 'item',
    unitPrice: Money(minorUnits: unitPriceMinor, currency: currency),
    quantity: quantity,
    refundedQuantity: refundedQuantity,
  );
}

ShopOrder testOrder({
  required String id,
  required List<OrderItem> items,
  required SettlementStatus settlement,
}) {
  final currency = items.first.unitPrice.currency;
  final subtotal = items.map((i) => i.lineTotal).reduce((a, b) => a + b);
  return ShopOrder(
    id: id,
    buyerId: 'buyer1',
    items: items,
    subtotal: subtotal,
    paymentFee: Money.zero(currency),
    total: subtotal,
    settlementStatus: settlement,
  );
}
