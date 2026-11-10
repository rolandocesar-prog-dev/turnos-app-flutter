/// Motivos por los que no se pudieron activar los avisos (design.md §13). El texto lo pone la
/// presentación (design.md §14).
enum PushFailureReason { denied, unknown }

class PushFailure implements Exception {
  const PushFailure(this.reason);

  final PushFailureReason reason;

  @override
  String toString() => 'PushFailure(${reason.name})';
}

/// Notificaciones push del dispositivo (design.md §13). Los errores llegan como [PushFailure].
abstract interface class PushRepository {
  /// Si el usuario ya dio permiso en este dispositivo.
  Future<bool> isAllowed();

  /// Pide el permiso (si hace falta) y devuelve el token de este dispositivo.
  Future<String> enable();

  /// Tokens nuevos cuando FCM renueva el de este dispositivo.
  Stream<String> get tokenRefreshes;
}
