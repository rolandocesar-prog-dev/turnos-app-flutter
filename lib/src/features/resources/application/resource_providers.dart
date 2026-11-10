import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/no_retry.dart';
import '../data/firestore_resource_repository.dart';
import '../data/firestore_slot_repository.dart';
import '../domain/resource.dart';
import '../domain/resource_repository.dart';
import '../domain/slot_repository.dart';

/// Catálogo en Firestore; las pruebas lo reemplazan con un override.
final resourceRepositoryProvider = Provider<ResourceRepository>(
  (ref) => FirestoreResourceRepository(FirebaseFirestore.instance),
);

/// Recursos activos, en tiempo real (RF-02).
final activeResourcesProvider = StreamProvider<List<Resource>>(
  (ref) => ref.watch(resourceRepositoryProvider).watchActive(),
  retry: noRetry,
);

/// Todos los recursos, también los inactivos, para el panel de administración (RF-06).
final allResourcesProvider = StreamProvider<List<Resource>>(
  (ref) => ref.watch(resourceRepositoryProvider).watchAll(),
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
