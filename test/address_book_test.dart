import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/buyer.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/buyer/data/buyer_repository.dart';
import 'package:shop_afrik/features/buyer/presentation/address_book_screen.dart';

import 'support/session.dart';

void main() {
  testWidgets('lists saved addresses with a default badge', (tester) async {
    const buyer = Buyer(
      id: 'u1',
      name: 'Ada',
      addresses: [
        Address(
          id: 'a1',
          label: 'Home',
          recipientName: 'Ada',
          phone: '+234800',
          line1: '1 Market Rd',
          city: 'Lagos',
          market: 'NG',
          isDefault: true,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stubSession(),
          currentBuyerProvider.overrideWith((ref) => Stream.value(buyer)),
        ],
        child: const MaterialApp(home: AddressBookScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('empty state prompts to add', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stubSession(),
          currentBuyerProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const AddressBookScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No saved addresses'), findsOneWidget);
  });
}
