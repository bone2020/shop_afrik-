import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/app.dart';

void main() {
  testWidgets('App boots to the sign-in / role picker screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShopAfrikApp()));
    await tester.pumpAndSettle();

    expect(find.text('Shop Afrik'), findsWidgets);
    expect(find.text('Buyer'), findsOneWidget);
    expect(find.text('Seller'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('Choosing a role routes into that role section',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShopAfrikApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seller'));
    await tester.pumpAndSettle();

    expect(find.text('Seller Dashboard'), findsOneWidget);
  });
}
