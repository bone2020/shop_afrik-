import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/admin_audit_entry.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/order.dart';
import '../../../core/models/staff_member.dart';

/// An account found by email, phone or uid (via the `findUser` callable).
@immutable
class FoundUser {
  const FoundUser({
    required this.uid,
    required this.role,
    this.adminTier,
    this.email,
    this.phone,
    this.displayName,
    this.disabled = false,
  });

  final String uid;
  final String role;
  final String? adminTier;
  final String? email;
  final String? phone;
  final String? displayName;
  final bool disabled;

  String get label => displayName ?? email ?? phone ?? uid;

  factory FoundUser.fromMap(Map<String, dynamic> map) => FoundUser(
        uid: map['uid'] as String,
        role: map['role'] as String? ?? 'buyer',
        adminTier: map['adminTier'] as String?,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        displayName: map['displayName'] as String?,
        disabled: map['disabled'] as bool? ?? false,
      );
}

/// Filters for the all-orders view (SA-134). Only one of [buyerId] and
/// [sellerId] applies at a time.
@immutable
class OrderFilter {
  const OrderFilter({
    this.status,
    this.market,
    this.buyerId,
    this.sellerId,
    this.from,
    this.to,
  });

  final OrderStatus? status;
  final String? market;
  final String? buyerId;
  final String? sellerId;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is OrderFilter &&
      other.status == status &&
      other.market == market &&
      other.buyerId == buyerId &&
      other.sellerId == sellerId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(status, market, buyerId, sellerId, from, to);
}

/// Filters for the audit log (SA-135). One of [actorId], [targetId] or
/// [action] at a time keeps every query on a single composite index.
@immutable
class AuditFilter {
  const AuditFilter({this.actorId, this.targetId, this.action});

  final String? actorId;
  final String? targetId;
  final String? action;

  @override
  bool operator ==(Object other) =>
      other is AuditFilter &&
      other.actorId == actorId &&
      other.targetId == targetId &&
      other.action == action;

  @override
  int get hashCode => Object.hash(actorId, targetId, action);
}

/// One page of results plus the cursor for the next page.
@immutable
class AdminPage<T> {
  const AdminPage(this.items, this.cursor, {required this.hasMore});
  final List<T> items;
  final Object? cursor;
  final bool hasMore;
}

const adminPageSize = 25;

/// Back-office tools: user lookup and roles, platform settings, the
/// all-orders search and the audit log (SA-132 to SA-135).
abstract interface class AdminToolsRepository {
  Future<FoundUser?> findUser(String query);
  Future<void> setUserRole(
      {required String uid, required String role, String? adminTier});
  Stream<List<StaffMember>> watchStaff();
  Future<void> updateSettings(Map<String, dynamic> patch);
  Future<ShopOrder?> getOrder(String orderId);
  Future<AdminPage<ShopOrder>> fetchOrders(OrderFilter filter,
      {Object? cursor});
  Future<AdminPage<AdminAuditEntry>> fetchAudit(AuditFilter filter,
      {Object? cursor});
}

class FirebaseAdminToolsRepository implements AdminToolsRepository {
  FirebaseAdminToolsRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Future<FoundUser?> findUser(String query) async {
    final res =
        await _functions.httpsCallable('findUser').call({'query': query});
    final user = (res.data as Map?)?['user'] as Map?;
    return user == null ? null : FoundUser.fromMap(user.cast());
  }

  @override
  Future<void> setUserRole(
      {required String uid, required String role, String? adminTier}) async {
    await _functions.httpsCallable('setUserRole').call({
      'uid': uid,
      'role': role,
      if (adminTier != null) 'adminTier': adminTier,
    });
  }

  @override
  Stream<List<StaffMember>> watchStaff() {
    return _db.collection(Collections.staff).snapshots().map((s) =>
        s.docs.map((d) => StaffMember.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> updateSettings(Map<String, dynamic> patch) async {
    await _functions
        .httpsCallable('updatePlatformSettings')
        .call({'patch': patch});
  }

  @override
  Future<ShopOrder?> getOrder(String orderId) async {
    final d = await _db.collection(Collections.orders).doc(orderId).get();
    return d.exists ? ShopOrder.fromMap(d.id, d.data()!) : null;
  }

  @override
  Future<AdminPage<ShopOrder>> fetchOrders(OrderFilter f,
      {Object? cursor}) async {
    Query<Map<String, dynamic>> q = _db.collection(Collections.orders);
    if (f.status != null) q = q.where('status', isEqualTo: f.status!.name);
    // A buyer or seller search ignores the market filter, which keeps the
    // number of composite indexes small (see firestore.indexes.json).
    if (f.buyerId != null) {
      q = q.where('buyerId', isEqualTo: f.buyerId);
    } else if (f.sellerId != null) {
      q = q.where('sellerIds', arrayContains: f.sellerId);
    } else if (f.market != null) {
      q = q.where('market', isEqualTo: f.market);
    }
    if (f.from != null) {
      q = q.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(f.from!));
    }
    if (f.to != null) {
      q = q.where('createdAt', isLessThan: Timestamp.fromDate(f.to!));
    }
    q = q.orderBy('createdAt', descending: true).limit(adminPageSize);
    if (cursor != null) {
      q = q.startAfterDocument(cursor as DocumentSnapshot);
    }
    final snap = await q.get();
    return AdminPage(
      snap.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList(),
      snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == adminPageSize,
    );
  }

  @override
  Future<AdminPage<AdminAuditEntry>> fetchAudit(AuditFilter f,
      {Object? cursor}) async {
    Query<Map<String, dynamic>> q = _db.collection(Collections.adminAudit);
    if (f.actorId != null) {
      q = q.where('actorId', isEqualTo: f.actorId);
    } else if (f.targetId != null) {
      q = q.where('targetId', isEqualTo: f.targetId);
    } else if (f.action != null) {
      q = q.where('action', isEqualTo: f.action);
    }
    q = q.orderBy('createdAt', descending: true).limit(adminPageSize);
    if (cursor != null) {
      q = q.startAfterDocument(cursor as DocumentSnapshot);
    }
    final snap = await q.get();
    return AdminPage(
      snap.docs.map((d) => AdminAuditEntry.fromMap(d.id, d.data())).toList(),
      snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == adminPageSize,
    );
  }
}

final adminToolsRepositoryProvider = Provider<AdminToolsRepository>((ref) {
  return FirebaseAdminToolsRepository(
      FirebaseFirestore.instance, FirebaseFunctions.instance);
});

final staffProvider = StreamProvider.autoDispose<List<StaffMember>>((ref) {
  return ref.watch(adminToolsRepositoryProvider).watchStaff();
});
