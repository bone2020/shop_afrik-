import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/order.dart';
import '../../../services/session_controller.dart';

/// Delivery-person data: the shipped orders assigned to this courier and
/// proof-of-delivery submission. Submitting proof marks the order delivered
/// via a Cloud Function (orders are server-write-only).
abstract interface class DeliveryRepository {
  Stream<List<ShopOrder>> watchAssignedDeliveries(String courierId);
  Future<void> submitProof({
    required String orderId,
    required String barcode,
    String? photoUrl,
    double? latitude,
    double? longitude,
  });
}

class FirebaseDeliveryRepository implements DeliveryRepository {
  FirebaseDeliveryRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<ShopOrder>> watchAssignedDeliveries(String courierId) {
    // The rules only let a courier read their own shipped orders, so the query
    // must carry both filters.
    return _db
        .collection(Collections.orders)
        .where('courierId', isEqualTo: courierId)
        .where('status', isEqualTo: 'shipped')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<void> submitProof({
    required String orderId,
    required String barcode,
    String? photoUrl,
    double? latitude,
    double? longitude,
  }) async {
    await _functions.httpsCallable('submitProofOfDelivery').call({
      'orderId': orderId,
      'barcode': barcode,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }
}

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return FirebaseDeliveryRepository(
      FirebaseFirestore.instance, FirebaseFunctions.instance);
});

final assignedDeliveriesProvider =
    StreamProvider.autoDispose<List<ShopOrder>>((ref) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(deliveryRepositoryProvider).watchAssignedDeliveries(uid);
});
