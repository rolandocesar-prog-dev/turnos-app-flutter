import '../../resources/domain/resource.dart';

/// Escritura de recursos por el administrador (RF-06, design.md §11). Un recurso no se borra: se
/// desactiva guardándolo con `active: false`.
abstract interface class ResourceEditor {
  /// Crea [draft] con un id nuevo, que devuelve; el id de [draft] se ignora.
  Future<String> create(Resource draft);

  /// Reemplaza el recurso [resource] (por su id).
  Future<void> update(Resource resource);
}
