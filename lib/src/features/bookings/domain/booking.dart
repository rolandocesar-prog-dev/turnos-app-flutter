/// Estado de una reserva (design.md §3).
enum BookingStatus { active, cancelled }

/// Quién canceló una reserva: el cliente, el negocio (con motivo, §11) o el servidor por el
/// límite (§12).
enum CancelledBy { client, business, system }

/// Problemas del motivo que escribe el administrador al cancelar.
enum CancelReasonIssue { tooShort, tooLong }

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

  /// Quién la canceló; `null` si sigue activa.
  CancelledBy? get cancelledBy => switch (status) {
        BookingStatus.active => null,
        BookingStatus.cancelled when cancelledBySystem => CancelledBy.system,
        BookingStatus.cancelled when cancelReason != null =>
          CancelledBy.business,
        BookingStatus.cancelled => CancelledBy.client,
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

/// Problema del motivo, o `null` si es válido.
CancelReasonIssue? cancelReasonIssue(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < cancelReasonMinLength) return CancelReasonIssue.tooShort;
  if (length > cancelReasonMaxLength) return CancelReasonIssue.tooLong;
  return null;
}
