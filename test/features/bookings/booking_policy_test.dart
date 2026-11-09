import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/bookings/domain/booking_failure.dart';
import 'package:turnos_app/src/features/bookings/domain/booking_policy.dart';
import 'package:turnos_app/src/features/resources/domain/slot_calculator.dart';

void main() {
  final start = DateTime(2026, 11, 9, 15);
  final slot = Slot(
    id: slotId(start),
    start: start,
    end: start.add(const Duration(hours: 1)),
  );
  final before = DateTime(2026, 11, 9, 14, 59);

  BookingFailureReason? check(DateTime now, int active) =>
      bookingBlocker(slot: slot, now: now, activeUpcoming: active);

  test('una franja futura se reserva con menos de 3 reservas activas', () {
    expect(check(before, 0), isNull);
    expect(check(before, 2), isNull);
  });

  test('con 3 reservas activas, o más, se alcanza el límite', () {
    expect(maxActiveBookings, 3);
    expect(check(before, 3), BookingFailureReason.limitReached);
    expect(check(before, 4), BookingFailureReason.limitReached);
  });

  test('una franja que ya empezó cuenta como pasada, antes que el límite', () {
    expect(check(start, 0), BookingFailureReason.slotPast);
    expect(
      check(start.add(const Duration(minutes: 1)), 3),
      BookingFailureReason.slotPast,
    );
  });
}
