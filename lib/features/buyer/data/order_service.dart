import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of creating an order. [paymentConfigured] is false while the QR
/// Wallet seam is inert — the order is recorded as pending payment, but no
/// payment can be collected yet. We never fabricate a successful payment.
class CreateOrderResult {
  const CreateOrderResult({
    required this.orderId,
    required this.paymentConfigured,
    this.message,
  });

  final String orderId;
  final bool paymentConfigured;
  final String? message;
}

class CartItemRef {
  const CartItemRef({required this.productId, required this.quantity});
  final String productId;
  final int quantity;
}

/// Creates orders via the `createOrder` Cloud Function (which computes the
/// authoritative totals and talks to the QR Wallet seam).
abstract interface class OrderService {
  Future<CreateOrderResult> createOrder({
    required List<CartItemRef> items,
    required String market,
  });
}

class FunctionsOrderService implements OrderService {
  FunctionsOrderService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<CreateOrderResult> createOrder({
    required List<CartItemRef> items,
    required String market,
  }) async {
    final callable = _functions.httpsCallable('createOrder');
    final res = await callable.call<Map<String, dynamic>>({
      'items': [
        for (final i in items)
          {'productId': i.productId, 'quantity': i.quantity},
      ],
      'market': market,
    });
    final data = res.data;
    return CreateOrderResult(
      orderId: data['orderId'] as String? ?? '',
      paymentConfigured: data['paymentConfigured'] as bool? ?? false,
      message: data['message'] as String?,
    );
  }
}

final orderServiceProvider = Provider<OrderService>((ref) {
  return FunctionsOrderService(FirebaseFunctions.instance);
});
