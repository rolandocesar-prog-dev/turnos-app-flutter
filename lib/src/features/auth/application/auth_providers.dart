import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/no_retry.dart';
import '../../../core/firebase/firebase_setup.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firestore_user_profile_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_profile_repository.dart';

/// Implementación de autenticación; las pruebas la reemplazan con un override.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

/// Perfiles en Firestore; las pruebas lo reemplazan con un override.
final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(FirebaseFirestore.instance),
);

/// Google solo está disponible en web (design.md §8): con los emuladores siempre, y en el
/// proyecto real cuando se compila con `--dart-define=GOOGLE_SIGN_IN=true`, después de activar
/// Google en la consola (design.md §6). Las pruebas lo reemplazan con un override.
final googleSignInAvailableProvider = Provider<bool>(
  (ref) => googleSignInAvailableFor(
    isWeb: kIsWeb,
    environment: parseFirebaseEnvironment(firebaseEnvironment),
    enabledInProduction: const bool.fromEnvironment('GOOGLE_SIGN_IN'),
  ),
);

bool googleSignInAvailableFor({
  required bool isWeb,
  required FirebaseEnvironment environment,
  required bool enabledInProduction,
}) =>
    isWeb &&
    (environment == FirebaseEnvironment.emulators || enabledInProduction);

/// Sesión actual: cargando, sin usuario (`null`) o con usuario.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Rol del usuario con sesión, en tiempo real (design.md §11); sin sesión, `client`. Como los
/// demás flujos de Firestore, no se reintenta (design.md §9).
final currentRoleProvider = StreamProvider<UserRole>(
  (ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return Stream.value(UserRole.client);
    return ref.watch(userProfileRepositoryProvider).watchRole(user.uid);
  },
  retry: noRetry,
);
