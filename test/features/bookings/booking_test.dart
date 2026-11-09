import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/bookings/data/booking_mapper.dart';
import 'package:turnos_app/src/features/bookings/domain/booking.dart';

import '../../support/fakes.dart';

void main() {
  group('canCancel (RF-04)', () {
    final booking = testBooking('b', DateTime(2026, 11, 9, 15));

    test('hasta exactamente 2 horas antes, como las reglas', () {
      expect(canCancel(booking, DateTime(2026, 11, 9, 10)), isTrue);
      expect(canCancel(booking, DateTime(2026, 11, 9, 13)), isTrue);
      expect(canCancel(booking, DateTime(2026, 11, 9, 13, 0, 1)), isFalse);
      expect(canCancel(booking, DateTime(2026, 11, 9, 16)), isFalse);
    });

    test('una cancelada no se vuelve a cancelar', () {
      final cancelled = testBooking(
        'c',
        DateTime(2026, 11, 20, 9),
        status: BookingStatus.cancelled,
      );
      expect(canCancel(cancelled, DateTime(2026, 11, 9, 10)), isFalse);
    });

    test('próxima = activa y sin empezar', () {
      final now = DateTime(2026, 11, 9, 15);
      expect(booking.isUpcoming(now), isFalse);
      expect(booking.isUpcoming(DateTime(2026, 11, 9, 14, 59)), isTrue);
    });
  });

  group('bookingFromFirestore', () {
    Map<String, dynamic> data({Object? status = 'active'}) => {
          'resourceId': 'cancha',
          'resourceName': 'Cancha',
          'slotId': '2026-11-10T18:00',
          'uid': 'u1',
          'startAt': Timestamp.fromDate(DateTime(2026, 11, 10, 18)),
          'endAt': Timestamp.fromDate(DateTime(2026, 11, 10, 19)),
          'status': status,
          'createdAt': Timestamp.now(),
        };

    test('convierte una reserva válida', () {
      final booking = bookingFromFirestore('b1', data());
      expect(booking.id, 'b1');
      expect(booking.resourceName, 'Cancha');
      expect(booking.startAt, DateTime(2026, 11, 10, 18));
      expect(booking.status, BookingStatus.active);
      expect(
        bookingFromFirestore('b2', data(status: 'cancelled')).status,
        BookingStatus.cancelled,
      );
    });

    test('omite las mal formadas y ordena el resto por inicio', () {
      final errors = <FormatException>[];
      final later = data()
        ..['startAt'] = Timestamp.fromDate(DateTime(2026, 11, 11, 9));
      final result = bookingsFromFirestore(
        [
          ('tarde', later),
          ('rota', data(status: 'borrada')),
          ('sin-hora', data()..remove('startAt')),
          ('temprano', data()),
        ],
        onInvalid: errors.add,
      );

      expect([for (final b in result) b.id], ['temprano', 'tarde']);
      expect(errors, hasLength(2));
      expect(errors.first.message, contains('borrada'));
    });
  });
}
