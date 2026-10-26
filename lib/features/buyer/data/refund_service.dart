import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/data/firestore_collections.dart';
import '../../../core/models/refund_request.dart';
import '../../../services/session_controller.dart';

/// Buyer refund requests (SA-053). Requests are created by the
/// `requestRefund` Cloud Function, which computes the amount and checks the
/// refund window; the client only says which lines and why.
abstract interface class RefundService {
  /// Opens a refund for [quantities] (productId → quantity); returns its id.
  Future<String> requestRefund({
    required String orderId,
    required Map<String, int> quantities,
    required String reason,
    List<String> evidenceUrls = const [],
  });

  /// The signed-in buyer's refund requests on [orderId], newest first.
  Stream<List<RefundRequest>> watchForOrder({
    required String buyerId,
    required String orderId,
  });

  /// Picks a photo and uploads it as private refund evidence; returns its
  /// download URL, or null if the buyer cancelled.
  Future<String?> pickAndUploadEvidence(String buyerId);
}

class FirebaseRefundService implements RefundService {
  FirebaseRefundService(this._db, this._functions, this._storage, this._picker);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  @override
  Future<String> requestRefund({
    required String orderId,
    required Map<String, int> quantities,
    required String reason,
    List<String> evidenceUrls = const [],
  }) async {
    final res = await _functions
        .httpsCallable('requestRefund')
        .call<Map<String, dynamic>>({
      'orderId': orderId,
      'lines': [
        for (final e in quantities.entries)
          if (e.value > 0) {'productId': e.key, 'quantity': e.value},
      ],
      'reason': reason,
      'evidenceUrls': evidenceUrls,
    });
    return res.data['refundId'] as String? ?? '';
  }

  @override
  Stream<List<RefundRequest>> watchForOrder({
    required String buyerId,
    required String orderId,
  }) {
    return _db
        .collection(Collections.refundRequests)
        .where('buyerId', isEqualTo: buyerId)
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => RefundRequest.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0))));
  }

  @override
  Future<String?> pickAndUploadEvidence(String buyerId) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    final ref = _storage.ref(
      'refund_evidence/$buyerId/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(
        await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}

final refundServiceProvider = Provider<RefundService>((ref) {
  return FirebaseRefundService(FirebaseFirestore.instance,
      FirebaseFunctions.instance, FirebaseStorage.instance, ImagePicker());
});

/// The signed-in buyer's refund requests for one order.
final orderRefundsProvider = StreamProvider.autoDispose
    .family<List<RefundRequest>, String>((ref, orderId) {
  final uid = ref.watch(sessionControllerProvider).uid;
  if (uid == null) return const Stream.empty();
  return ref
      .watch(refundServiceProvider)
      .watchForOrder(buyerId: uid, orderId: orderId);
});
