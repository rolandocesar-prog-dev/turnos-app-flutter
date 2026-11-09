/// Ocupación de franjas en `resources/{id}/slots` (design.md §3 y §9).
abstract interface class SlotRepository {
  /// Ids de las franjas ocupadas de [resourceId] en el día [dateKey] (`yyyy-MM-dd`), en tiempo
  /// real.
  Stream<Set<String>> watchTaken(String resourceId, String dateKey);
}
