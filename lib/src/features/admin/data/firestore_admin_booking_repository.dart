import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../bookings/data/booking_mapper.dart';
import '../../bookings/data/firestore_booking_repository.dart';
import '../../bookings/domain/booking.dart';
import '../../bookings/domain/booking_failure.dart';
import '../domain/admin_booking_repository.dart';

/// Reservas para el administrador: las reglas le dejan leerlas todas y cancelarlas con motivo
/// (design.md §11).
class FirestoreAdminBookingRepository implements AdminBookingRepository {
  const FirestoreAdminBookingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  /// Rango y orden sobre el mismo campo: alcanza con el índice simple de `startAt`.
  @override
  Stream<List<Booking>> watchDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return _bookings
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('startAt')
        .snapshots()
        .map(
          (snapshot) => bookingsFromFirestore(
            [for (final doc in snapshot.docs) (doc.id, doc.data())],
            onInvalid: (error) =>
                log('Reserva omitida: ${error.message}', name: 'admin'),
          ),
        );
  }

  @override
  Future<String?> clientEmail(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['email'] as String?;
  }

  /// Mismo lote atómico que la cancelación del cliente, con el motivo (design.md §10 y §11).
  @override
  Future<void> cancel(Booking booking, String reason) async {
    try {
      await (_firestore.batch()
            ..update(_bookings.doc(booking.id), {
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelReason': reason,
            })
            ..delete(
              _firestore
                  .collection('resources')
                  .doc(booking.resourceId)
                  .collection('slots')
                  .doc(booking.slotId),
            ))
          .commit();
    } on FirebaseException catch (error) {
      throw BookingFailure(
        bookingFailureReasonFor(error.code, action: BookingAction.adminCancel),
      );
    }
  }
}
