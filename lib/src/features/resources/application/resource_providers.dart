import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore_resource_repository.dart';
import '../domain/resource.dart';
import '../domain/resource_repository.dart';

/// Catálogo en Firestore; las pruebas lo reemplazan con un override.
final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => FirestoreResourceRepository(FirebaseFirestore.instance),
);

/// Recursos activos, en tiempo real (RF-02).
final activeResourcesProvider = StreamProvider<List<Resource>>(
  (ref) => ref.watch(resourceRepositoryProvider).watchActive(),
);

/// Un recurso por id, en tiempo real.
final resourceProvider = StreamProvider.family<Resource?, String>(
  (ref, id) => ref.watch(resourceRepositoryProvider).watch(id),
);
