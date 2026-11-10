import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../domain/push_repository.dart';

/// Avisos con Firebase Cloud Messaging (design.md §13). El dispositivo se identifica con su id de
/// instalación (FID), que entrega `register()` por `onRegistered` (firebase_messaging 17 dejó de
/// usar `getToken`). En web se usa la clave VAPID por defecto de Firebase y
/// `web/firebase-messaging-sw.js`.
class FirebasePushRepository implements PushRepository {
  const FirebasePushRepository(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<bool> isAllowed() async {
    final settings = await _messaging.getNotificationSettings();
    return isAllowedStatus(settings.authorizationStatus);
  }

  @override
  Future<String> enable() async {
    final settings = await _messaging.requestPermission();
    if (!isAllowedStatus(settings.authorizationStatus)) {
      throw const PushFailure(PushFailureReason.denied);
    }
    try {
      // Se escucha antes de registrar, para no perder el aviso.
      final registered =
          _messaging.onRegistered.first.timeout(const Duration(seconds: 20));
      await _messaging.register();
      return await registered;
    } on Exception {
      throw const PushFailure(PushFailureReason.unknown);
    }
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.onRegistered;
}

/// Permiso concedido; el provisional de iOS también sirve (avisos silenciosos).
bool isAllowedStatus(AuthorizationStatus status) => switch (status) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => true,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently ||
      AuthorizationStatus.notDetermined =>
        false,
    };
