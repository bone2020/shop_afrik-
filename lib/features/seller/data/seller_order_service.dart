import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seller order actions via Cloud Functions (orders are server-write-only).
abstract interface class SellerOrderService {
  /// Marks an order shipped. This is the cancellation cutoff.
  Future<void> markShipped(String orderId);
}

class FunctionsSellerOrderService implements SellerOrderService {
  FunctionsSellerOrderService(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> markShipped(String orderId) async {
    await _functions.httpsCallable('markShipped').call({'orderId': orderId});
  }
}

final sellerOrderServiceProvider = Provider<SellerOrderService>((ref) {
  return FunctionsSellerOrderService(FirebaseFunctions.instance);
});
