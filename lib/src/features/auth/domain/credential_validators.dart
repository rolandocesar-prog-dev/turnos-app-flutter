/// Problemas de lo escrito en el formulario de acceso; la presentación los traduce
/// (design.md §14).
enum CredentialIssue {
  emailMissing,
  emailInvalid,
  passwordMissing,
  passwordTooShort
}

/// Validaciones del formulario de acceso, antes de llamar a Firebase (design.md §8).
/// Devuelven el problema, o `null` si el valor es válido.
abstract final class CredentialValidators {
  static const minPasswordLength = 6;

  // Suficiente para atrapar errores de tipeo; Firebase valida el resto.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static CredentialIssue? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return CredentialIssue.emailMissing;
    if (!_emailPattern.hasMatch(email)) return CredentialIssue.emailInvalid;
    return null;
  }

  static CredentialIssue? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return CredentialIssue.passwordMissing;
    if (password.length < minPasswordLength) {
      return CredentialIssue.passwordTooShort;
    }
    return null;
  }
}
