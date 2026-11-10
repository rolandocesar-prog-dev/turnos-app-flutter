import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:turnos_app/src/app.dart';
import 'package:turnos_app/src/features/auth/application/auth_providers.dart';
import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/bookings/application/booking_providers.dart';
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

  setUp(() {
    auth = FakeAuthRepository();
    catalog = FakeResourceRepository([testCancha, testConsultorio, sala]);
    slots = FakeSlotRepository();
  });
  tearDown(() => auth.close());

  Future<void> signIn(WidgetTester tester, AppUser user) async {
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
          bookingRepositoryProvider
              .overrideWithValue(FakeBookingRepository(slots)),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 9, 10)),
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
