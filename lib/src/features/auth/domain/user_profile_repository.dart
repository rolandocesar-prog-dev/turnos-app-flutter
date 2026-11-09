import 'app_user.dart';

/// Perfil del usuario en `users/{uid}` (design.md §3 y §8).
abstract interface class UserProfileRepository {
  /// Crea el perfil con rol `client` si todavía no existe; uno existente no se modifica.
  Future<void> ensureProfile(AppUser user);
}
