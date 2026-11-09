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
