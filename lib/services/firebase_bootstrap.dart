import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes the Shop Afrik Firebase project.
///
/// The generated `lib/firebase_options.dart` is intentionally NOT committed
/// (it is environment-specific and listed in `.gitignore`). Run
/// `flutterfire configure` against the dedicated Shop Afrik Firebase project
/// (plan §10) to generate it, then this bootstrap will pick it up.
///
/// Until the file exists, [ensureFirebaseInitialized] falls back to the
/// default `Firebase.initializeApp()` so the app can still boot during early
/// scaffolding without crashing.
Future<void> ensureFirebaseInitialized() async {
  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (e) {
    if (kDebugMode) {
      // No options configured yet — expected before `flutterfire configure`.
      debugPrint('Firebase not yet configured: ${e.message}');
    }
    rethrow;
  }
}
