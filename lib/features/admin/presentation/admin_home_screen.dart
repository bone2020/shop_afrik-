import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/session_controller.dart';
import '../../notifications/presentation/notifications_bell.dart';
import 'delivery_quote_tab.dart';
import 'platform_balances_view.dart';
import 'refund_queue_tab.dart';
import 'seller_approval_tab.dart';

/// Admin console: platform balances, the seller-approval queue, and the
/// refund-approval queue.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Console'),
          actions: [
            const NotificationsBell(),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(sessionControllerProvider.notifier).signOut(),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Balances'),
              Tab(text: 'Deliveries'),
              Tab(text: 'Sellers'),
              Tab(text: 'Refunds'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PlatformBalancesView(),
            DeliveryQuoteTab(),
            SellerApprovalTab(),
            RefundQueueTab(),
          ],
        ),
      ),
    );
  }
}
