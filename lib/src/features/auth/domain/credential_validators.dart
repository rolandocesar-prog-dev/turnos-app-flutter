/// Validaciones del formulario de acceso, antes de llamar a Firebase (design.md §8).
/// Devuelven el mensaje de error o `null` si el valor es válido.
abstract final class CredentialValidators {
  static const minPasswordLength = 6;

  // Suficiente para atrapar errores de tipeo; Firebase valida el resto.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Escribe tu correo.';
    if (!_emailPattern.hasMatch(email)) {
      return 'El correo no tiene un formato válido.';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Escribe tu contraseña.';
    if (password.length < minPasswordLength) {
      return 'Usa al menos $minPasswordLength caracteres.';
    }
    return null;
  }
}
