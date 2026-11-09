import '../../resources/domain/resource.dart';
import '../../resources/domain/slot_calculator.dart';

/// Reservas del usuario (RF-03, RF-04). Los errores llegan como `BookingFailure`.
abstract interface class BookingRepository {
  /// Reserva [slot] de [resource] a nombre de [uid]. Falla con `slotTaken` si la franja ya está
  /// ocupada (design.md §10).
  Future<void> book({
    required String uid,
    required Resource resource,
    required Slot slot,
  });
}
