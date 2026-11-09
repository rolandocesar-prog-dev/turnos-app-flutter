import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/auth/data/firebase_auth_repository.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';

void main() {
  test(
      'usuario inexistente y contraseña incorrecta dan el mismo mensaje (RF-01)',
      () {
    const codes = [
      'user-not-found',
      'wrong-password',
      'invalid-credential',
      'invalid-login-credentials',
    ];
    final messages = {
      for (final code in codes) authFailureReasonFor(code).message,
    };

    expect(messages, {'Correo o contraseña incorrectos.'});
  });

  test('los demás códigos conocidos tienen su propio motivo', () {
    expect(
      authFailureReasonFor('email-already-in-use'),
      AuthFailureReason.emailInUse,
    );
    expect(
      authFailureReasonFor('weak-password'),
      AuthFailureReason.weakPassword,
    );
    expect(
      authFailureReasonFor('invalid-email'),
      AuthFailureReason.invalidEmail,
    );
    expect(
      authFailureReasonFor('too-many-requests'),
      AuthFailureReason.tooManyRequests,
    );
    expect(
      authFailureReasonFor('network-request-failed'),
      AuthFailureReason.network,
    );
    expect(
      authFailureReasonFor('popup-closed-by-user'),
      AuthFailureReason.cancelled,
    );
  });

  test('un código desconocido da un mensaje genérico', () {
    expect(authFailureReasonFor('algo-nuevo'), AuthFailureReason.unknown);
    expect(AuthFailureReason.unknown.message, isNotEmpty);
  });
}
