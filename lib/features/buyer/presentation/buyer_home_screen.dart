import 'package:flutter/material.dart';

import '../../shared/presentation/role_scaffold.dart';

/// Buyer landing screen (Phase 3 will flesh this out).
class BuyerHomeScreen extends StatelessWidget {
  const BuyerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleScaffold(
      title: 'Shop Afrik',
      subtitle: 'Discover products, pay with QR Wallet, track your orders.',
      plannedFeatures: [
        'Home, categories, and search',
        'Product detail and reviews',
        'Cart and QR Wallet checkout',
        'Orders and delivery tracking',
        'Refund requests within the 7-day window',
        'Wishlist',
      ],
    );
  }
}
