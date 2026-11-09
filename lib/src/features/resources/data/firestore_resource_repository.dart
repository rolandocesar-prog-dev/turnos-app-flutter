import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/resource.dart';
import '../domain/resource_repository.dart';
import 'resource_mapper.dart';

/// Catálogo en `resources`. Las reglas permiten leerlo a cualquier usuario con sesión (design.md §4).
class FirestoreResourceRepository implements ResourceRepository {
  const FirestoreResourceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _resources =>
      _firestore.collection('resources');

  @override
  Stream<List<Resource>> watchActive() =>
      _resources.where('active', isEqualTo: true).snapshots().map(
            (snapshot) => [
              for (final doc in snapshot.docs)
                resourceFromFirestore(doc.id, doc.data()),
            ]..sort((a, b) => a.name.compareTo(b.name)),
          );

  @override
  Stream<Resource?> watch(String id) =>
      _resources.doc(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : resourceFromFirestore(doc.id, data);
      });
}
