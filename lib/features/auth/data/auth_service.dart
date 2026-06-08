import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Firebase Auth instance, exposed as a provider so it can be overridden
/// in tests.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Wraps Firebase Authentication for email/password and phone/OTP sign-in.
/// Profile-doc creation lives in the sign-in flow (it knows when a user is new);
/// this service only handles credentials.
class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  // --- Email / password ---

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
  }

  /// Registers a new email account and sets the display name.
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    await cred.user?.updateDisplayName(displayName.trim());
    return cred;
  }

  // --- Phone / OTP ---

  /// Starts phone verification. On Android, [verificationCompleted] may fire for
  /// auto-retrieval; otherwise [codeSent] provides the verification id to pair
  /// with the user's typed code.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) codeSent,
    required void Function(FirebaseAuthException e) verificationFailed,
    void Function(PhoneAuthCredential credential)? verificationCompleted,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: verificationCompleted ?? (_) {},
      verificationFailed: verificationFailed,
      codeSent: (verificationId, _) => codeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode.trim(),
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithPhoneCredential(
      PhoneAuthCredential credential) {
    return _auth.signInWithCredential(credential);
  }

  /// Sets the display name on the current user (used for phone sign-ups).
  Future<void> setDisplayName(String name) =>
      _auth.currentUser?.updateDisplayName(name.trim()) ?? Future.value();
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(firebaseAuthProvider));
});

/// Maps an auth error to a short, friendly message.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'invalid-verification-code':
        return 'That code is incorrect. Please try again.';
      case 'invalid-phone-number':
        return 'That phone number looks invalid.';
      case 'session-expired':
      case 'code-expired':
        return 'The code expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
  if (kDebugMode) return error.toString();
  return 'Something went wrong. Please try again.';
}
