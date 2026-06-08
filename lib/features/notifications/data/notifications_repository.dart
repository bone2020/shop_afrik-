import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/app_notification.dart';
import '../../../services/session_controller.dart';

/// Reads a user's in-app notifications and lets them mark one read. Server
/// writes the records; rules allow the recipient to flip only `isRead`.
abstract interface class NotificationsRepository {
  Stream<List<AppNotification>> watchForUser(String userId);
  Future<void> markRead(String notificationId);
}

class FirestoreNotificationsRepository implements NotificationsRepository {
  FirestoreNotificationsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AppNotification>> watchForUser(String userId) {
    return _db
        .collection(Collections.notifications)
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Future<void> markRead(String notificationId) {
    return _db
        .collection(Collections.notifications)
        .doc(notificationId)
        .update({'isRead': true});
  }
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return FirestoreNotificationsRepository(FirebaseFirestore.instance);
});

/// The signed-in user's notifications.
final notificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(notificationsRepositoryProvider).watchForUser(uid);
});

/// Count of unread notifications, for the app-bar badge.
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
        data: (items) => items.where((n) => !n.isRead).length,
        orElse: () => 0,
      );
});
