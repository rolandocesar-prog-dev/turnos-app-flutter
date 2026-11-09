import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/loading_page.dart';
import '../features/auth/application/auth_providers.dart';
import '../features/auth/domain/app_user.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/bookings/presentation/my_bookings_page.dart';
import '../features/resources/presentation/catalog_page.dart';
import '../features/resources/presentation/resource_detail_page.dart';
import 'session_redirect.dart';

/// Router de la app: se vuelve a evaluar cada vez que cambia la sesión (design.md §7).
final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AsyncValue<AppUser?>>(const AsyncLoading());
  ref.listen(
    authStateProvider,
    (_, next) => session.value = next,
    fireImmediately: true,
  );

  final router = GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: session,
    redirect: (context, state) =>
        sessionRedirect(session.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const CatalogPage(),
        routes: [
          // Anidada en el inicio: la barra muestra el botón para volver al catálogo.
          GoRoute(
            path: 'recursos/:id',
            builder: (context, state) =>
                ResourceDetailPage(resourceId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'mis-reservas',
            builder: (context, state) => const MyBookingsPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingPage(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
