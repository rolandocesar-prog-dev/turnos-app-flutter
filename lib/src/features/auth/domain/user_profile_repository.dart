import 'app_user.dart';

/// Rol guardado en `users/{uid}` (design.md §3 y §11). Solo se asigna fuera de la app.
enum UserRole { client, admin }

/// Perfil del usuario en `users/{uid}` (design.md §3 y §8).
abstract interface class UserProfileRepository {
  /// Crea el perfil con rol `client` si todavía no existe; uno existente no se modifica.
  Future<void> ensureProfile(AppUser user);

  /// Rol de [uid] en tiempo real; sin perfil, `client`.
  Stream<UserRole> watchRole(String uid);

  /// Guarda el token de FCM de un dispositivo de [uid], sin duplicarlo (design.md §13).
  Future<void> addFcmToken(String uid, String token);
}
