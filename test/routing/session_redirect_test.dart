import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/auth/domain/app_user.dart';
import 'package:turnos_app/src/features/auth/domain/user_profile_repository.dart';
import 'package:turnos_app/src/routing/session_redirect.dart';

void main() {
  const user = AppUser(uid: 'u1', email: 'ana@ejemplo.com');

  group('mientras se carga la sesión', () {
    const loading = AsyncLoading<AppUser?>();

    test('espera en la pantalla de carga', () {
      expect(sessionRedirect(loading, AppRoutes.home), AppRoutes.loading);
      expect(sessionRedirect(loading, AppRoutes.login), AppRoutes.loading);
      expect(sessionRedirect(loading, AppRoutes.loading), isNull);
    });
  });

  group('sin sesión', () {
    const signedOut = AsyncData<AppUser?>(null);

    test('las rutas protegidas llevan al login', () {
      expect(sessionRedirect(signedOut, AppRoutes.home), AppRoutes.login);
      expect(sessionRedirect(signedOut, AppRoutes.loading), AppRoutes.login);
    });

    test('el login se queda donde está', () {
      expect(sessionRedirect(signedOut, AppRoutes.login), isNull);
    });

    test('si la sesión no se pudo leer, se trata como sin sesión', () {
      final failed =
          AsyncError<AppUser?>(Exception('sin red'), StackTrace.empty);
      expect(sessionRedirect(failed, AppRoutes.home), AppRoutes.login);
    });
  });

  group('con sesión', () {
    const signedIn = AsyncData<AppUser?>(user);

    test('el login y la carga llevan al inicio', () {
      expect(sessionRedirect(signedIn, AppRoutes.login), AppRoutes.home);
      expect(sessionRedirect(signedIn, AppRoutes.loading), AppRoutes.home);
    });

    test('las rutas protegidas se quedan donde están', () {
      expect(sessionRedirect(signedIn, AppRoutes.home), isNull);
    });
  });

  group('rutas de administración (design.md §11)', () {
    const admin = AsyncData(UserRole.admin);
    const client = AsyncData(UserRole.client);
    const loading = AsyncLoading<UserRole>();
    final failed = AsyncError<UserRole>(Exception('sin red'), StackTrace.empty);

    test('el administrador entra a /admin y a sus subrutas', () {
      expect(adminRedirect(admin, AppRoutes.admin), isNull);
      expect(adminRedirect(admin, '/admin/reservas'), isNull);
    });

    test('un cliente, o un rol que no se pudo leer, vuelve al inicio', () {
      expect(adminRedirect(client, AppRoutes.admin), AppRoutes.home);
      expect(adminRedirect(client, '/admin/recursos/nuevo'), AppRoutes.home);
      expect(adminRedirect(failed, AppRoutes.admin), AppRoutes.home);
    });

    test('mientras el rol carga, la página espera', () {
      expect(adminRedirect(loading, AppRoutes.admin), isNull);
    });

    test('las demás rutas no dependen del rol', () {
      expect(adminRedirect(client, AppRoutes.home), isNull);
      expect(adminRedirect(client, AppRoutes.myBookings), isNull);
      expect(adminRedirect(client, '/administrar'), isNull);
    });
  });
}
