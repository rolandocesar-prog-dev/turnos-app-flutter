import '../../bookings/domain/booking.dart';

/// Reservas de todos los clientes, para el administrador (RF-06, design.md §11). Los errores
/// llegan como `BookingFailure`.
abstract interface class AdminBookingRepository {
  /// Reservas (activas y canceladas) que empiezan el día [day], por inicio, en tiempo real.
  Stream<List<Booking>> watchDay(DateTime day);

  /// Correo del cliente [uid], o `null` si no tiene perfil.
  Future<String?> clientEmail(String uid);

  /// Cancela [booking] con [reason] y libera su franja.
  Future<void> cancel(Booking booking, String reason);
}
