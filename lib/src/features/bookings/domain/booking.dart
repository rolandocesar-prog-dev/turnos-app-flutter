/// Estado de una reserva (design.md §3).
enum BookingStatus { active, cancelled }

/// Una reserva del usuario: `bookings/{id}`.
class Booking {
  const Booking({
    required this.id,
    required this.resourceId,
    required this.resourceName,
    required this.slotId,
    required this.uid,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.cancelReason,
    this.cancelledBySystem = false,
  });

  final String id;
  final String resourceId;

  /// Copiado al reservar, para mostrar «Mis reservas» sin leer cada recurso.
  final String resourceName;
  final String slotId;
  final String uid;
  final DateTime startAt;
  final DateTime endAt;
  final BookingStatus status;

  /// Motivo, cuando la canceló el administrador (RF-06) o el servidor; el cliente cancela sin
  /// motivo.
  final String? cancelReason;

  /// La canceló el servidor por superar el límite de reservas (design.md §12).
  final bool cancelledBySystem;

  /// Texto del estado de una reserva cancelada, para el cliente y el administrador.
  String get cancellationLabel => switch ((cancelledBySystem, cancelReason)) {
        (true, final reason) => 'Cancelada automáticamente: '
            '${reason ?? 'superaste el límite de reservas.'}',
        (false, final String reason) => 'Cancelada por el negocio: $reason',
        (false, null) => 'Cancelada',
      };

  /// Reserva activa que todavía no empezó.
  bool isUpcoming(DateTime now) =>
      status == BookingStatus.active && startAt.isAfter(now);

  @override
  String toString() => 'Booking($id, $slotId, ${status.name})';
}

/// Anticipación mínima para cancelar (RF-04).
const cancelWindow = Duration(hours: 2);

/// Si [booking] se puede cancelar a la hora [now]: activa y con al menos 2 horas de anticipación.
/// Es la misma frontera que las reglas de Firestore (`request.time <= startAt - 2h`).
bool canCancel(Booking booking, DateTime now) =>
    booking.status == BookingStatus.active &&
    !now.isAfter(booking.startAt.subtract(cancelWindow));

/// Si el administrador puede cancelar [booking] a la hora [now]: activa y sin empezar, sin el
/// plazo de 2 horas (RF-06). Es la misma frontera que las reglas (`request.time < startAt`).
bool canAdminCancel(Booking booking, DateTime now) =>
    booking.status == BookingStatus.active && now.isBefore(booking.startAt);

/// Largo del motivo de cancelación del administrador, como en las reglas (design.md §11).
const cancelReasonMinLength = 3;
const cancelReasonMaxLength = 200;

/// Mensaje de error del motivo, o `null` si es válido.
String? cancelReasonError(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < cancelReasonMinLength) {
    return 'Escribe el motivo (al menos $cancelReasonMinLength caracteres).';
  }
  if (length > cancelReasonMaxLength) {
    return 'Usa como máximo $cancelReasonMaxLength caracteres.';
  }
  return null;
}
