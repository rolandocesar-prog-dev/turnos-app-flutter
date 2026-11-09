import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore_resource_repository.dart';
import '../data/firestore_slot_repository.dart';
import '../domain/resource.dart';
import '../domain/resource_repository.dart';
import '../domain/slot_repository.dart';

/// Los flujos de Firestore no se reintentan: el SDK ya maneja la reconexión, y un error que llega
/// (permiso denegado, documento mal formado) no se arregla solo. Con el reintento automático de
/// Riverpod 3, en la app real el catálogo quedaba «cargando» sin mostrar el error (design.md §9).
Duration? noRetry(int retryCount, Object error) => null;

/// Catálogo en Firestore; las pruebas lo reemplazan con un override.
final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => FirestoreResourceRepository(FirebaseFirestore.instance),
);

/// Recursos activos, en tiempo real (RF-02).
final activeResourcesProvider = StreamProvider<List<Resource>>(
  (ref) => ref.watch(resourceRepositoryProvider).watchActive(),
  retry: noRetry,
);

/// Un recurso por id, en tiempo real.
final resourceProvider = StreamProvider.family<Resource?, String>(
  (ref, id) => ref.watch(resourceRepositoryProvider).watch(id),
  retry: noRetry,
);

/// Ocupación de franjas en Firestore; las pruebas lo reemplazan con un override.
final slotRepositoryProvider = Provider<SlotRepository>(
  (ref) => FirestoreSlotRepository(FirebaseFirestore.instance),
);

/// Ids de las franjas ocupadas de un recurso en un día (`yyyy-MM-dd`), en tiempo real.
final takenSlotsProvider =
    StreamProvider.family<Set<String>, ({String resourceId, String dateKey})>(
  (ref, key) =>
      ref.watch(slotRepositoryProvider).watchTaken(key.resourceId, key.dateKey),
  retry: noRetry,
);

/// Hora actual; las pruebas la fijan.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
