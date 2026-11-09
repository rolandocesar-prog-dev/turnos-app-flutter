/// Motivos de un acceso fallido, con el mensaje que ve el usuario (design.md §8).
enum AuthFailureReason {
  /// Usuario inexistente, contraseña incorrecta o credencial inválida: un solo mensaje, para no
  /// revelar si el correo está registrado (RF-01).
  invalidCredentials('Correo o contraseña incorrectos.'),
  emailInUse('Ya existe una cuenta con ese correo. Inicia sesión.'),
  weakPassword('La contraseña es muy débil: usa al menos 6 caracteres.'),
  invalidEmail('El correo no tiene un formato válido.'),
  tooManyRequests('Demasiados intentos. Espera un momento y vuelve a probar.'),
  network('No hay conexión. Revisa tu internet y vuelve a probar.'),
  cancelled('Se canceló el inicio de sesión.'),
  popupBlocked(
    'El navegador bloqueó la ventana de Google. Permite las ventanas emergentes para este '
    'sitio y vuelve a intentarlo.',
  ),
  unknown('No se pudo completar. Vuelve a intentarlo.');

  const AuthFailureReason(this.message);

  final String message;
}

/// Error de acceso con un motivo conocido.
class AuthFailure implements Exception {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;

  String get message => reason.message;

  @override
  String toString() => 'AuthFailure(${reason.name})';
}
