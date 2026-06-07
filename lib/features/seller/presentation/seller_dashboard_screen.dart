import 'package:flutter/material.dart';

import '../../shared/presentation/role_scaffold.dart';

/// Seller landing screen (Phase 4 will flesh this out).
class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleScaffold(
      title: 'Seller Dashboard',
      subtitle: 'Manage your store, products, orders, and payouts.',
      plannedFeatures: [
        'Seller onboarding with QR Wallet KYC',
        'Product create / read / update / delete',
        'Inventory and low-stock alerts',
        'Order management and status updates',
        'Sales and day-8 payout visibility',
      ],
    );
  }
}
