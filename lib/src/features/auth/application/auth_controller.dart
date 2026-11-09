import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Acciones de acceso. Su estado es el de la última acción: en curso, error (`AuthFailure`) o
/// terminada. La navegación no depende de él: la decide la sesión (design.md §7).
final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signIn({required String email, required String password}) =>
      _run(() async {
        await ref
            .read(authRepositoryProvider)
            .signInWithEmail(email: email, password: password);
      });

  /// Crea la cuenta y su perfil con rol `client` (RF-01).
  Future<void> register({required String email, required String password}) =>
      _run(() async {
        final user = await ref
            .read(authRepositoryProvider)
            .registerWithEmail(email: email, password: password);
        await ref.read(userProfileRepositoryProvider).ensureProfile(user);
      });

  Future<void> signOut() =>
      _run(() => ref.read(authRepositoryProvider).signOut());

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
  }
}
