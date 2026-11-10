/// Motivos por los que no se pudieron activar los avisos, con el mensaje que ve el usuario
/// (design.md §13).
enum PushFailureReason {
  denied(
    'Los avisos están bloqueados. Permite las notificaciones de Turnos en la configuración del '
    'navegador o del teléfono y vuelve a intentarlo.',
  ),
  unknown('No se pudieron activar los avisos. Vuelve a intentarlo.');

  const PushFailureReason(this.message);

  final String message;
}

class PushFailure implements Exception {
  const PushFailure(this.reason);

  final PushFailureReason reason;

  String get message => reason.message;

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
