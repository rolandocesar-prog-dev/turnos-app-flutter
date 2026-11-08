import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

/// `AuthRepository` sobre Firebase Auth.
class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(
        (user) =>
            user == null ? null : AppUser(uid: user.uid, email: user.email),
      );
}
