import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/app.dart';
import 'package:turnos_app/src/features/auth/application/auth_providers.dart';
import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';

import 'support/fakes.dart';

void main() {
  const user = AppUser(uid: 'u1', email: 'ana@ejemplo.com');
  late FakeAuthRepository auth;
  late FakeUserProfileRepository profiles;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeUserProfileRepository();
  });
  tearDown(() => auth.close());

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userProfileRepositoryProvider.overrideWithValue(profiles),
          ],
          child: const TurnosApp(),
        ),
      );

  Future<void> showLogin(WidgetTester tester) async {
    await pumpApp(tester);
    auth.emit(null);
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      password,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  group('sesión y navegación', () {
    testWidgets('mientras se lee la sesión muestra la pantalla de carga',
        (tester) async {
      await pumpApp(tester);
      await tester.pump();

      expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    });

    testWidgets('sin sesión muestra el login', (tester) async {
      await showLogin(tester);

      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(find.text('Reserva tu turno en segundos'), findsNothing);
    });

    testWidgets('con sesión muestra el inicio', (tester) async {
      await pumpApp(tester);
      auth.emit(user);
      await tester.pumpAndSettle();

      expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    });

    testWidgets('cerrar sesión vuelve al login', (tester) async {
      await pumpApp(tester);
      auth.emit(user);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Inicia sesión'), findsOneWidget);
    });
  });

  group('formulario de acceso (RF-01)', () {
    testWidgets('valida antes de enviar', (tester) async {
      await showLogin(tester);

      await fillAndSubmit(tester, 'ana', '123');

      expect(
        find.text('El correo no tiene un formato válido.'),
        findsOneWidget,
      );
      expect(find.text('Usa al menos 6 caracteres.'), findsOneWidget);
      expect(auth.calls, isEmpty);
    });

    testWidgets('iniciar sesión lleva al inicio', (tester) async {
      await showLogin(tester);

      await fillAndSubmit(tester, 'ana@ejemplo.com', 'secreto1');

      expect(auth.calls, ['signIn:ana@ejemplo.com']);
      expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    });

    testWidgets('crear cuenta registra y crea el perfil', (tester) async {
      await showLogin(tester);
      await tester.tap(find.text('¿No tienes cuenta? Crea una'));
      await tester.pumpAndSettle();
      expect(find.text('Crear cuenta'), findsNWidgets(2)); // título y botón

      await fillAndSubmit(tester, 'luis@ejemplo.com', 'secreto1');

      expect(auth.calls, ['register:luis@ejemplo.com']);
      expect(profiles.ensured.single.email, 'luis@ejemplo.com');
      expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    });

    testWidgets(
        'con credenciales incorrectas muestra un mensaje que no revela el correo',
        (
      tester,
    ) async {
      await showLogin(tester);
      auth.failWith = const AuthFailure(AuthFailureReason.invalidCredentials);

      await fillAndSubmit(tester, 'ana@ejemplo.com', 'incorrecta');

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsOneWidget);
    });

    testWidgets(
        'el error anterior no se ve mientras se procesa un intento nuevo', (
      tester,
    ) async {
      await showLogin(tester);
      auth.failWith = const AuthFailure(AuthFailureReason.invalidCredentials);
      await fillAndSubmit(tester, 'ana@ejemplo.com', 'incorrecta');
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

      auth.hold = Completer<void>();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Correo o contraseña incorrectos.'), findsNothing);
      auth.hold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('mientras espera, el botón se desactiva', (tester) async {
      await showLogin(tester);
      auth.hold = Completer<void>();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'ana@ejemplo.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto1',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      auth.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    });
  });
}
