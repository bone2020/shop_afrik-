import 'package:flutter_test/flutter_test.dart';
import 'package:shop_afrik/core/config/app_env.dart';
import 'package:shop_afrik/core/config/staging_firebase_options.dart';

void main() {
  test('a normal build talks to the real project', () {
    // Tests run without --dart-define=KARTAFRIK_ENV=staging.
    expect(AppEnvironment.current, AppEnv.production);
    expect(AppEnvironment.isStaging, isFalse);
  });

  test('only an empty value or "staging" is accepted', () {
    expect(AppEnvironment.parse(''), AppEnv.production);
    expect(AppEnvironment.parse('staging'), AppEnv.staging);
    expect(() => AppEnvironment.parse('stagin'), throwsStateError);
    expect(() => AppEnvironment.parse('production'), throwsStateError);
  });

  test('staging options always point at kartafrik-staging', () {
    expect(StagingFirebaseOptions.android.projectId, 'kartafrik-staging');
    expect(StagingFirebaseOptions.ios.projectId, 'kartafrik-staging');
  });
}
