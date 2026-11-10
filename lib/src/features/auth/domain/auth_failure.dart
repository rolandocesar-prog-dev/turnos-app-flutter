/// Motivos de un acceso fallido (design.md §8). El texto que ve el usuario lo pone la
/// presentación (design.md §14).
enum AuthFailureReason {
  /// Usuario inexistente, contraseña incorrecta o credencial inválida: un solo motivo, para no
  /// revelar si el correo está registrado (RF-01).
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  tooManyRequests,
  network,
  cancelled,
  popupBlocked,
  unknown,
}

/// Error de acceso con un motivo conocido.
class AuthFailure implements Exception {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;

  @override
  String toString() => 'AuthFailure(${reason.name})';
}
