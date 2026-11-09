import '../../resources/domain/slot_calculator.dart';
import 'booking_failure.dart';

/// Reservas futuras activas que puede tener un cliente a la vez (RF-03).
const maxActiveBookings = 3;

/// Motivo por el que no se puede reservar [slot] a la hora [now] teniendo [activeUpcoming]
/// reservas futuras activas, o `null` si se puede (RF-03, design.md §10). Una franja que ya
/// empezó cuenta como pasada, igual que en la vista de franjas.
BookingFailureReason? bookingBlocker({
  required Slot slot,
  required DateTime now,
  required int activeUpcoming,
}) {
  if (!slot.start.isAfter(now)) return BookingFailureReason.slotPast;
  if (activeUpcoming >= maxActiveBookings) {
    return BookingFailureReason.limitReached;
  }
  return null;
}
