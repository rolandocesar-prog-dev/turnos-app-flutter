import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/app.dart';

void main() {
  testWidgets('muestra la pantalla de inicio', (tester) async {
    await tester.pumpWidget(const TurnosApp());

    expect(find.text('Turnos'), findsOneWidget);
    expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    expect(find.byIcon(Icons.event_available), findsOneWidget);
  });
}
