import '../../resources/domain/resource.dart';
import '../../resources/domain/slot_calculator.dart';
import 'booking.dart';

/// Reservas del usuario (RF-03, RF-04). Los errores llegan como `BookingFailure`.
abstract interface class BookingRepository {
  /// Reservas de [uid] (activas y canceladas), por inicio, en tiempo real.
  Stream<List<Booking>> watchMine(String uid);

  /// Cuántas reservas `active` de [uid] empiezan después de [now] (límite de RF-03).
  Future<int> countActiveUpcoming(String uid, DateTime now);

  /// Reserva [slot] de [resource] a nombre de [uid]. Falla con `slotTaken` si la franja ya está
  /// ocupada (design.md §10).
  Future<void> book({
    required String uid,
    required Resource resource,
    required Slot slot,
  });

  /// Cancela [booking] y libera su franja (RF-04).
  Future<void> cancel(Booking booking);
}
