import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_env.dart';
import '../core/config/staging_firebase_options.dart';
import '../firebase_options.dart';

/// Initializes Firebase: the real project from the generated
/// `lib/firebase_options.dart`, or kartafrik-staging in a staging build. Explicit options work uniformly across
/// Android, iOS, and web, with no per-platform native config required.
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: AppEnvironment.isStaging
          ? StagingFirebaseOptions.currentPlatform
          : DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization failed: ${e.message}');
    }
    rethrow;
  }
}
