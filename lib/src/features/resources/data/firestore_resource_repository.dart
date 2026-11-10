import 'dart:developer';

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
      _watchQuery(_resources.where('active', isEqualTo: true));

  @override
  Stream<List<Resource>> watchAll() => _watchQuery(_resources);

  Stream<List<Resource>> _watchQuery(Query<Map<String, dynamic>> query) =>
      query.snapshots().map(
            (snapshot) => resourcesFromFirestore(
              [for (final doc in snapshot.docs) (doc.id, doc.data())],
              // Un recurso mal cargado se omite de la lista y queda registrado.
              onInvalid: (error) =>
                  log('Recurso omitido: ${error.message}', name: 'resources'),
            ),
          );

  /// En el detalle, un documento mal formado sí es un error: la pantalla lo informa.
  @override
  Stream<Resource?> watch(String id) =>
      _resources.doc(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : resourceFromFirestore(doc.id, data);
      });
}
