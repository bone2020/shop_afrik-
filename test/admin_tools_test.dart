import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/data/platform_settings_repository.dart';
import 'package:shop_afrik/core/models/admin_audit_entry.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/models/order.dart';
import 'package:shop_afrik/core/models/platform_settings.dart';
import 'package:shop_afrik/core/models/staff_member.dart';
import 'package:shop_afrik/core/models/user_role.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/admin/data/admin_tools_repository.dart';
import 'package:shop_afrik/features/admin/presentation/all_orders_tab.dart';
import 'package:shop_afrik/features/admin/presentation/audit_log_tab.dart';
import 'package:shop_afrik/features/admin/presentation/settings_tab.dart';
import 'package:shop_afrik/features/admin/presentation/users_roles_tab.dart';
import 'package:shop_afrik/services/session_controller.dart';

import 'support/fixtures.dart';
import 'support/session.dart';

class _FakeTools implements AdminToolsRepository {
  _FakeTools({this.users = const {}, this.orders = const [], this.audit = const []});
  final Map<String, FoundUser> users;
  final List<ShopOrder> orders;
  final List<AdminAuditEntry> audit;

  final roleCalls = <(String, String, String?)>[];
  final settingsPatches = <Map<String, dynamic>>[];
  final orderFilters = <OrderFilter>[];
  final auditFilters = <AuditFilter>[];

  @override
  Future<FoundUser?> findUser(String query) async => users[query];
  @override
  Future<void> setUserRole(
          {required String uid, required String role, String? adminTier}) async =>
      roleCalls.add((uid, role, adminTier));
  @override
  Stream<List<StaffMember>> watchStaff() => Stream.value(const [
        StaffMember(uid: 'c1', role: 'delivery', displayName: 'Kofi Courier'),
      ]);
  @override
  Future<void> updateSettings(Map<String, dynamic> patch) async =>
      settingsPatches.add(patch);
  @override
  Future<ShopOrder?> getOrder(String orderId) async {
    for (final o in orders) {
      if (o.id == orderId) return o;
    }
    return null;
  }

  @override
  Future<AdminPage<ShopOrder>> fetchOrders(OrderFilter filter,
      {Object? cursor}) async {
    orderFilters.add(filter);
    return AdminPage(orders, null, hasMore: false);
  }

  @override
  Future<AdminPage<AdminAuditEntry>> fetchAudit(AuditFilter filter,
      {Object? cursor}) async {
    auditFilters.add(filter);
    final list = filter.action == null
        ? audit
        : audit.where((e) => e.action == filter.action).toList();
    return AdminPage(list, null, hasMore: false);
  }
}

Session _admin({bool supervisor = false}) => Session(
      uid: 'me',
      role: UserRole.admin,
      adminTier: supervisor ? AdminTier.supervisor : AdminTier.admin,
    );

Future<void> _pump(WidgetTester tester, Widget child, _FakeTools repo,
    {Session? session}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      stubSession(session ?? _admin(supervisor: true)),
      adminToolsRepositoryProvider.overrideWithValue(repo),
      platformSettingsProvider
          .overrideWith((ref) => Stream.value(const PlatformSettings())),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

/// Scrolls the settings page to the bottom and taps Save.
Future<void> _save(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.scrollUntilVisible(find.text('Save settings'), 300,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save settings'));
}

const _ama = FoundUser(uid: 'u1', role: 'buyer', email: 'ama@test.dev');

void main() {
  group('Users and roles (SA-132)', () {
    testWidgets('a supervisor finds a user and makes them a courier',
        (tester) async {
      final repo = _FakeTools(users: {'ama@test.dev': _ama});
      await _pump(tester, const UsersRolesTab(), repo);
      expect(find.text('Kofi Courier'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ama@test.dev');
      await tester.tap(find.byTooltip('Find'));
      await tester.pumpAndSettle();
      expect(find.text('Current role: No staff role'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<StaffRoleChoice>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Courier').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(repo.roleCalls, [('u1', 'delivery', null)]);
      expect(find.text('Current role: Courier'), findsOneWidget);
    });

    testWidgets('an ordinary admin can look up but not change roles',
        (tester) async {
      final repo = _FakeTools(users: {'ama@test.dev': _ama});
      await _pump(tester, const UsersRolesTab(), repo, session: _admin());
      await tester.enterText(find.byType(TextField), 'ama@test.dev');
      await tester.tap(find.byTooltip('Find'));
      await tester.pumpAndSettle();

      expect(find.text('Only a supervisor can change roles.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
    });

    testWidgets('nobody can change their own role', (tester) async {
      final repo = _FakeTools(users: {
        'me': const FoundUser(uid: 'me', role: 'admin', adminTier: 'supervisor'),
      });
      await _pump(tester, const UsersRolesTab(), repo);
      await tester.enterText(find.byType(TextField), 'me');
      await tester.tap(find.byTooltip('Find'));
      await tester.pumpAndSettle();
      expect(find.text('You cannot change your own role.'), findsOneWidget);
    });
  });

  group('Settings (SA-133)', () {
    testWidgets('a supervisor saves only what changed', (tester) async {
      final repo = _FakeTools();
      await _pump(tester, const SettingsTab(), repo);

      await tester.enterText(
          find.widgetWithText(TextField, 'Commission'), '12.5');
      await _save(tester);
      await tester.pumpAndSettle();

      expect(repo.settingsPatches, [
        {'commissionRate': 0.125},
      ]);
    });

    testWidgets('switching a market off sends the markets', (tester) async {
      final repo = _FakeTools();
      await _pump(tester, const SettingsTab(), repo);
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      await _save(tester);
      await tester.pumpAndSettle();

      final markets = repo.settingsPatches.single['markets'] as Map;
      expect(markets.values.where((m) => m['enabled'] == false).length, 1);
    });

    testWidgets('other admins see settings read-only', (tester) async {
      await _pump(tester, const SettingsTab(), _FakeTools(), session: _admin());
      expect(find.text('Only a supervisor can change settings.'), findsOneWidget);
      expect(find.text('Save settings'), findsNothing);
      final commission =
          tester.widget<TextField>(find.widgetWithText(TextField, 'Commission'));
      expect(commission.enabled, isFalse);
    });
  });

  group('All orders (SA-134)', () {
    final order = testOrder(
      id: 'ORDER123',
      settlement: SettlementStatus.notDue,
      items: [testItem(sellerId: 's1', unitPriceMinor: 5000, currency: 'GHS')],
    );

    testWidgets('lists orders and finds one by id', (tester) async {
      final repo = _FakeTools(orders: [order]);
      await _pump(tester, const AllOrdersTab(), repo);
      expect(find.text('ORDER123'), findsOneWidget);
      expect(repo.orderFilters.single, const OrderFilter());

      await tester.enterText(find.byType(TextField), 'ORDER123');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      // Shown expanded, with the buyer.
      expect(find.text('Buyer: buyer1'), findsOneWidget);
    });

    testWidgets('searching an email shows that buyer\'s orders',
        (tester) async {
      final repo = _FakeTools(orders: [order], users: {'ama@test.dev': _ama});
      await _pump(tester, const AllOrdersTab(), repo);
      await tester.enterText(find.byType(TextField), 'ama@test.dev');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();

      expect(repo.orderFilters.last, const OrderFilter(buyerId: 'u1'));
      expect(find.text('Orders where ama@test.dev is the buyer'), findsOneWidget);
    });
  });

  group('Audit log (SA-135)', () {
    testWidgets('lists entries and filters by action', (tester) async {
      final repo = _FakeTools(audit: [
        AdminAuditEntry(
          id: 'a1',
          actorId: 'super1',
          action: 'settings.updated',
          targetType: 'settings',
          targetId: 'platform',
          metadata: const {'changed': ['commissionRate']},
          createdAt: DateTime(2026, 11, 2, 9, 30),
        ),
        const AdminAuditEntry(id: 'a2', actorId: 'system', action: 'settlement.paid'),
      ]);
      await _pump(tester, const AuditLogTab(), repo);
      expect(find.text('settings.updated'), findsOneWidget);
      expect(find.text('settlement.paid'), findsOneWidget);

      await tester.tap(find.text('Everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Action').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'settings.updated');
      await tester.tap(find.byTooltip('Filter'));
      await tester.pumpAndSettle();

      expect(repo.auditFilters.last, const AuditFilter(action: 'settings.updated'));
      expect(find.text('settlement.paid'), findsNothing);

      await tester.tap(find.widgetWithText(ExpansionTile, 'settings.updated'));
      await tester.pumpAndSettle();
      expect(find.text('changed: [commissionRate]'), findsOneWidget);
    });
  });
}
