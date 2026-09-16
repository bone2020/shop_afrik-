import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/platform_settings_repository.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/money.dart';
import '../../../core/models/order.dart';
import '../../../core/models/platform_settings.dart';
import '../../../services/session_controller.dart';
import '../../orders/data/orders_repository.dart';

/// Computes how much a seller is owed (payable), grouped **by currency**, from
/// their delivered orders whose settlement is still pending. Net = the seller's
/// share of the subtotal less commission (rate from config). Currencies are
/// never blended; each is summed in its own minor units.
Map<String, Money> computeSellerPayable({
  required List<ShopOrder> orders,
  required String sellerId,
  required PlatformSettings settings,
}) {
  final minorByCurrency = <String, int>{};
  final rate = settings.commissionRate;

  for (final order in orders) {
    final pending = order.settlementStatus == SettlementStatus.scheduled ||
        order.settlementStatus == SettlementStatus.onHold;
    if (!pending) continue;

    for (final item in order.items) {
      if (item.sellerId != sellerId) continue;
      final remaining = item.quantity - item.refundedQuantity;
      if (remaining <= 0) continue;
      final gross = item.unitPrice.minorUnits * remaining;
      final net = (gross * (1 - rate)).round();
      final currency = item.unitPrice.currency;
      minorByCurrency[currency] = (minorByCurrency[currency] ?? 0) + net;
    }
  }

  return {
    for (final entry in minorByCurrency.entries)
      entry.key: Money(minorUnits: entry.value, currency: entry.key),
  };
}

/// Per-currency payable for the signed-in seller.
final sellerPayableProvider =
    Provider.autoDispose<AsyncValue<Map<String, Money>>>((ref) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return const AsyncData({});

  final settings = ref.watch(platformSettingsProvider).valueOrNull ??
      const PlatformSettings();
  final ordersAsync = ref.watch(sellerOrdersProvider(uid));

  return ordersAsync.whenData((orders) => computeSellerPayable(
        orders: orders,
        sellerId: uid,
        settings: settings,
      ));
});

/// The signed-in seller's orders.
final sellerOrdersProvider = StreamProvider.autoDispose
    .family((ref, String sellerId) =>
        ref.watch(ordersRepositoryProvider).watchSellerOrders(sellerId));
