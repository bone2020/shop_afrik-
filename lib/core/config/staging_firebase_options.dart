import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Client settings for the `kartafrik-staging` Firebase project.
///
/// These identify the project to Firebase; they are not secrets (access is
/// enforced by the security rules), so unlike `lib/firebase_options.dart`
/// they are committed. The app ids are filled in once the staging Android and
/// iOS apps are registered (docs/STAGING.md).
abstract final class StagingFirebaseOptions {
  static const String projectId = 'kartafrik-staging';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: projectId,
    storageBucket: 'kartafrik-staging.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: projectId,
    storageBucket: 'kartafrik-staging.firebasestorage.app',
    iosBundleId: 'com.shopafrik.shopAfrik',
  );

  static FirebaseOptions get currentPlatform {
    final options = switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
          'The staging app is built for Android and iOS only.'),
    };
    if (options.appId.isEmpty) {
      throw StateError(
          'Staging is not registered for this platform yet. See docs/STAGING.md.');
    }
    return options;
  }
}
