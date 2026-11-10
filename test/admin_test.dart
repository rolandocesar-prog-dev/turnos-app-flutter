import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turnos_app/src/app.dart';
import 'package:turnos_app/src/features/admin/application/admin_providers.dart';
import 'package:turnos_app/src/features/auth/application/auth_providers.dart';
import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/bookings/application/booking_providers.dart';
import 'package:turnos_app/src/features/bookings/domain/booking.dart';
import 'package:turnos_app/src/features/bookings/domain/booking_failure.dart';
import 'package:turnos_app/src/features/resources/application/resource_providers.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';

import 'support/fakes.dart';

/// Panel de administración (RF-06, design.md §11).
void main() {
  const admin = AppUser(uid: 'admin', email: 'admin@turnos.test');
  const client = AppUser(uid: 'u1', email: 'ana@ejemplo.com');
  const sala = Resource(
    id: 'sala',
    name: 'Sala de ensayo',
    description: 'En remodelación.',
    slotMinutes: 120,
    active: false,
    weeklySchedule: {},
  );

  late FakeAuthRepository auth;
  late FakeResourceRepository catalog;
  late FakeSlotRepository slots;
  late FakeResourceEditor editor;
  late FakeBookingRepository bookings;
  late FakeAdminBookingRepository adminBookings;

  setUp(() {
    auth = FakeAuthRepository();
    catalog = FakeResourceRepository([testCancha, testConsultorio, sala]);
    slots = FakeSlotRepository();
    editor = FakeResourceEditor();
    bookings = FakeBookingRepository(slots);
    adminBookings = FakeAdminBookingRepository(
      bookings,
      emails: {'u1': 'ana@ejemplo.com', 'u2': 'luis@ejemplo.com'},
    );
  });
  tearDown(() => auth.close());

  Future<void> signIn(WidgetTester tester, AppUser user) async {
    // Pantalla alta: el formulario entero cabe sin desplazarse.
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userProfileRepositoryProvider.overrideWithValue(
            FakeUserProfileRepository(admins: {admin.uid}),
          ),
          googleSignInAvailableProvider.overrideWithValue(false),
          resourceRepositoryProvider.overrideWithValue(catalog),
          slotRepositoryProvider.overrideWithValue(slots),
          bookingRepositoryProvider.overrideWithValue(bookings),
          // Lunes 9 de noviembre de 2026, 10:00.
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 9, 10)),
          resourceEditorProvider.overrideWithValue(editor),
          adminBookingRepositoryProvider.overrideWithValue(adminBookings),
        ],
        child: const TurnosApp(),
      ),
    );
    auth.emit(user);
    await tester.pumpAndSettle();
  }

  void goTo(WidgetTester tester, String location) => GoRouter.of(
        tester.element(find.text('Reserva tu turno en segundos')),
      ).go(location);

  testWidgets('el administrador entra al panel y ve también los inactivos',
      (tester) async {
    await signIn(tester, admin);

    await tester.tap(find.byTooltip('Administración'));
    await tester.pumpAndSettle();

    expect(find.text('Recursos'), findsOneWidget);
    expect(find.text('Cancha de fútbol 5'), findsOneWidget);
    expect(find.text('Sala de ensayo'), findsOneWidget);
    expect(
      find.textContaining('Inactivo: no aparece en el catálogo'),
      findsOneWidget,
    );
  });

  testWidgets('un cliente no ve el acceso y /admin lo devuelve al inicio',
      (tester) async {
    await signIn(tester, client);

    expect(find.byTooltip('Administración'), findsNothing);
    // El catálogo no muestra los inactivos.
    expect(find.text('Sala de ensayo'), findsNothing);

    goTo(tester, '/admin');
    await tester.pumpAndSettle();

    expect(find.text('Administración'), findsNothing);
    expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
  });

  group('formulario de recurso (RF-06)', () {
    Finder field(String label) => find.widgetWithText(TextFormField, label);

    Future<void> openNew(WidgetTester tester) async {
      await signIn(tester, admin);
      goTo(tester, '/admin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nuevo recurso'));
      await tester.pumpAndSettle();
    }

    testWidgets('crea un recurso con su horario', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Nombre'), '  Cancha de pádel ');
      await tester.enterText(field('Descripción'), 'Al aire libre.');
      await tester.enterText(field('Lunes'), '08:00-12:00, 16:00-22:00');
      await tester.enterText(field('Sábado'), '9:00-13:00');
      await tester.tap(find.text('Turnos de 1 h'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turnos de 1 h 30 min').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final created = editor.created.single;
      expect(created.name, 'Cancha de pádel');
      expect(created.description, 'Al aire libre.');
      expect(created.slotMinutes, 90);
      expect(created.active, isTrue);
      expect(created.weeklySchedule, {
        DateTime.monday: const [TimeRange(480, 720), TimeRange(960, 1320)],
        DateTime.saturday: const [TimeRange(540, 780)],
      });
      expect(find.text('Recurso guardado: Cancha de pádel.'), findsOneWidget);
      expect(find.text('Recursos'), findsOneWidget);
    });

    testWidgets('valida antes de guardar', (tester) async {
      await openNew(tester);

      await tester.enterText(field('Martes'), '09:00-13:00, 12:00-14:00');
      await tester.enterText(field('Miércoles'), 'de 9 a 13');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe un nombre.'), findsOneWidget);
      expect(
        find.text('Los intervalos deben ir en orden y sin solaparse.'),
        findsOneWidget,
      );
      expect(find.textContaining('no es un intervalo'), findsOneWidget);
      expect(editor.created, isEmpty);
    });

    testWidgets('edita un recurso: lo desactiva y cambia sus días bloqueados',
        (tester) async {
      catalog.resources = [
        const Resource(
          id: 'consultorio',
          name: 'Consultorio dental',
          description: 'Consulta general.',
          slotMinutes: 30,
          active: true,
          photoUrl: 'https://ejemplo.com/foto.jpg',
          weeklySchedule: {
            DateTime.monday: [TimeRange(540, 780), TimeRange(900, 1140)],
          },
          blockedDates: {'2026-12-25'},
        ),
      ];
      await signIn(tester, admin);
      goTo(tester, '/admin');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Consultorio dental'));
      await tester.pumpAndSettle();

      expect(find.text('Editar recurso'), findsOneWidget);
      expect(find.text('09:00-13:00, 15:00-19:00'), findsOneWidget);
      expect(find.text('vie 25 dic 2026'), findsOneWidget);

      await tester.tap(find.text('Activo'));
      await tester.tap(find.byTooltip('Quitar vie 25 dic 2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar día bloqueado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24'));
      // El botón de confirmar es el último del diálogo (su texto depende de la traducción).
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(find.text('mar 24 nov 2026'), findsOneWidget);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final updated = editor.updated.single;
      expect(updated.id, 'consultorio');
      expect(updated.active, isFalse);
      expect(updated.blockedDates, {'2026-11-24'});
      expect(updated.photoUrl, 'https://ejemplo.com/foto.jpg');
      expect(updated.weeklySchedule[DateTime.monday], hasLength(2));
    });

    testWidgets('si no se puede guardar, lo dice y sigue en el formulario',
        (tester) async {
      await openNew(tester);
      editor.failWith = Exception('permission-denied');

      await tester.enterText(field('Nombre'), 'Sala');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No se pudo guardar el recurso. Revisa tu conexión e inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nuevo recurso'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
    });

    testWidgets('un id que no existe lo dice', (tester) async {
      await signIn(tester, admin);
      goTo(tester, '/admin/recursos/no-existe');
      await tester.pumpAndSettle();

      expect(find.text('Ese recurso no existe.'), findsOneWidget);
    });
  });

  group('reservas del día (RF-06)', () {
    final today = DateTime(2026, 11, 9);
    late Booking pending;

    setUp(() {
      pending = testBooking('b1', today.add(const Duration(hours: 15)));
      bookings
        ..add(pending)
        ..add(
          testBooking(
            'b2',
            today.add(const Duration(hours: 9)),
            uid: 'u2',
            resource: testCancha,
          ),
        )
        ..add(
          testBooking(
            'b3',
            today.add(const Duration(hours: 11, minutes: 30)),
            status: BookingStatus.cancelled,
            cancelReason: 'Lluvia',
          ),
        )
        ..add(
          testBooking(
            'b4',
            today.add(const Duration(days: 1, hours: 18)),
            uid: 'u2',
          ),
        );
    });

    Future<void> openDay(WidgetTester tester) async {
      await signIn(tester, admin);
      goTo(tester, '/admin');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reservas del día'));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra las de hoy de todos los clientes, en orden',
        (tester) async {
      await openDay(tester);

      expect(find.text('Hoy'), findsOneWidget);
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(titles, [
        '09:00–10:00 · Cancha de fútbol 5',
        '11:30–12:30 · Consultorio dental',
        '15:00–16:00 · Consultorio dental',
      ]);
      expect(find.text('luis@ejemplo.com\nYa empezó'), findsOneWidget);
      expect(
        find.text('ana@ejemplo.com\nCancelada por el negocio: Lluvia'),
        findsOneWidget,
      );
      expect(find.text('ana@ejemplo.com\nActiva'), findsOneWidget);
      // Solo la que no empezó ni está cancelada se puede cancelar.
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('cambia de día con las flechas', (tester) async {
      await openDay(tester);

      await tester.tap(find.byTooltip('Día siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Mañana'), findsOneWidget);
      expect(find.text('18:00–19:00 · Consultorio dental'), findsOneWidget);

      await tester.tap(find.byTooltip('Día anterior'));
      await tester.tap(find.byTooltip('Día anterior'));
      await tester.pumpAndSettle();
      expect(find.text('No hay reservas para dom 8 nov.'), findsOneWidget);
    });

    testWidgets('cancela con motivo y libera la franja', (tester) async {
      await openDay(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      expect(
        find.text('Escribe el motivo (al menos 3 caracteres).'),
        findsOneWidget,
      );
      expect(bookings.cancelled, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'),
        '  Corte de luz ',
      );
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();

      expect(bookings.cancelled, ['b1']);
      expect(
        find.text('Reserva cancelada. El horario quedó libre.'),
        findsOneWidget,
      );
      expect(
        find.text('ana@ejemplo.com\nCancelada por el negocio: Corte de luz'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsNothing);
    });

    testWidgets('volver del diálogo no cancela', (tester) async {
      await openDay(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(bookings.cancelled, isEmpty);
    });

    testWidgets('si el servidor la rechaza, muestra el motivo', (tester) async {
      await openDay(tester);
      adminBookings.failWith =
          const BookingFailure(BookingFailureReason.notCancellable);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'),
        'Lluvia',
      );
      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esa reserva ya empezó o ya estaba cancelada.'),
        findsOneWidget,
      );
      expect(bookings.cancelled, isEmpty);
    });

    testWidgets('el cliente ve el motivo en Mis reservas', (tester) async {
      await signIn(tester, client);

      await tester.tap(find.byTooltip('Mis reservas'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cancelada por el negocio: Lluvia'),
        findsOneWidget,
      );
    });
  });

  testWidgets('si los recursos no cargan, el panel lo dice', (tester) async {
    await signIn(tester, admin);
    catalog.failWith = Exception('permiso denegado');

    goTo(tester, '/admin');
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudieron cargar los recursos. Revisa tu conexión.'),
      findsOneWidget,
    );
  });
}
