import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Initializes the Shop Afrik Firebase project using the generated
/// `lib/firebase_options.dart`. Explicit options work uniformly across
/// Android, iOS, and web, with no per-platform native config required.
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: ${e.message}');
    }
    rethrow;
  }
}
