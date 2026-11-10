import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';

import { LIMIT_CANCEL_REASON, bookingsOverLimit } from './limit.js';

/**
 * Revisa las reservas activas futuras de [uid] y cancela las que superan el límite, liberando su
 * franja (design.md §12). Devuelve los ids cancelados.
 */
export async function enforceBookingLimit(
  db: Firestore,
  uid: string,
  now: Date,
): Promise<string[]> {
  // Mismo índice compuesto (uid, startAt) que usa la app; el estado se filtra aquí.
  const snapshot = await db
    .collection('bookings')
    .where('uid', '==', uid)
    .where('startAt', '>', Timestamp.fromDate(now))
    .get();

  const active = snapshot.docs
    .filter((doc) => doc.get('status') === 'active')
    .map((doc) => ({
      id: doc.id,
      // Sin createdAt (no debería pasar: las reglas lo exigen) cuenta como la más reciente.
      createdAt:
        doc.get('createdAt') instanceof Timestamp
          ? (doc.get('createdAt') as Timestamp).toDate()
          : new Date(8.64e15),
    }));

  const over = bookingsOverLimit(active);
  for (const id of over) {
    await cancelBySystem(db, id);
  }
  return over;
}

/** Cancela la reserva y borra su franja en una transacción, si sigue activa. */
async function cancelBySystem(db: Firestore, bookingId: string): Promise<void> {
  const bookingRef = db.collection('bookings').doc(bookingId);
  await db.runTransaction(async (transaction) => {
    const booking = await transaction.get(bookingRef);
    if (booking.get('status') !== 'active') return;

    const slotRef = db
      .collection('resources')
      .doc(String(booking.get('resourceId')))
      .collection('slots')
      .doc(String(booking.get('slotId')));
    const slot = await transaction.get(slotRef);

    transaction.update(bookingRef, {
      status: 'cancelled',
      cancelledAt: FieldValue.serverTimestamp(),
      cancelledBy: 'system',
      cancelReason: LIMIT_CANCEL_REASON,
    });
    // Solo se libera la franja si es de esta reserva.
    if (slot.get('bookingId') === bookingId) transaction.delete(slotRef);
  });
}
