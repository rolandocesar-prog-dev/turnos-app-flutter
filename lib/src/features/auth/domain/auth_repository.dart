import 'app_user.dart';

/// Puerto de autenticación: la app solo conoce esta interfaz (design.md §7).
abstract interface class AuthRepository {
  /// Emite el usuario actual cada vez que cambia la sesión; `null` sin sesión.
  Stream<AppUser?> authStateChanges();
}
