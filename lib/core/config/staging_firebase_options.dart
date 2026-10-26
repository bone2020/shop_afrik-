import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Client settings for the `kartafrik-staging` Firebase project.
///
/// These identify the project to Firebase; they are not secrets (access is
/// enforced by the security rules), so unlike `lib/firebase_options.dart`
/// they are committed. The values come from the Staging workflow's
/// "register apps" action (docs/STAGING.md).
abstract final class StagingFirebaseOptions {
  static const String projectId = 'kartafrik-staging';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3ECnOxMg51WHJ6bL6IKatiLEp7eYpnBE',
    appId: '1:788179421436:android:d28733e6a559b80cbb2f79',
    messagingSenderId: '788179421436',
    projectId: projectId,
    storageBucket: 'kartafrik-staging.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAEIm3ODO7R8qlQU5VS59Rd2ogvPVEwwo4',
    appId: '1:788179421436:ios:85829d9d779ced4dbb2f79',
    messagingSenderId: '788179421436',
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
