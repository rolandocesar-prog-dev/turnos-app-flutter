import 'package:cloud_firestore/cloud_firestore.dart';

import '../../resources/domain/resource.dart';
import '../../resources/domain/slot_calculator.dart';
import '../domain/booking_failure.dart';
import '../domain/booking_repository.dart';

/// Reservas en Firestore: la reserva y su franja se escriben en una transacción (design.md §3 y
/// §10); las reglas de seguridad impiden pisar una franja ocupada (§4).
class FirestoreBookingRepository implements BookingRepository {
  const FirestoreBookingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// Usa el índice compuesto `uid` + `startAt` (firestore.indexes.json); el estado se filtra
  /// aquí, porque las reservas futuras de una persona son pocas.
  @override
  Future<int> countActiveUpcoming(String uid, DateTime now) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('uid', isEqualTo: uid)
          .where('startAt', isGreaterThan: Timestamp.fromDate(now))
          .get();
      return snapshot.docs
          .where((doc) => doc.data()['status'] == 'active')
          .length;
    } on FirebaseException catch (error) {
      throw BookingFailure(bookingFailureReasonFor(error.code));
    }
  }

  @override
  Future<void> book({
    required String uid,
    required Resource resource,
    required Slot slot,
  }) async {
    final slotRef = _firestore
        .collection('resources')
        .doc(resource.id)
        .collection('slots')
        .doc(slot.id);
    final bookingRef = _firestore.collection('bookings').doc();

    final bool booked;
    try {
      // La transacción devuelve si reservó en vez de lanzar el error desde adentro: así el aviso
      // llega igual en todas las plataformas.
      booked = await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(slotRef);
        if (existing.exists) return false;
        transaction
          ..set(bookingRef, {
            'resourceId': resource.id,
            'resourceName': resource.name,
            'slotId': slot.id,
            'uid': uid,
            'startAt': Timestamp.fromDate(slot.start),
            'endAt': Timestamp.fromDate(slot.end),
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(slotRef, {
            'bookingId': bookingRef.id,
            'uid': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        return true;
      });
    } on FirebaseException catch (error) {
      throw BookingFailure(bookingFailureReasonFor(error.code));
    }
    if (!booked) throw const BookingFailure(BookingFailureReason.slotTaken);
  }
}

/// Traduce el código de error de Firestore al motivo del dominio al reservar (design.md §10).
BookingFailureReason bookingFailureReasonFor(String code) => switch (code) {
      'permission-denied' => BookingFailureReason.slotUnavailable,
      'unavailable' => BookingFailureReason.network,
      _ => BookingFailureReason.unknown,
    };
