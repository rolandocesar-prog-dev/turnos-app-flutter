import 'app_user.dart';

/// Puerto de autenticación: la app solo conoce esta interfaz (design.md §7 y §8).
/// Los errores llegan como `AuthFailure`.
abstract interface class AuthRepository {
  /// Emite el usuario actual cada vez que cambia la sesión; `null` sin sesión.
  Stream<AppUser?> authStateChanges();

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
