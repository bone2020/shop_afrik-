import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_notification.dart';
import '../../../core/theme/app_colors.dart';
import '../data/notifications_repository.dart';

/// In-app notification history (delivery quoted, shipped, delivered, cancelled,
/// refunded, etc.). Tapping an unread item marks it read.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load notifications.\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.mutedText)),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No notifications yet.',
                    style: TextStyle(color: AppColors.mutedText)))
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, i) => _Tile(notification: items[i], ref: ref),
              ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.notification, required this.ref});

  final AppNotification notification;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        notification.isRead
            ? Icons.notifications_none
            : Icons.notifications_active,
        color: notification.isRead
            ? AppColors.mutedText
            : AppColors.primaryTeal,
      ),
      title: Text(notification.title,
          style: TextStyle(
              fontWeight:
                  notification.isRead ? FontWeight.normal : FontWeight.w600)),
      subtitle: Text(notification.body),
      onTap: notification.isRead
          ? null
          : () => ref
              .read(notificationsRepositoryProvider)
              .markRead(notification.id),
    );
  }
}
