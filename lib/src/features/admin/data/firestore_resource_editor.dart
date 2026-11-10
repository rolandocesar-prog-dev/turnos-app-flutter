import 'package:cloud_firestore/cloud_firestore.dart';

import '../../resources/data/resource_mapper.dart';
import '../../resources/domain/resource.dart';
import '../domain/resource_editor.dart';

/// Recursos en `resources`; las reglas validan cada campo y exigen rol de administrador
/// (design.md §11).
class FirestoreResourceEditor implements ResourceEditor {
  const FirestoreResourceEditor(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _resources =>
      _firestore.collection('resources');

  @override
  Future<String> create(Resource draft) async {
    final ref = _resources.doc();
    await ref.set(resourceToFirestore(draft));
    return ref.id;
  }

  @override
  Future<void> update(Resource resource) =>
      _resources.doc(resource.id).set(resourceToFirestore(resource));
}
