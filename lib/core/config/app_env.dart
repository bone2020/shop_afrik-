/// Which backend this build talks to, chosen when the app is built:
///
///   flutter run                                    → the real app
///   flutter run --dart-define=KARTAFRIK_ENV=staging → kartafrik-staging
///
/// A staging build shows a STAGING banner and, on Android, installs as a
/// separate app (see android/app/build.gradle.kts), so test data and real
/// data can never be mixed up on one phone.
enum AppEnv { production, staging }

abstract final class AppEnvironment {
  static const String _name = String.fromEnvironment('KARTAFRIK_ENV');

  static const AppEnv current =
      _name == 'staging' ? AppEnv.staging : AppEnv.production;

  static const bool isStaging = _name == 'staging';
}
