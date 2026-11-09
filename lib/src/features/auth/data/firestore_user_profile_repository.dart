import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';
import '../domain/user_profile_repository.dart';

/// Perfil en `users/{uid}`. Las reglas exigen rol `client` y el correo de la sesión (design.md §4).
class FirestoreUserProfileRepository implements UserProfileRepository {
  const FirestoreUserProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> ensureProfile(AppUser user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    if ((await ref.get()).exists) return;
    await ref.set(newProfileData(user));
  }
}

/// Datos de un perfil nuevo: siempre `client`; el nombre inicial sale del correo.
Map<String, Object?> newProfileData(AppUser user) => {
      'displayName': user.email?.split('@').first ?? '',
      'email': user.email,
      'role': 'client',
      'createdAt': FieldValue.serverTimestamp(),
    };
