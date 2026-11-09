/// Motivos de una reserva o cancelación fallida, con el mensaje que ve el usuario
/// (design.md §10).
enum BookingFailureReason {
  slotTaken('Ese horario acaba de ocuparse. Elige otro.'),

  /// El servidor rechazó la reserva (franja ya pasada según su hora, recurso desactivado…).
  slotUnavailable('Ese horario ya no está disponible. Elige otro.'),
  limitReached('Ya tienes 3 reservas activas. Cancela una para reservar otra.'),
  slotPast('Ese horario ya pasó. Elige otro.'),
  tooLateToCancel('Solo se puede cancelar hasta 2 horas antes.'),
  network('No hay conexión. Revisa tu internet y vuelve a probar.'),
  unknown('No se pudo completar. Vuelve a intentarlo.');

  const BookingFailureReason(this.message);

  final String message;
}

/// Error de reserva con un motivo conocido.
class BookingFailure implements Exception {
  const BookingFailure(this.reason);

  final BookingFailureReason reason;

  String get message => reason.message;

  @override
  String toString() => 'BookingFailure(${reason.name})';
}
