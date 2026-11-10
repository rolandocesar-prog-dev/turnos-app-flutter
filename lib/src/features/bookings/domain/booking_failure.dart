/// Motivos de una reserva o cancelación fallida (design.md §10). El texto que ve el usuario lo
/// pone la presentación (design.md §14).
enum BookingFailureReason {
  slotTaken,

  /// El servidor rechazó la reserva (franja ya pasada según su hora, recurso desactivado…).
  slotUnavailable,
  limitReached,
  slotPast,
  tooLateToCancel,

  /// El administrador intentó cancelar una reserva que ya empezó o ya estaba cancelada (RF-06).
  notCancellable,
  invalidReason,
  network,
  unknown,
}

/// Error de reserva con un motivo conocido.
class BookingFailure implements Exception {
  const BookingFailure(this.reason);

  final BookingFailureReason reason;

  @override
  String toString() => 'BookingFailure(${reason.name})';
}
