import 'package:flutter/material.dart';

import '../../shared/presentation/role_scaffold.dart';

/// Admin landing screen (Phase 5 will flesh this out).
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleScaffold(
      title: 'Admin Console',
      subtitle: 'Approve sellers and products, manage refunds and commissions.',
      plannedFeatures: [
        'Seller and product approval queues',
        'Order overview',
        'Tiered refund approval and control',
        'Commission settings',
        'Audit logs and reports',
        'Role controls',
      ],
    );
  }
}
