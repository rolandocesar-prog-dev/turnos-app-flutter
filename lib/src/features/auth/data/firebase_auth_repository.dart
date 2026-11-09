import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';

/// `AuthRepository` sobre Firebase Auth.
class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() => _auth
      .authStateChanges()
      .map((user) => user == null ? null : _toAppUser(user));

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
  }) =>
      _guard(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<AppUser> signInWithGoogle() =>
      _guard(() => _auth.signInWithPopup(GoogleAuthProvider()));

  @override
  Future<void> signOut() => _auth.signOut();

  Future<AppUser> _guard(Future<UserCredential> Function() action) async {
    try {
      final credential = await action();
      final user = credential.user;
      if (user == null) throw const AuthFailure(AuthFailureReason.unknown);
      return _toAppUser(user);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(authFailureReasonFor(error.code));
    }
  }

  static AppUser _toAppUser(User user) =>
      AppUser(uid: user.uid, email: user.email);
}

/// Traduce el código de error de Firebase Auth al motivo del dominio (design.md §8).
AuthFailureReason authFailureReasonFor(String code) => switch (code) {
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'invalid-login-credentials' =>
        AuthFailureReason.invalidCredentials,
      'email-already-in-use' => AuthFailureReason.emailInUse,
      'weak-password' => AuthFailureReason.weakPassword,
      'invalid-email' => AuthFailureReason.invalidEmail,
      'too-many-requests' => AuthFailureReason.tooManyRequests,
      'network-request-failed' => AuthFailureReason.network,
      'popup-closed-by-user' ||
      'cancelled-popup-request' =>
        AuthFailureReason.cancelled,
      'popup-blocked' => AuthFailureReason.popupBlocked,
      _ => AuthFailureReason.unknown,
    };
