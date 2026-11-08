import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/app.dart';
import 'package:turnos_app/src/features/auth/application/auth_providers.dart';
import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/auth/domain/auth_repository.dart';

/// Sesión controlada por la prueba, sin Firebase (design.md §6).
class FakeAuthRepository implements AuthRepository {
  final _changes = StreamController<AppUser?>.broadcast();

  void emit(AppUser? user) => _changes.add(user);

  Future<void> close() => _changes.close();

  @override
  Stream<AppUser?> authStateChanges() => _changes.stream;
}

void main() {
  const user = AppUser(uid: 'u1', email: 'ana@ejemplo.com');
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.close());

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: const TurnosApp(),
        ),
      );

  testWidgets('mientras se lee la sesión muestra la pantalla de carga', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pump();

    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
  });

  testWidgets('sin sesión muestra el login', (tester) async {
    await pumpApp(tester);
    auth.emit(null);
    await tester.pumpAndSettle();

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.text('Reserva tu turno en segundos'), findsNothing);
  });

  testWidgets('con sesión muestra el inicio', (tester) async {
    await pumpApp(tester);
    auth.emit(user);
    await tester.pumpAndSettle();

    expect(find.text('Reserva tu turno en segundos'), findsOneWidget);
    expect(find.byIcon(Icons.event_available), findsOneWidget);
  });

  testWidgets('al iniciar y cerrar sesión cambia de pantalla sola', (
    tester,
  ) async {
    await pumpApp(tester);
    auth.emit(null);
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión'), findsOneWidget);

    auth.emit(user);
    await tester.pumpAndSettle();
    expect(find.text('Reserva tu turno en segundos'), findsOneWidget);

    auth.emit(null);
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión'), findsOneWidget);
  });
}
