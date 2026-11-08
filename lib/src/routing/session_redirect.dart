import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/app_user.dart';

/// Rutas de la app (design.md §7).
abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const loading = '/cargando';
}

/// Regla de redirección según la sesión (RF-01). Devuelve la ruta a la que hay que ir o
/// `null` para quedarse en [location].
///
/// - Mientras la sesión se carga, se espera en [AppRoutes.loading]: así no se manda al login a
///   quien ya inició sesión.
/// - Sin sesión (o si la sesión no se pudo leer), solo se permite [AppRoutes.login].
/// - Con sesión, el login y la espera llevan al inicio.
String? sessionRedirect(AsyncValue<AppUser?> session, String location) {
  if (session.isLoading && !session.hasValue) {
    return location == AppRoutes.loading ? null : AppRoutes.loading;
  }
  final signedIn = session.hasValue && session.value != null;
  if (!signedIn) {
    return location == AppRoutes.login ? null : AppRoutes.login;
  }
  if (location == AppRoutes.login || location == AppRoutes.loading) {
    return AppRoutes.home;
  }
  return null;
}
