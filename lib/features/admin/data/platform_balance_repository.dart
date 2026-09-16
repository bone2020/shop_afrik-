import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/platform_balance.dart';

/// Reads the platform-account bucket balances (one row per currency).
abstract interface class PlatformBalanceRepository {
  Stream<List<PlatformBalance>> watchBalances();
}

/// Firestore-backed implementation reading `platform_balances`.
class FirestorePlatformBalanceRepository implements PlatformBalanceRepository {
  FirestorePlatformBalanceRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<PlatformBalance>> watchBalances() {
    return _db
        .collection(Collections.platformBalances)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlatformBalance.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.currency.compareTo(b.currency)));
  }
}

final platformBalanceRepositoryProvider =
    Provider<PlatformBalanceRepository>((ref) {
  return FirestorePlatformBalanceRepository(FirebaseFirestore.instance);
});

/// Streams the per-currency platform buckets for the admin dashboard.
final platformBalancesProvider =
    StreamProvider.autoDispose<List<PlatformBalance>>((ref) {
  return ref.watch(platformBalanceRepositoryProvider).watchBalances();
});
