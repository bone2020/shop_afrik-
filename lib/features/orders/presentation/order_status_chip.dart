import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';

/// Human-readable name of an order status.
String orderStatusLabel(OrderStatus status) => switch (status) {
      OrderStatus.awaitingDeliveryQuote => 'Awaiting delivery quote',
      OrderStatus.awaitingPayment => 'Awaiting payment',
      OrderStatus.confirmed => 'Confirmed',
      OrderStatus.shipped => 'Shipped',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
      OrderStatus.refunded => 'Refunded',
    };

/// A small colored chip showing an order's high-level status.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final label = orderStatusLabel(status);
    final color = switch (status) {
      OrderStatus.awaitingDeliveryQuote => AppColors.mutedText,
      OrderStatus.awaitingPayment || OrderStatus.confirmed =>
        AppColors.brightAqua,
      OrderStatus.shipped ||
      OrderStatus.delivered ||
      OrderStatus.completed =>
        AppColors.primaryTeal,
      OrderStatus.cancelled || OrderStatus.refunded => AppColors.dangerCoral,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
