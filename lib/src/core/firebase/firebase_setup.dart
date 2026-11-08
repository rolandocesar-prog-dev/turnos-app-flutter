import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Entorno de Firebase elegido con `--dart-define=FIREBASE_ENV=…` (design.md §6).
/// Por ahora solo existen los emuladores; el proyecto real llega en M4.
const firebaseEnvironment = String.fromEnvironment(
  'FIREBASE_ENV',
  defaultValue: 'emulators',
);

/// Proyecto de demostración: los proyectos `demo-*` solo existen en los emuladores, que aceptan
/// una clave y un id de app ficticios.
const demoProjectId = 'demo-turnos';

const _authEmulatorPort = 9099;
const _firestoreEmulatorPort = 8080;

/// Inicializa Firebase y lo conecta a los emuladores locales.
Future<void> initializeFirebase() async {
  if (firebaseEnvironment != 'emulators') {
    throw UnsupportedError(
      'Entorno de Firebase desconocido: $firebaseEnvironment (solo existe «emulators»).',
    );
  }
  await Firebase.initializeApp(options: _demoOptions());

  final host = emulatorHost(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );
  await FirebaseAuth.instance.useAuthEmulator(host, _authEmulatorPort);
  FirebaseFirestore.instance.useFirestoreEmulator(host, _firestoreEmulatorPort);
}

/// El emulador de Android ve la máquina anfitriona en 10.0.2.2; el resto, en localhost.
String emulatorHost({required bool isWeb, required TargetPlatform platform}) {
  if (!isWeb && platform == TargetPlatform.android) return '10.0.2.2';
  return 'localhost';
}

FirebaseOptions _demoOptions() {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  return FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:0:$platform:0',
    messagingSenderId: '0',
    projectId: demoProjectId,
  );
}
