import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/models/app_notification.dart';
import 'package:shop_afrik/core/models/enums.dart';
import 'package:shop_afrik/core/theme/app_theme.dart';
import 'package:shop_afrik/features/notifications/data/notifications_repository.dart';
import 'package:shop_afrik/features/notifications/presentation/notifications_screen.dart';

void main() {
  testWidgets('renders notification history', (tester) async {
    final items = [
      const AppNotification(
        id: 'n1',
        recipientId: 'u1',
        audience: NotificationAudience.buyer,
        title: 'Delivery quoted',
        body: 'Your delivery price is ready.',
      ),
      const AppNotification(
        id: 'n2',
        recipientId: 'u1',
        audience: NotificationAudience.buyer,
        title: 'Order shipped',
        body: 'Your order is on its way.',
        isRead: true,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => Stream.value(items)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delivery quoted'), findsOneWidget);
    expect(find.text('Order shipped'), findsOneWidget);
  });
}
