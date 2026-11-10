import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/core/l10n/l10n.dart';
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

  test('un rechazo de las reglas al cancelar es el plazo de 2 horas', () {
    expect(
      bookingFailureReasonFor(
        'permission-denied',
        action: BookingAction.cancel,
      ),
      BookingFailureReason.tooLateToCancel,
    );
  });

  test(
      'un rechazo al cancelar como administrador es que ya empezó o ya no está activa',
      () {
    expect(
      bookingFailureReasonFor(
        'permission-denied',
        action: BookingAction.adminCancel,
      ),
      BookingFailureReason.notCancellable,
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
    final l10n = lookupAppLocalizations(const Locale('es'));
    for (final reason in BookingFailureReason.values) {
      expect(l10n.bookingFailure(reason), isNotEmpty, reason: reason.name);
      expect(
        l10n.bookingError(BookingFailure(reason)),
        l10n.bookingFailure(reason),
      );
    }
    expect(
      l10n.bookingError(Exception('otro')),
      l10n.bookingFailure(BookingFailureReason.unknown),
    );
    expect(
      l10n.bookingFailure(BookingFailureReason.slotTaken),
      'Ese horario acaba de ocuparse. Elige otro.',
    );
  });
}
