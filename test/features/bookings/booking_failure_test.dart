import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/bookings/data/firestore_booking_repository.dart';
import 'package:turnos_app/src/features/bookings/domain/booking_failure.dart';

void main() {
  test(
      'un rechazo de las reglas al reservar dice que el horario no está disponible',
      () {
    expect(
      bookingFailureReasonFor('permission-denied'),
      BookingFailureReason.slotUnavailable,
    );
  });

  test('sin conexión lo dice; lo demás es un error genérico', () {
    expect(
      bookingFailureReasonFor('unavailable'),
      BookingFailureReason.network,
    );
    expect(bookingFailureReasonFor('internal'), BookingFailureReason.unknown);
  });

  test('cada motivo tiene un mensaje en español', () {
    for (final reason in BookingFailureReason.values) {
      expect(reason.message, isNotEmpty, reason: reason.name);
      expect(BookingFailure(reason).message, reason.message);
    }
  });
}
