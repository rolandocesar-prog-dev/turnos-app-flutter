import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/app.dart';
import 'package:turnos_app/src/features/auth/application/auth_providers.dart';
import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';
import 'package:turnos_app/src/features/bookings/application/booking_providers.dart';
import 'package:turnos_app/src/features/bookings/domain/booking_failure.dart';
import 'package:turnos_app/src/features/resources/application/resource_providers.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';

import 'support/fakes.dart';

void main() {
  const user = AppUser(uid: 'u1', email: 'ana@ejemplo.com');
  late FakeAuthRepository auth;
  late FakeUserProfileRepository profiles;
  late FakeResourceRepository catalog;
  late FakeSlotRepository slots;
  late FakeBookingRepository bookings;
  // Lunes 9 de noviembre de 2026, 10:10; una prueba la adelanta.
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 11, 9, 10, 10);
    auth = FakeAuthRepository();
    profiles = FakeUserProfileRepository();
    catalog = FakeResourceRepository();
    slots = FakeSlotRepository();
    bookings = FakeBookingRepository(slots);
  });
  tearDown(() => auth.close());

  Future<void> pumpApp(WidgetTester tester, {bool google = false}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userProfileRepositoryProvider.overrideWithValue(profiles),
            googleSignInAvailableProvider.overrideWithValue(google),
            resourceRepositoryProvider.overrideWithValue(catalog),
            slotRepositoryProvider.overrideWithValue(slots),
            bookingRepositoryProvider.overrideWithValue(bookings),
            clockProvider.overrideWithValue(() => now),
          ],
          child: const TurnosApp(),
        ),
      );

  Future<void> showCatalog(WidgetTester tester) async {
    await pumpApp(tester);
    auth.emit(user);
    await tester.pumpAndSettle();
  }

  Future<void> showLogin(WidgetTester tester, {bool google = false}) async {
    await pumpApp(tester, google: google);
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

  group('Google (design.md §8)', () {
    testWidgets('donde no está disponible, no se muestra el botón',
        (tester) async {
      await showLogin(tester);

      expect(find.text('Continuar con Google'), findsNothing);
    });

    testWidgets('continuar con Google crea el perfil y lleva al inicio',
        (tester) async {
      await showLogin(tester, google: true);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['google']);
      expect(profiles.ensured.single.email, 'google.user@ejemplo.com');
      expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    });
  });

  group('catálogo (RF-02)', () {
    testWidgets('lista los recursos activos con su duración de turno',
        (tester) async {
      await showCatalog(tester);

      expect(find.text('Cancha de fútbol 5'), findsOneWidget);
      expect(find.text('Consultorio dental'), findsOneWidget);
      expect(find.textContaining('Turnos de 1 h'), findsOneWidget);
      expect(find.textContaining('Turnos de 30 min'), findsOneWidget);
    });

    testWidgets('no muestra los inactivos', (tester) async {
      catalog.resources = [
        testCancha,
        const Resource(
          id: 'sala',
          name: 'Sala de ensayo',
          description: 'En remodelación.',
          slotMinutes: 120,
          active: false,
          weeklySchedule: {},
        ),
      ];
      await showCatalog(tester);

      expect(find.text('Cancha de fútbol 5'), findsOneWidget);
      expect(find.text('Sala de ensayo'), findsNothing);
    });

    testWidgets('si el catálogo no se puede leer, lo dice (no queda cargando)',
        (
      tester,
    ) async {
      catalog.failWith = Exception('permission-denied');
      await showCatalog(tester);

      expect(
        find.text('No se pudo cargar el catálogo. Revisa tu conexión.'),
        findsOneWidget,
      );
    });

    testWidgets('sin recursos muestra un aviso', (tester) async {
      catalog.resources = [];
      await showCatalog(tester);

      expect(
        find.text('Todavía no hay lugares para reservar.'),
        findsOneWidget,
      );
    });

    testWidgets('el detalle muestra el horario semanal y vuelve al catálogo',
        (tester) async {
      // Pantalla alta: la lista solo construye lo visible y el horario va después de las franjas.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await showCatalog(tester);

      await tester.tap(find.text('Consultorio dental'));
      await tester.pumpAndSettle();

      expect(find.text('Horario'), findsOneWidget);
      expect(find.text('09:00–13:00, 15:00–19:00'), findsOneWidget); // lunes
      expect(find.text('09:00–12:00'), findsOneWidget); // sábado
      expect(
        find.text('Cerrado'),
        findsNWidgets(5),
      ); // martes a viernes y domingo

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    });
  });

  group('franjas por fecha (RF-02)', () {
    Finder slot(String time, String status) =>
        find.bySemanticsLabel('$time, $status');

    // El estado de cada franja se lee por su etiqueta de accesibilidad, como un lector de pantalla.
    Future<void> openConsultorio(WidgetTester tester) async {
      await showCatalog(tester);
      await tester.tap(find.text('Consultorio dental'));
      await tester.pumpAndSettle();
    }

    testWidgets('hoy marca las pasadas, las ocupadas y las disponibles', (
      tester,
    ) async {
      slots.setTaken('consultorio', '2026-11-09', {'2026-11-09T11:00'});
      await openConsultorio(tester);

      expect(find.text('Hoy'), findsOneWidget);
      expect(slot('09:00', 'ya pasó'), findsOneWidget);
      expect(slot('10:00', 'ya pasó'), findsOneWidget); // empezó a las 10:00
      expect(slot('10:30', 'disponible'), findsOneWidget);
      expect(slot('11:00', 'ocupada'), findsOneWidget);
      expect(slot('18:30', 'disponible'), findsOneWidget);
    });

    testWidgets('una reserva nueva se ve al instante, sin recargar', (
      tester,
    ) async {
      await openConsultorio(tester);
      expect(slot('15:00', 'disponible'), findsOneWidget);

      slots.setTaken('consultorio', '2026-11-09', {'2026-11-09T15:00'});
      await tester.pumpAndSettle();

      expect(slot('15:00', 'ocupada'), findsOneWidget);
    });

    testWidgets('cambiar de día muestra sus franjas, o que está cerrado', (
      tester,
    ) async {
      await openConsultorio(tester);

      await tester.tap(find.text('Mañana')); // martes: cerrado
      await tester.pumpAndSettle();
      expect(find.text('Cerrado este día.'), findsOneWidget);

      await tester.tap(find.text('sáb 14'));
      await tester.pumpAndSettle();
      expect(slot('09:00', 'disponible'), findsOneWidget);
      expect(slot('11:30', 'disponible'), findsOneWidget);
      expect(slot('12:00', 'disponible'), findsNothing); // cierra a las 12:00
    });
  });

  group('reservar (RF-03)', () {
    Finder slot(String time, String status) =>
        find.bySemanticsLabel('$time, $status');

    Future<void> openConsultorio(WidgetTester tester) async {
      await showCatalog(tester);
      await tester.tap(find.text('Consultorio dental'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseAndConfirm(WidgetTester tester, String time) async {
      await tester.tap(slot(time, 'disponible'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reservar'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirmar reserva la franja, que pasa a ocupada', (
      tester,
    ) async {
      await openConsultorio(tester);

      await tester.tap(slot('15:00', 'disponible'));
      await tester.pumpAndSettle();
      expect(find.text('¿Reservar este turno?'), findsOneWidget);
      expect(find.text('Consultorio dental\nHoy, 15:00'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Reservar'));
      await tester.pumpAndSettle();

      expect(bookings.booked, ['u1:consultorio/2026-11-09T15:00']);
      expect(find.text('Turno reservado: Hoy, 15:00.'), findsOneWidget);
      expect(slot('15:00', 'ocupada'), findsOneWidget);
    });

    testWidgets('volver del diálogo no reserva', (tester) async {
      await openConsultorio(tester);

      await tester.tap(slot('15:00', 'disponible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(bookings.booked, isEmpty);
      expect(slot('15:00', 'disponible'), findsOneWidget);
    });

    testWidgets('si otra persona la ocupó antes, lo avisa', (tester) async {
      await openConsultorio(tester);
      bookings.failWith = const BookingFailure(BookingFailureReason.slotTaken);

      await chooseAndConfirm(tester, '15:00');

      expect(
        find.text('Ese horario acaba de ocuparse. Elige otro.'),
        findsOneWidget,
      );
      expect(bookings.booked, isEmpty);
    });

    testWidgets('las ocupadas y las pasadas no se pueden tocar', (
      tester,
    ) async {
      slots.setTaken('consultorio', '2026-11-09', {'2026-11-09T11:00'});
      await openConsultorio(tester);

      await tester.tap(slot('11:00', 'ocupada'));
      await tester.tap(slot('09:00', 'ya pasó'));
      await tester.pumpAndSettle();

      expect(find.text('¿Reservar este turno?'), findsNothing);
      final semantics = tester.getSemantics(slot('11:00', 'ocupada'));
      expect(semantics.flagsCollection.isButton, isFalse);
      expect(
        tester
            .getSemantics(slot('15:00', 'disponible'))
            .flagsCollection
            .isButton,
        isTrue,
      );
    });

    testWidgets('con 3 reservas activas no deja reservar otra', (tester) async {
      await openConsultorio(tester);

      for (final time in ['15:00', '15:30', '16:00']) {
        await chooseAndConfirm(tester, time);
      }
      expect(bookings.booked, hasLength(3));

      await chooseAndConfirm(tester, '16:30');

      expect(
        find.text(
          'Ya tienes 3 reservas activas. Cancela una para reservar otra.',
        ),
        findsOneWidget,
      );
      expect(bookings.booked, hasLength(3));
      expect(slot('16:30', 'disponible'), findsOneWidget);
    });

    testWidgets('las reservas que ya tenía también cuentan', (tester) async {
      bookings.existingActive = 3;
      await openConsultorio(tester);

      await chooseAndConfirm(tester, '15:00');

      expect(
        find.textContaining('Ya tienes 3 reservas activas'),
        findsOneWidget,
      );
      expect(bookings.booked, isEmpty);
    });

    testWidgets('si la franja empieza mientras se decide, no se reserva', (
      tester,
    ) async {
      await openConsultorio(tester);

      await tester.tap(slot('10:30', 'disponible'));
      await tester.pumpAndSettle();
      now = DateTime(2026, 11, 9, 10, 30);
      await tester.tap(find.widgetWithText(FilledButton, 'Reservar'));
      await tester.pumpAndSettle();

      expect(find.text('Ese horario ya pasó. Elige otro.'), findsOneWidget);
      expect(bookings.booked, isEmpty);
    });

    testWidgets('mientras reserva, no se puede tocar otra franja', (
      tester,
    ) async {
      await openConsultorio(tester);
      bookings.hold = Completer<void>();

      await chooseAndConfirm(tester, '15:00');
      await tester.tap(slot('16:00', 'disponible'));
      await tester.pumpAndSettle();
      expect(find.text('¿Reservar este turno?'), findsNothing);

      bookings.hold!.complete();
      await tester.pumpAndSettle();
      expect(bookings.booked, ['u1:consultorio/2026-11-09T15:00']);
    });
  });
}
