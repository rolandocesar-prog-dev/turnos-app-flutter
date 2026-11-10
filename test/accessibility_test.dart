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
import 'package:turnos_app/src/features/notifications/application/push_providers.dart';
import 'package:turnos_app/src/features/resources/application/resource_providers.dart';

import 'support/fakes.dart';

/// Accesibilidad de las pantallas principales (RNF-03, design.md §14): contraste AA, áreas
/// táctiles de 48 × 48 y botones con nombre, en tema claro y oscuro; y texto al 200 % sin
/// desbordes en un celular.
void main() {
  const admin = AppUser(uid: 'admin', email: 'admin@turnos.test');
  // Lunes 9 de noviembre de 2026, 10:10.
  final now = DateTime(2026, 11, 9, 10, 10);

  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.close());

  /// Abre la app con datos de ejemplo y lleva a [location] (o al login si es `null`).
  Future<void> open(WidgetTester tester, String? location) async {
    final slots = FakeSlotRepository()
      ..setTaken('cancha', '2026-11-09', {'2026-11-09T18:00'});
    final bookings = FakeBookingRepository(slots)
      ..add(testBooking('b1', DateTime(2026, 11, 9, 15), uid: admin.uid))
      ..add(testBooking('b2', DateTime(2026, 11, 9, 11), uid: admin.uid))
      ..add(
        testBooking(
          'b3',
          DateTime(2026, 11, 2, 9),
          uid: admin.uid,
          status: BookingStatus.cancelled,
          cancelReason: 'Corte de luz',
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userProfileRepositoryProvider.overrideWithValue(
            FakeUserProfileRepository(admins: {admin.uid}),
          ),
          googleSignInAvailableProvider.overrideWithValue(true),
          resourceRepositoryProvider.overrideWithValue(
            FakeResourceRepository(),
          ),
          slotRepositoryProvider.overrideWithValue(slots),
          bookingRepositoryProvider.overrideWithValue(bookings),
          adminBookingRepositoryProvider.overrideWithValue(
            FakeAdminBookingRepository(
              bookings,
              emails: {admin.uid: admin.email!},
            ),
          ),
          resourceEditorProvider.overrideWithValue(FakeResourceEditor()),
          clockProvider.overrideWithValue(() => now),
          pushAvailableProvider.overrideWithValue(true),
          pushRepositoryProvider.overrideWithValue(FakePushRepository()),
        ],
        child: const TurnosApp(),
      ),
    );
    auth.emit(location == null ? null : admin);
    await tester.pumpAndSettle();
    if (location != null && location != '/') {
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
      await tester.pumpAndSettle();
    }
  }

  // Pantalla → (ruta, un texto que prueba que se llegó a ella).
  const screens = {
    'acceso': (null, 'Inicia sesión'),
    'catálogo': ('/', 'Reserva tu turno en segundos'),
    'detalle con franjas': ('/recursos/cancha', 'Horario'),
    'mis reservas': ('/mis-reservas', 'Próximas'),
    'panel': ('/admin', 'Recursos'),
    'formulario de recurso': ('/admin/recursos/consultorio', 'Editar recurso'),
    'reservas del día': ('/admin/reservas', 'Reservas del día'),
  };

  for (final brightness in Brightness.values) {
    group('guías de accesibilidad, tema ${brightness.name}', () {
      for (final MapEntry(key: name, value: (location, marker))
          in screens.entries) {
        testWidgets(name, (tester) async {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
          final semantics = tester.ensureSemantics();

          await open(tester, location);
          expect(find.text(marker), findsWidgets);

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          semantics.dispose();
        });
      }
    });
  }

  group('texto al 200 % en un celular', () {
    for (final MapEntry(key: name, value: (location, marker))
        in screens.entries) {
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        // Un desborde se informa como excepción y hace fallar la prueba; se imprime completo para
        // saber qué widget lo causó.
        final original = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          original?.call(details);
        };
        addTearDown(() => FlutterError.onError = original);
        await open(tester, location);
        expect(tester.takeException(), isNull);
        // Recorre la pantalla hasta abajo, porque las listas construyen solo lo visible, y anota
        // si en algún momento apareció el texto que prueba que se llegó a ella.
        var seen = find.text(marker).evaluate().isNotEmpty;
        final scrollables = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (scrollables.evaluate().isNotEmpty) {
          final position =
              tester.state<ScrollableState>(scrollables.first).position;
          while (position.pixels < position.maxScrollExtent) {
            await tester.drag(scrollables.first, const Offset(0, -300));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            seen = seen || find.text(marker).evaluate().isNotEmpty;
          }
        }
        expect(seen, isTrue, reason: 'No apareció «$marker»');
      });
    }
  });
}
