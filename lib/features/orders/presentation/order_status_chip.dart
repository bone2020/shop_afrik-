import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';

/// A small colored chip showing an order's high-level status.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OrderStatus.pendingPayment => ('Pending payment', AppColors.mutedText),
      OrderStatus.paid => ('Paid', AppColors.brightAqua),
      OrderStatus.processing => ('Processing', AppColors.brightAqua),
      OrderStatus.shipped => ('Shipped', AppColors.primaryTeal),
      OrderStatus.delivered => ('Delivered', AppColors.primaryTeal),
      OrderStatus.completed => ('Completed', AppColors.primaryTeal),
      OrderStatus.cancelled => ('Cancelled', AppColors.dangerCoral),
      OrderStatus.refunded => ('Refunded', AppColors.dangerCoral),
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
