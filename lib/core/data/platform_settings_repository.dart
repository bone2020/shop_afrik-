import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/platform_settings.dart';
import 'firestore_collections.dart';

/// Reads the admin-configurable platform settings document (the runtime source
/// of truth for markets, currencies, fees, and refund tiers).
abstract interface class PlatformSettingsRepository {
  Stream<PlatformSettings> watch();
}

class FirestorePlatformSettingsRepository
    implements PlatformSettingsRepository {
  FirestorePlatformSettingsRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<PlatformSettings> watch() {
    return _db
        .collection(Collections.settings)
        .doc(Collections.platformSettingsDoc)
        .snapshots()
        .map((doc) => doc.exists
            ? PlatformSettings.fromMap(doc.data()!)
            : const PlatformSettings());
  }
}

final platformSettingsRepositoryProvider =
    Provider<PlatformSettingsRepository>((ref) {
  return FirestorePlatformSettingsRepository(FirebaseFirestore.instance);
});

/// Streams platform settings. Until the document exists (or while offline) the
/// seed defaults from [PlatformSettings] apply — config, not hardcoded values.
final platformSettingsProvider = StreamProvider<PlatformSettings>((ref) {
  return ref.watch(platformSettingsRepositoryProvider).watch();
});
