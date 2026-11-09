// Prueba de integración reservar → cancelar sobre la app real, contra los emuladores de Firebase
// con los datos de `npm run seed` (design.md §10). Cómo correrla: README, «Prueba de integración».
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:turnos_app/src/app.dart';
import 'package:turnos_app/src/core/firebase/firebase_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reservar una franja, verla en Mis reservas y cancelarla', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await initializeFirebase();
    await tester.pumpWidget(const ProviderScope(child: TurnosApp()));

    // Los datos llegan de los emuladores: se espera a que aparezcan, con un tope.
    Future<void> waitFor(
      Finder finder, {
      Duration timeout = const Duration(seconds: 20),
    }) async {
      final end = DateTime.now().add(timeout);
      while (finder.evaluate().isEmpty) {
        if (DateTime.now().isAfter(end)) {
          throw TestFailure('No apareció a tiempo: $finder');
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tapAndWait(Finder target, Finder next) async {
      await tester.tap(target);
      await waitFor(next);
    }

    // El botón «Mis reservas» solo está en el catálogo; se espera a que termine la transición
    // para no tocar algo de la pantalla que se va.
    Future<void> backToCatalog() async {
      await tapAndWait(find.byType(BackButton), find.byTooltip('Mis reservas'));
      await tester.pumpAndSettle();
    }

    // Una cuenta nueva en cada ejecución.
    await waitFor(find.text('Inicia sesión'));
    await tapAndWait(
      find.text('¿No tienes cuenta? Crea una'),
      find.text('Crear cuenta'),
    );
    final email = 'e2e.${DateTime.now().millisecondsSinceEpoch}@ejemplo.com';
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'prueba123',
    );
    await tapAndWait(
      find.byType(FilledButton),
      find.text('Cancha de fútbol 5'),
    );

    // Mañana: la primera franja libre está a más de 2 horas, así que se podrá cancelar.
    await tapAndWait(find.text('Cancha de fútbol 5'), find.text('Mañana'));
    final available = find.bySemanticsLabel(RegExp(r'^\d\d:\d\d, disponible$'));
    await tapAndWait(find.text('Mañana'), available);
    final label = tester.getSemantics(available.first).label;
    final time = label.split(',').first;

    await tapAndWait(available.first, find.text('¿Reservar este turno?'));
    await tapAndWait(
      find.widgetWithText(FilledButton, 'Reservar'),
      find.text('Turno reservado: Mañana, $time.'),
    );
    await waitFor(find.bySemanticsLabel('$time, ocupada'));

    // Mis reservas la muestra entre las próximas, con su botón de cancelar.
    await backToCatalog();
    final booking = find.textContaining('Mañana, $time–');
    await tapAndWait(find.byTooltip('Mis reservas'), booking);
    expect(find.text('Próximas'), findsOneWidget);

    await tapAndWait(
      find.widgetWithText(TextButton, 'Cancelar'),
      find.text('¿Cancelar esta reserva?'),
    );
    await tapAndWait(
      find.widgetWithText(FilledButton, 'Cancelar reserva'),
      find.text('Reserva cancelada. El horario quedó libre.'),
    );
    await waitFor(find.textContaining('Cancelada'));
    expect(find.text('Anteriores'), findsOneWidget);

    // La franja vuelve a estar disponible para cualquiera.
    await backToCatalog();
    await tapAndWait(find.text('Cancha de fútbol 5'), find.text('Mañana'));
    await tapAndWait(
      find.text('Mañana'),
      find.bySemanticsLabel('$time, disponible'),
    );

    semantics.dispose();
  });
}
