import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/app.dart';
import 'package:shop_afrik/core/models/user_role.dart';

import 'support/session.dart';

void main() {
  testWidgets('unauthenticated session lands on the sign-in screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stubSession()],
        child: const ShopAfrikApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Real auth UI, not the old role picker.
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);
  });

  testWidgets('an authenticated buyer is routed into the buyer shell',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stubSession(authedSession(UserRole.buyer))],
        child: const ShopAfrikApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Buyer shell shows its bottom-nav destinations; the sign-in form is gone.
    expect(find.text('Cart'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('Phone'), findsNothing);
  });
}
