import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/user_role.dart';
import '../features/auth/data/auth_service.dart';

/// A lightweight view of the authenticated user and their active role.
///
/// Hydrated from Firebase Auth: [uid] from the signed-in user, [role] /
/// [adminTier] from the ID-token custom claims, and [displayName] from the
/// auth profile. A missing `role` claim maps to [UserRole.buyer] — a fresh
/// account is a fully functional buyer with no claim required.
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

/// Builds a [Session] from a user's id and ID-token claims. Pure and
/// synchronous so the claim → role mapping can be unit-tested directly.
///
/// `role` absent → [UserRole.buyer] (the default); `adminTier` is only read for
/// admins.
Session sessionFromClaims({
  required String uid,
  required Map<String, dynamic> claims,
  String? displayName,
}) {
  final role = UserRole.fromName(claims['role'] as String?);
  final adminTier = role == UserRole.admin
      ? AdminTier.fromName(claims['adminTier'] as String?)
      : null;
  return Session(
    uid: uid,
    role: role,
    displayName: displayName,
    adminTier: adminTier,
  );
}

/// Holds the current [Session], hydrated live from Firebase Auth.
class SessionController extends Notifier<Session> {
  StreamSubscription<User?>? _sub;

  @override
  Session build() {
    final auth = ref.watch(firebaseAuthProvider);
    // idTokenChanges fires on sign-in, sign-out AND token refreshes, so a newly
    // granted role claim propagates without a full re-login.
    _sub = auth.idTokenChanges().listen(_handleUser);
    ref.onDispose(() => _sub?.cancel());
    return Session.unauthenticated;
  }

  Future<void> _handleUser(User? user) async {
    if (user == null) {
      state = Session.unauthenticated;
      return;
    }
    final token = await user.getIdTokenResult();
    state = sessionFromClaims(
      uid: user.uid,
      claims: token.claims ?? const {},
      displayName: user.displayName,
    );
  }

  /// Force-refreshes the ID token to pick up a newly granted role claim
  /// (e.g. after seller approval). Safe to call on app resume.
  Future<void> refreshClaims() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;
    final token = await user.getIdTokenResult(true);
    state = sessionFromClaims(
      uid: user.uid,
      claims: token.claims ?? const {},
      displayName: user.displayName,
    );
  }

  Future<void> signOut() => ref.read(firebaseAuthProvider).signOut();
}

final sessionControllerProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);
