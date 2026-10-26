import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/money.dart';
import '../../../core/models/product.dart';

/// One line in the buyer's cart (a product + quantity).
@immutable
class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  Money get lineTotal => product.price * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);
}

/// The buyer's cart. A cart holds a single currency: products are priced in
/// their seller's market currency, and money is never blended across
/// currencies, so a product from a different currency cannot be added.
/// [cartSyncProvider] saves it to the buyer's profile and restores it on
/// sign-in (SA-045).
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  /// The currency the cart is locked to, or null when empty.
  String? get currency =>
      state.isEmpty ? null : state.first.product.price.currency;

  /// Whether [product] can join the cart (same currency, or empty cart).
  bool canAdd(Product product) =>
      currency == null || product.price.currency == currency;

  void add(Product product, {int quantity = 1}) {
    if (!canAdd(product)) return;
    final idx = state.indexWhere((l) => l.product.id == product.id);
    if (idx >= 0) {
      final updated = [...state];
      updated[idx] =
          updated[idx].copyWith(quantity: updated[idx].quantity + quantity);
      state = updated;
    } else {
      state = [...state, CartLine(product: product, quantity: quantity)];
    }
  }

  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    state = [
      for (final l in state)
        if (l.product.id == productId) l.copyWith(quantity: quantity) else l,
    ];
  }

  void remove(String productId) =>
      state = state.where((l) => l.product.id != productId).toList();

  void clear() => state = const [];

  /// Adds saved [lines] behind anything already in the cart, skipping
  /// products already present or in another currency.
  void restore(List<CartLine> lines) {
    var next = [...state];
    for (final l in lines) {
      final cur = next.isEmpty ? null : next.first.product.price.currency;
      if (next.any((x) => x.product.id == l.product.id)) continue;
      if (cur != null && l.product.price.currency != cur) continue;
      next = [...next, l];
    }
    state = next;
  }
}

final cartProvider =
    NotifierProvider<CartController, List<CartLine>>(CartController.new);

/// Total item count (sum of quantities).
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold(0, (sum, l) => sum + l.quantity);
});

/// Cart subtotal in the cart's single currency, or null when empty.
final cartSubtotalProvider = Provider<Money?>((ref) {
  final lines = ref.watch(cartProvider);
  if (lines.isEmpty) return null;
  return lines
      .map((l) => l.lineTotal)
      .reduce((a, b) => a + b); // throws if currencies ever differ — they can't
});
