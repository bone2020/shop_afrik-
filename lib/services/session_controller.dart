import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/user_role.dart';

/// A lightweight view of the authenticated user and their active role.
///
/// During Phase 1 this is populated locally so the routing shell and the
/// per-role screens can be exercised without a live Firebase backend. In
/// Phase 2 it will be hydrated from Firebase Auth + the user's Firestore
/// profile document.
@immutable
class Session {
  const Session({
    this.uid,
    this.role,
    this.displayName,
    this.adminTier,
  });

  final String? uid;
  final UserRole? role;
  final String? displayName;
  final AdminTier? adminTier;

  bool get isAuthenticated => uid != null && role != null;

  Session copyWith({
    String? uid,
    UserRole? role,
    String? displayName,
    AdminTier? adminTier,
  }) {
    return Session(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      adminTier: adminTier ?? this.adminTier,
    );
  }

  static const Session unauthenticated = Session();
}

/// Holds and mutates the current [Session].
class SessionController extends Notifier<Session> {
  @override
  Session build() => Session.unauthenticated;

  /// Stand-in sign-in used by the Phase 1 role picker. Replace with a real
  /// Firebase Auth flow in Phase 2.
  void signInAs(UserRole role, {String? displayName, AdminTier? adminTier}) {
    state = Session(
      uid: 'local-${role.name}',
      role: role,
      displayName: displayName ?? role.name,
      adminTier: role == UserRole.admin
          ? (adminTier ?? AdminTier.admin)
          : null,
    );
  }

  void signOut() => state = Session.unauthenticated;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);
