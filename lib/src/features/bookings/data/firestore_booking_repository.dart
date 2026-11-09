import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../resources/domain/resource.dart';
import '../../resources/domain/slot_calculator.dart';
import '../domain/booking.dart';
import '../domain/booking_failure.dart';
import '../domain/booking_repository.dart';
import 'booking_mapper.dart';

/// Reservas en Firestore: la reserva y su franja se escriben en una transacción (design.md §3 y
/// §10); las reglas de seguridad impiden pisar una franja ocupada (§4).
class FirestoreBookingRepository implements BookingRepository {
  const FirestoreBookingRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection('bookings');

  DocumentReference<Map<String, dynamic>> _slotRef(
    String resourceId,
    String slotId,
  ) =>
      _firestore
          .collection('resources')
          .doc(resourceId)
          .collection('slots')
          .doc(slotId);

  /// Las reglas solo dejan leer las reservas propias: la consulta filtra por `uid` (design.md §4).
  @override
  Stream<List<Booking>> watchMine(String uid) =>
      _bookings.where('uid', isEqualTo: uid).orderBy('startAt').snapshots().map(
            (snapshot) => bookingsFromFirestore(
              [for (final doc in snapshot.docs) (doc.id, doc.data())],
              onInvalid: (error) =>
                  log('Reserva omitida: ${error.message}', name: 'bookings'),
            ),
          );

  /// La reserva pasa a `cancelled` y su franja se borra en un mismo lote atómico; las reglas
  /// exigen ambas cosas y las 2 horas de anticipación (design.md §4).
  @override
  Future<void> cancel(Booking booking) async {
    try {
      await (_firestore.batch()
            ..update(_bookings.doc(booking.id), {
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
            })
            ..delete(_slotRef(booking.resourceId, booking.slotId)))
          .commit();
    } on FirebaseException catch (error) {
      throw BookingFailure(
        bookingFailureReasonFor(error.code, cancelling: true),
      );
    }
  }

  /// Usa el índice compuesto `uid` + `startAt` (firestore.indexes.json); el estado se filtra
  /// aquí, porque las reservas futuras de una persona son pocas.
  @override
  Future<int> countActiveUpcoming(String uid, DateTime now) async {
    try {
      final snapshot = await _bookings
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
    final slotRef = _slotRef(resource.id, slot.id);
    final bookingRef = _bookings.doc();

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

/// Traduce el código de error de Firestore al motivo del dominio (design.md §10). Un rechazo de
/// las reglas significa, al reservar, que la franja ya no está disponible y, al cancelar, que
/// pasó el plazo de 2 horas.
BookingFailureReason bookingFailureReasonFor(
  String code, {
  bool cancelling = false,
}) =>
    switch (code) {
      'permission-denied' => cancelling
          ? BookingFailureReason.tooLateToCancel
          : BookingFailureReason.slotUnavailable,
      'unavailable' => BookingFailureReason.network,
      _ => BookingFailureReason.unknown,
    };
