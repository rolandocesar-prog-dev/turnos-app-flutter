import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';

/// Entorno de Firebase elegido con `--dart-define=FIREBASE_ENV=…` (design.md §6).
const firebaseEnvironment = String.fromEnvironment(
  'FIREBASE_ENV',
  defaultValue: 'emulators',
);

/// Dónde se conecta la app: los emuladores locales o el proyecto real.
enum FirebaseEnvironment { emulators, production }

/// Lee el valor de `FIREBASE_ENV`; uno desconocido falla al arrancar, en vez de conectarse a un
/// lugar inesperado.
FirebaseEnvironment parseFirebaseEnvironment(String value) => switch (value) {
      'emulators' => FirebaseEnvironment.emulators,
      'production' => FirebaseEnvironment.production,
      _ => throw UnsupportedError(
          'Entorno de Firebase desconocido: «$value» (usa «emulators» o «production»).',
        ),
    };

/// Proyecto de demostración: los proyectos `demo-*` solo existen en los emuladores, que aceptan
/// una clave y un id de app ficticios.
const demoProjectId = 'demo-turnos';

const _authEmulatorPort = 9099;
const _firestoreEmulatorPort = 8080;

/// Inicializa Firebase en el entorno de [firebaseEnvironment]: el proyecto real o los emuladores
/// locales.
Future<void> initializeFirebase() async {
  switch (parseFirebaseEnvironment(firebaseEnvironment)) {
    case FirebaseEnvironment.production:
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    case FirebaseEnvironment.emulators:
      await _initializeEmulators();
  }
}

Future<void> _initializeEmulators() async {
  await Firebase.initializeApp(options: demoFirebaseOptions());

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

/// Opciones del proyecto de demostración, que los emuladores aceptan.
FirebaseOptions demoFirebaseOptions() {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  return FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:0:$platform:0',
    messagingSenderId: '0',
    projectId: demoProjectId,
    // En web, el inicio de sesión con ventana emergente (Google) lo exige; con los emuladores no
    // se contacta este dominio.
    authDomain: '$demoProjectId.firebaseapp.com',
  );
}
