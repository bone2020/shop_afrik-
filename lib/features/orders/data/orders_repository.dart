import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/order.dart';

/// Read access to orders. Orders are server-written (Cloud Functions); clients
/// only read their own (buyers) or those containing their products (sellers).
abstract interface class OrdersRepository {
  Stream<List<ShopOrder>> watchBuyerOrders(String buyerId);
  Stream<List<ShopOrder>> watchSellerOrders(String sellerId);
}

class FirestoreOrdersRepository implements OrdersRepository {
  FirestoreOrdersRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<ShopOrder>> watchBuyerOrders(String buyerId) {
    return _db
        .collection(Collections.orders)
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<ShopOrder>> watchSellerOrders(String sellerId) {
    return _db
        .collection(Collections.orders)
        .where('sellerIds', arrayContains: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ShopOrder.fromMap(d.id, d.data())).toList());
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return FirestoreOrdersRepository(FirebaseFirestore.instance);
});
