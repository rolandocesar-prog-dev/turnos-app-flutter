import 'resource.dart';

/// Catálogo de recursos (RF-02, design.md §9).
abstract interface class ResourceRepository {
  /// Recursos activos, ordenados por nombre, actualizados en tiempo real.
  Stream<List<Resource>> watchActive();

  /// Todos los recursos, activos e inactivos, ordenados por nombre (administración, RF-06).
  Stream<List<Resource>> watchAll();

  /// Un recurso; `null` si no existe.
  Stream<Resource?> watch(String id);
}
