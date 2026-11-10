import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/auth/domain/credential_validators.dart';

void main() {
  group('correo', () {
    test('acepta un correo con formato válido, aunque tenga espacios alrededor',
        () {
      expect(CredentialValidators.email('ana@ejemplo.com'), isNull);
      expect(CredentialValidators.email('  ana@ejemplo.com '), isNull);
    });

    test('pide el correo si está vacío', () {
      expect(CredentialValidators.email(''), CredentialIssue.emailMissing);
      expect(CredentialValidators.email(null), CredentialIssue.emailMissing);
    });

    test('rechaza formatos inválidos', () {
      for (final value in [
        'ana',
        'ana@',
        'ana@ejemplo',
        '@ejemplo.com',
        'ana @x.com',
      ]) {
        expect(
          CredentialValidators.email(value),
          CredentialIssue.emailInvalid,
          reason: value,
        );
      }
    });
  });

  group('contraseña', () {
    test('acepta 6 caracteres o más', () {
      expect(CredentialValidators.password('123456'), isNull);
    });

    test('pide la contraseña si está vacía y rechaza las cortas', () {
      expect(
        CredentialValidators.password(''),
        CredentialIssue.passwordMissing,
      );
      expect(
        CredentialValidators.password('12345'),
        CredentialIssue.passwordTooShort,
      );
    });
  });
}
