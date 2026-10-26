import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/product.dart';
import '../../../services/session_controller.dart';
import 'cart_controller.dart';

/// Where a signed-in buyer's cart is kept between sessions (SA-045).
abstract interface class CartStore {
  Future<List<({String productId, int quantity})>> load(String uid);
  Future<void> save(String uid, List<CartLine> lines);
  Future<Product?> product(String productId);
}

/// Keeps the cart as a `cart` list on `buyers/{uid}`, so it follows the
/// buyer across devices. Prices are never stored: they are re-read on load.
class FirestoreCartStore implements CartStore {
  FirestoreCartStore([this._override]);
  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  @override
  Future<List<({String productId, int quantity})>> load(String uid) async {
    final d = await _db.collection(Collections.buyers).doc(uid).get();
    final raw = (d.data()?['cart'] as List?) ?? const [];
    return [
      for (final e in raw.whereType<Map>())
        if (e['productId'] is String && e['quantity'] is num)
          (
            productId: e['productId'] as String,
            quantity: (e['quantity'] as num).toInt()
          ),
    ];
  }

  @override
  Future<void> save(String uid, List<CartLine> lines) =>
      _db.collection(Collections.buyers).doc(uid).set({
        'cart': [
          for (final l in lines)
            {'productId': l.product.id, 'quantity': l.quantity},
        ],
      }, SetOptions(merge: true));

  @override
  Future<Product?> product(String productId) async {
    try {
      final d =
          await _db.collection(Collections.products).doc(productId).get();
      return d.exists ? Product.fromMap(d.id, d.data()!) : null;
    } on FirebaseException {
      // Products that are no longer listed are not readable.
      return null;
    }
  }
}

final cartStoreProvider = Provider<CartStore>((ref) {
  return FirestoreCartStore();
});

/// Watch this from the buyer shell. On sign-in it restores the saved cart
/// (dropping products no longer for sale and capping quantities at stock);
/// after that every change is saved.
final cartSyncProvider = Provider<void>((ref) {
  final store = ref.watch(cartStoreProvider);
  String? loadedFor;

  Future<void> restore(String uid) async {
    try {
      final saved = await store.load(uid);
      final lines = <CartLine>[];
      for (final s in saved) {
        final p = await store.product(s.productId);
        if (p == null ||
            !p.isActive ||
            p.approvalStatus != ProductApprovalStatus.approved ||
            p.stock <= 0) {
          continue;
        }
        lines.add(CartLine(
            product: p, quantity: s.quantity.clamp(1, p.stock).toInt()));
      }
      if (ref.read(sessionControllerProvider).uid != uid) return;
      ref.read(cartProvider.notifier).restore(lines);
      loadedFor = uid;
      await store.save(uid, ref.read(cartProvider));
    } catch (_) {
      // A cart that cannot be restored or saved stays local; never block
      // the shop over it.
    }
  }

  void save(String uid, List<CartLine> lines) {
    store.save(uid, lines).catchError((_) {});
  }

  ref.listen<String?>(
    sessionControllerProvider.select((s) => s.uid),
    (previous, uid) {
      loadedFor = null;
      // Signing out leaves nothing behind for the next person on the device.
      if (previous != null && uid != previous) {
        ref.read(cartProvider.notifier).clear();
      }
      if (uid != null) restore(uid);
    },
    fireImmediately: true,
  );
  ref.listen<List<CartLine>>(cartProvider, (_, lines) {
    final uid = ref.read(sessionControllerProvider).uid;
    if (uid != null && uid == loadedFor) save(uid, lines);
  });
});
