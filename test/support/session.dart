import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shop_afrik/core/models/user_role.dart';
import 'package:shop_afrik/services/session_controller.dart';

/// A [SessionController] that returns a fixed [Session] and never touches
/// Firebase Auth — for widget tests.
class StubSessionController extends SessionController {
  StubSessionController(this._session);
  final Session _session;

  @override
  Session build() => _session;
}

/// Provider override that pins the session to [session] (unauthenticated by
/// default).
Override stubSession([Session session = Session.unauthenticated]) {
  return sessionControllerProvider
      .overrideWith(() => StubSessionController(session));
}

/// Convenience: an authenticated session for [role].
Session authedSession(UserRole role, {String uid = 'test-uid'}) {
  return Session(uid: uid, role: role, displayName: 'Tester');
}
