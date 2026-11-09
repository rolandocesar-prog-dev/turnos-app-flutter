import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/auth/application/auth_controller.dart';
import 'package:turnos_app/src/features/auth/application/auth_providers.dart';
import 'package:turnos_app/src/features/auth/domain/auth_failure.dart';

import '../../support/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeUserProfileRepository profiles;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeUserProfileRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userProfileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  AuthController controller() =>
      container.read(authControllerProvider.notifier);

  test('registrarse crea la cuenta y el perfil de cliente', () async {
    await controller().register(email: 'ana@ejemplo.com', password: 'secreto1');

    expect(auth.calls, ['register:ana@ejemplo.com']);
    expect(profiles.ensured.single.uid, 'uid-ana@ejemplo.com');
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('si el registro falla, no se crea perfil y queda el error', () async {
    auth.failWith = const AuthFailure(AuthFailureReason.emailInUse);

    await controller().register(email: 'ana@ejemplo.com', password: 'secreto1');

    expect(profiles.ensured, isEmpty);
    final state = container.read(authControllerProvider);
    expect((state.error! as AuthFailure).reason, AuthFailureReason.emailInUse);
  });

  test('iniciar sesión no toca el perfil', () async {
    await controller().signIn(email: 'ana@ejemplo.com', password: 'secreto1');

    expect(auth.calls, ['signIn:ana@ejemplo.com']);
    expect(profiles.ensured, isEmpty);
  });

  test('con Google se asegura el perfil de cliente', () async {
    await controller().signInWithGoogle();

    expect(auth.calls, ['google']);
    expect(profiles.ensured.single.email, 'google.user@ejemplo.com');
  });

  test('si se cierra la ventana de Google, queda el motivo «cancelado»',
      () async {
    auth.failWith = const AuthFailure(AuthFailureReason.cancelled);

    await controller().signInWithGoogle();

    expect(profiles.ensured, isEmpty);
    final state = container.read(authControllerProvider);
    expect((state.error! as AuthFailure).reason, AuthFailureReason.cancelled);
  });

  test('cerrar sesión', () async {
    await controller().signOut();

    expect(auth.calls, ['signOut']);
  });
}
