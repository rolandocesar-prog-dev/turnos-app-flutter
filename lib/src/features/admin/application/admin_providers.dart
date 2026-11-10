import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore_resource_editor.dart';
import '../domain/resource_editor.dart';

/// Escritura de recursos en Firestore; las pruebas lo reemplazan con un override.
final resourceEditorProvider = Provider<ResourceEditor>(
  (ref) => FirestoreResourceEditor(FirebaseFirestore.instance),
);
