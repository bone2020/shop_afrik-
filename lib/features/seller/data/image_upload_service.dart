import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Picks an image and uploads it to Cloud Storage, returning the download URL
/// (or null if the user cancelled). Product images live under
/// `products/{sellerId}/…`, which the Storage rules scope to the owning seller.
abstract interface class ImageUploadService {
  Future<String?> pickAndUploadProductImage(String sellerId);
}

class FirebaseImageUploadService implements ImageUploadService {
  FirebaseImageUploadService(this._storage, this._picker);

  final FirebaseStorage _storage;
  final ImagePicker _picker;

  @override
  Future<String?> pickAndUploadProductImage(String sellerId) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final ref = _storage.ref(
      'products/$sellerId/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return FirebaseImageUploadService(
      FirebaseStorage.instance, ImagePicker());
});
