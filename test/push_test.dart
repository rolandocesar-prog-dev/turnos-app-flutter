import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/app.dart';
import 'package:turnos_app/src/core/firebase/firebase_setup.dart';
import 'package:turnos_app/src/features/auth/application/auth_providers.dart';
import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/bookings/application/booking_providers.dart';
import 'package:turnos_app/src/features/notifications/application/push_providers.dart';
import 'package:turnos_app/src/features/notifications/data/firebase_push_repository.dart';
import 'package:turnos_app/src/features/resources/application/resource_providers.dart';

import 'support/fakes.dart';

/// Avisos push en «Mis reservas» (RF-05, design.md §13).
void main() {
  group('dónde hay avisos', () {
    test('solo en production, en web y Android', () {
      bool available(FirebaseEnvironment env, bool web, TargetPlatform p) =>
          pushAvailableFor(environment: env, isWeb: web, platform: p);

      const prod = FirebaseEnvironment.production;
      expect(available(prod, true, TargetPlatform.windows), isTrue);
      expect(available(prod, false, TargetPlatform.android), isTrue);
      expect(available(prod, false, TargetPlatform.iOS), isFalse);
      expect(
        available(FirebaseEnvironment.emulators, true, TargetPlatform.android),
        isFalse,
      );
    });

    test('el permiso provisional también sirve', () {
      expect(isAllowedStatus(AuthorizationStatus.authorized), isTrue);
      expect(isAllowedStatus(AuthorizationStatus.provisional), isTrue);
      expect(isAllowedStatus(AuthorizationStatus.denied), isFalse);
      expect(isAllowedStatus(AuthorizationStatus.deniedPermanently), isFalse);
      expect(isAllowedStatus(AuthorizationStatus.notDetermined), isFalse);
    });
  });

  group('tarjeta de avisos', () {
    const user = AppUser(uid: 'u1', email: 'ana@ejemplo.com');
    late FakeAuthRepository auth;
    late FakeUserProfileRepository profiles;
    late FakePushRepository push;

    setUp(() {
      auth = FakeAuthRepository();
      profiles = FakeUserProfileRepository();
      push = FakePushRepository();
    });
    tearDown(() => auth.close());

    Future<void> openMyBookings(
      WidgetTester tester, {
      bool available = true,
    }) async {
      final slots = FakeSlotRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userProfileRepositoryProvider.overrideWithValue(profiles),
            googleSignInAvailableProvider.overrideWithValue(false),
            resourceRepositoryProvider
                .overrideWithValue(FakeResourceRepository()),
            slotRepositoryProvider.overrideWithValue(slots),
            bookingRepositoryProvider
                .overrideWithValue(FakeBookingRepository(slots)),
            clockProvider.overrideWithValue(() => DateTime(2026, 11, 9, 10)),
            pushAvailableProvider.overrideWithValue(available),
            pushRepositoryProvider.overrideWithValue(push),
          ],
          child: const TurnosApp(),
        ),
      );
      auth.emit(user);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mis reservas'));
      await tester.pumpAndSettle();
    }

    testWidgets('activar pide el permiso y guarda el token', (tester) async {
      await openMyBookings(tester);

      expect(find.textContaining('recordatorio 1 hora antes'), findsOneWidget);
      expect(push.requests, isEmpty);

      await tester.tap(find.text('Activar avisos'));
      await tester.pumpAndSettle();

      expect(push.requests, ['permiso']);
      expect(profiles.tokens, ['u1:token-1']);
      expect(
        find.text('Avisos activados en este dispositivo.'),
        findsOneWidget,
      );
      expect(
        find.text('Listo: te avisaremos 1 hora antes de cada turno.'),
        findsOneWidget,
      );
    });

    testWidgets('si se niega el permiso, explica cómo habilitarlo',
        (tester) async {
      push.grant = false;
      await openMyBookings(tester);

      await tester.tap(find.text('Activar avisos'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Los avisos están bloqueados.'),
        findsOneWidget,
      );
      expect(find.text('Activar avisos'), findsOneWidget);
      expect(profiles.tokens, isEmpty);
    });

    testWidgets(
        'con el permiso ya dado, guarda el token al abrir y los renovados',
        (tester) async {
      push.allowed = true;
      await openMyBookings(tester);

      expect(
        find.text('Avisos activados en este dispositivo.'),
        findsOneWidget,
      );
      expect(push.requests, isEmpty);
      expect(profiles.tokens, ['u1:token-1']);

      push.refresh('token-2');
      await tester.pumpAndSettle();
      expect(profiles.tokens, ['u1:token-1', 'u1:token-2']);
    });

    testWidgets('sin FCM (emuladores) no aparece', (tester) async {
      await openMyBookings(tester, available: false);

      expect(find.text('Activar avisos'), findsNothing);
      expect(find.text('Próximas'), findsOneWidget);
    });
  });
}
