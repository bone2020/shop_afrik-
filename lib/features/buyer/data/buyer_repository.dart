import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/buyer.dart';
import '../../../services/session_controller.dart';

/// The buyer's own profile, including their saved-address book. Buyers read and
/// write only their own document (enforced by the rules).
abstract interface class BuyerRepository {
  Stream<Buyer?> watchBuyer(String uid);
  Future<void> upsertAddress(String uid, Address address);
  Future<void> deleteAddress(String uid, String addressId);
  Future<void> setDefaultAddress(String uid, String addressId);
}

class FirestoreBuyerRepository implements BuyerRepository {
  FirestoreBuyerRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(Collections.buyers).doc(uid);

  @override
  Stream<Buyer?> watchBuyer(String uid) {
    return _doc(uid)
        .snapshots()
        .map((d) => d.exists ? Buyer.fromMap(d.id, d.data()!) : null);
  }

  Future<void> _mutate(
    String uid,
    List<Address> Function(List<Address> current) change,
  ) async {
    await _db.runTransaction((tx) async {
      final ref = _doc(uid);
      final snap = await tx.get(ref);
      final buyer = snap.exists ? Buyer.fromMap(uid, snap.data()!) : null;
      final next = change(buyer?.addresses ?? const []);
      if (snap.exists) {
        tx.update(ref, {'addresses': next.map((a) => a.toMap()).toList()});
      } else {
        tx.set(ref, {
          'name': uid,
          'addresses': next.map((a) => a.toMap()).toList(),
          'wishlist': <String>[],
          'pushEnabled': true,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  @override
  Future<void> upsertAddress(String uid, Address address) {
    return _mutate(uid, (current) {
      final list = [...current];
      final idx = list.indexWhere((a) => a.id == address.id);
      // If this is (or becomes) the default, clear the flag on the others.
      final cleaned = address.isDefault
          ? list.map((a) => _withDefault(a, false)).toList()
          : list;
      if (idx >= 0) {
        cleaned[idx] = address;
        return cleaned;
      }
      return [...cleaned, address];
    });
  }

  @override
  Future<void> deleteAddress(String uid, String addressId) {
    return _mutate(
        uid, (current) => current.where((a) => a.id != addressId).toList());
  }

  @override
  Future<void> setDefaultAddress(String uid, String addressId) {
    return _mutate(
      uid,
      (current) =>
          current.map((a) => _withDefault(a, a.id == addressId)).toList(),
    );
  }

  Address _withDefault(Address a, bool isDefault) => Address(
        id: a.id,
        label: a.label,
        recipientName: a.recipientName,
        phone: a.phone,
        line1: a.line1,
        line2: a.line2,
        city: a.city,
        region: a.region,
        market: a.market,
        isDefault: isDefault,
      );
}

final buyerRepositoryProvider = Provider<BuyerRepository>((ref) {
  return FirestoreBuyerRepository(FirebaseFirestore.instance);
});

/// The signed-in buyer's profile (with their saved addresses).
final currentBuyerProvider = StreamProvider.autoDispose<Buyer?>((ref) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(buyerRepositoryProvider).watchBuyer(uid);
});
