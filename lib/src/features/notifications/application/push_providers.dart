import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_setup.dart';
import '../../auth/application/auth_providers.dart';
import '../data/firebase_push_repository.dart';
import '../domain/push_repository.dart';

/// Hay avisos push en el entorno `production`, en web y Android (design.md §13). Con los
/// emuladores no hay FCM. Las pruebas lo reemplazan con un override.
final pushAvailableProvider = Provider<bool>(
  (ref) => pushAvailableFor(
    environment: parseFirebaseEnvironment(firebaseEnvironment),
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  ),
);

bool pushAvailableFor({
  required FirebaseEnvironment environment,
  required bool isWeb,
  required TargetPlatform platform,
}) =>
    environment == FirebaseEnvironment.production &&
    (isWeb || platform == TargetPlatform.android);

/// FCM; las pruebas lo reemplazan con un override.
final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => FirebasePushRepository(FirebaseMessaging.instance),
);

/// Si los avisos están activos en este dispositivo para el usuario con sesión. Al abrir, si el
/// permiso ya estaba dado, vuelve a guardar el token (puede haber cambiado); los tokens renovados
/// se guardan solos.
final pushControllerProvider =
    AsyncNotifierProvider<PushController, bool>(PushController.new);

class PushController extends AsyncNotifier<bool> {
  StreamSubscription<String>? _refreshes;

  @override
  Future<bool> build() async {
    ref.onDispose(() => _refreshes?.cancel());
    if (!ref.watch(pushAvailableProvider)) return false;
    final user = ref.watch(authStateProvider).value;
    if (user == null) return false;
    // Al abrir no se molesta con errores: si algo falla, la tarjeta ofrece activarlos de nuevo.
    try {
      if (!await ref.read(pushRepositoryProvider).isAllowed()) return false;
      await _register(user.uid);
      return true;
    } on PushFailure {
      return false;
    }
  }

  /// Pide el permiso y guarda el token. Un error queda en el estado (`PushFailure`).
  Future<void> enable() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authStateProvider.future);
      if (user == null) throw const PushFailure(PushFailureReason.unknown);
      await _register(user.uid);
      return true;
    });
  }

  Future<void> _register(String uid) async {
    final push = ref.read(pushRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    try {
      await profiles.addFcmToken(uid, await push.enable());
    } on PushFailure {
      rethrow;
    } on Exception {
      throw const PushFailure(PushFailureReason.unknown);
    }
    await _refreshes?.cancel();
    _refreshes = push.tokenRefreshes.listen(
      (token) => profiles.addFcmToken(uid, token).ignore(),
    );
  }
}
