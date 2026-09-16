import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/order.dart';

class CartItemRef {
  const CartItemRef({required this.productId, required this.quantity});
  final String productId;
  final int quantity;
}

/// Buyer-facing order actions, all via Cloud Functions (orders are
/// server-write-only). Money moves go through the inert QR Wallet seam — these
/// surface the real outcome and never fake success.
abstract interface class OrderService {
  /// Places an order (no money held); returns the new order id. The order
  /// starts in `awaitingDeliveryQuote`.
  Future<String> placeOrder({
    required List<CartItemRef> items,
    required DeliveryLocation deliveryLocation,
  });

  /// Pays a quoted order with the chosen method (money-in via the seam).
  Future<void> payOrder({
    required String orderId,
    required PaymentMethod method,
  });

  /// Cancels an order (allowed only before it ships).
  Future<void> cancelOrder(String orderId);
}

class FunctionsOrderService implements OrderService {
  FunctionsOrderService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<String> placeOrder({
    required List<CartItemRef> items,
    required DeliveryLocation deliveryLocation,
  }) async {
    final res = await _functions.httpsCallable('createOrder').call<Map<String, dynamic>>({
      'items': [
        for (final i in items)
          {'productId': i.productId, 'quantity': i.quantity},
      ],
      'deliveryLocation': deliveryLocation.toMap(),
    });
    return res.data['orderId'] as String? ?? '';
  }

  @override
  Future<void> payOrder({
    required String orderId,
    required PaymentMethod method,
  }) async {
    await _functions.httpsCallable('payOrder').call({
      'orderId': orderId,
      'method': method.name,
    });
  }

  @override
  Future<void> cancelOrder(String orderId) async {
    await _functions.httpsCallable('cancelOrder').call({'orderId': orderId});
  }
}

final orderServiceProvider = Provider<OrderService>((ref) {
  return FunctionsOrderService(FirebaseFunctions.instance);
});
