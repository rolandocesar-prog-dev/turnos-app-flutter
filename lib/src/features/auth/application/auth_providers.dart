import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Sesión actual: cargando, sin usuario (`null`) o con usuario.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);
