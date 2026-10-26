import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/session_controller.dart';
import '../../notifications/presentation/notifications_bell.dart';
import 'admin_shipments_tab.dart';
import 'all_orders_tab.dart';
import 'audit_log_tab.dart';
import 'category_management_tab.dart';
import 'delivery_quote_tab.dart';
import 'platform_balances_view.dart';
import 'product_approval_tab.dart';
import 'refund_queue_tab.dart';
import 'seller_approval_tab.dart';
import 'settings_tab.dart';
import 'users_roles_tab.dart';

/// Admin console: platform balances, the work queues (deliveries, shipments,
/// products, sellers, refunds), and the back office: all orders, users and
/// roles, settings and the audit log.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 11,
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
              Tab(text: 'Shipments'),
              Tab(text: 'Products'),
              Tab(text: 'Categories'),
              Tab(text: 'Sellers'),
              Tab(text: 'Refunds'),
              Tab(text: 'Orders'),
              Tab(text: 'Users'),
              Tab(text: 'Settings'),
              Tab(text: 'Audit log'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PlatformBalancesView(),
            DeliveryQuoteTab(),
            AdminShipmentsTab(),
            ProductApprovalTab(),
            CategoryManagementTab(),
            SellerApprovalTab(),
            RefundQueueTab(),
            AllOrdersTab(),
            UsersRolesTab(),
            SettingsTab(),
            AuditLogTab(),
          ],
        ),
      ),
    );
  }
}
