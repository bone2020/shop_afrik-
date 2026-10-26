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

  /// The backend for this build. Throws on a misspelt KARTAFRIK_ENV (say
  /// "stagin") rather than quietly building an app that talks to the real
  /// project.
  static AppEnv get current => parse(_name);

  static bool get isStaging => current == AppEnv.staging;

  /// No value means the real app; "staging" means staging; anything else is
  /// a mistake in the build command.
  static AppEnv parse(String name) => switch (name) {
        '' => AppEnv.production,
        'staging' => AppEnv.staging,
        _ => throw StateError(
            'Unknown KARTAFRIK_ENV "$name". Leave it out for the real app, '
            'or use --dart-define=KARTAFRIK_ENV=staging.',
          ),
      };
}
