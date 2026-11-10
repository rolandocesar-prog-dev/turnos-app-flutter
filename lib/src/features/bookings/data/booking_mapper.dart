import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/booking.dart';

/// Convierte las reservas omitiendo las mal formadas (como el catálogo, design.md §9); cada
/// omitida se informa a [onInvalid]. Quedan ordenadas por inicio.
List<Booking> bookingsFromFirestore(
  Iterable<(String, Map<String, dynamic>)> docs, {
  required void Function(FormatException error) onInvalid,
}) {
  final bookings = <Booking>[];
  for (final (id, data) in docs) {
    try {
      bookings.add(bookingFromFirestore(id, data));
    } on FormatException catch (error) {
      onInvalid(error);
    }
  }
  return bookings..sort((a, b) => a.startAt.compareTo(b.startAt));
}

/// Convierte `bookings/{id}` en una [Booking]; un documento mal formado lanza `FormatException`.
Booking bookingFromFirestore(String id, Map<String, dynamic> data) {
  T field<T>(String name) {
    final value = data[name];
    if (value is! T) {
      throw FormatException('bookings/$id: «$name» falta o no es $T');
    }
    return value;
  }

  final status = switch (data['status']) {
    'active' => BookingStatus.active,
    'cancelled' => BookingStatus.cancelled,
    final other => throw FormatException(
        'bookings/$id: estado desconocido «$other»',
      ),
  };

  return Booking(
    id: id,
    resourceId: field<String>('resourceId'),
    resourceName: field<String>('resourceName'),
    slotId: field<String>('slotId'),
    uid: field<String>('uid'),
    startAt: field<Timestamp>('startAt').toDate(),
    endAt: field<Timestamp>('endAt').toDate(),
    status: status,
    cancelReason: switch (data['cancelReason']) {
      null => null,
      final String reason => reason,
      _ => throw FormatException('bookings/$id: «cancelReason» no es String'),
    },
  );
}
