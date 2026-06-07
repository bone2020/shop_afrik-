import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/money.dart';
import 'package:shop_afrik/core/models/platform_balance.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/admin/data/platform_balance_repository.dart';
import 'package:shop_afrik/features/admin/presentation/admin_dashboard_screen.dart';

class _FakeRepo implements PlatformBalanceRepository {
  _FakeRepo(this.rows);
  final List<PlatformBalance> rows;
  @override
  Stream<List<PlatformBalance>> watchBalances() => Stream.value(rows);
}

void main() {
  testWidgets('shows three buckets per currency, only commission as revenue',
      (tester) async {
    final rows = [
      const PlatformBalance(
        currency: 'NGN',
        escrow: Money(minorUnits: 500000, currency: 'NGN'),
        payable: Money(minorUnits: 200000, currency: 'NGN'),
        commission: Money(minorUnits: 75000, currency: 'NGN'),
      ),
      const PlatformBalance(
        currency: 'TND',
        escrow: Money(minorUnits: 12345, currency: 'TND'),
        payable: Money(minorUnits: 0, currency: 'TND'),
        commission: Money(minorUnits: 2000, currency: 'TND'),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformBalanceRepositoryProvider.overrideWithValue(_FakeRepo(rows)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both currencies render as separate cards (never blended).
    expect(find.text('NGN'), findsOneWidget);
    expect(find.text('TND'), findsOneWidget);

    // The three buckets appear for each currency.
    expect(find.text('Held in escrow'), findsNWidgets(2));
    expect(find.text('Owed to sellers'), findsNWidgets(2));
    expect(find.text('Commission earned'), findsNWidgets(2));

    // Only commission is labeled revenue.
    expect(find.text('Revenue'), findsNWidgets(2));

    // TND respects its 3-decimal exponent in formatting.
    expect(find.text('TND 12.345'), findsOneWidget);
    // NGN commission formatted with 2 decimals.
    expect(find.text('NGN 750.00'), findsOneWidget);
  });
}
