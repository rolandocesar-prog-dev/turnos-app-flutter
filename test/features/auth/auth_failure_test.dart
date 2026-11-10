import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/core/l10n/l10n.dart';
import 'package:turnos_app/src/features/auth/data/firebase_auth_repository.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));

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
      for (final code in codes) l10n.authFailure(authFailureReasonFor(code)),
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

  test('una ventana de Google bloqueada explica qué hacer', () {
    final reason = authFailureReasonFor('popup-blocked');
    expect(reason, AuthFailureReason.popupBlocked);
    expect(l10n.authFailure(reason), contains('ventanas emergentes'));
  });

  test('un código desconocido da un mensaje genérico', () {
    expect(authFailureReasonFor('algo-nuevo'), AuthFailureReason.unknown);
    expect(l10n.authFailure(AuthFailureReason.unknown), isNotEmpty);
  });

  test('cada motivo tiene su texto', () {
    for (final reason in AuthFailureReason.values) {
      expect(l10n.authFailure(reason), isNotEmpty, reason: reason.name);
    }
  });
}
