import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';

import { needsReminder, reminderNotice, reminderWindow, type BookingState } from './notices.js';
import { notifyUser, type PushSender } from './push.js';

/**
 * Envía el recordatorio de los turnos de la hora siguiente que todavía no lo tienen (design.md
 * §13 «Envío»). Devuelve los ids de las reservas recordadas.
 */
export async function sendReminders(
  db: Firestore,
  sender: PushSender,
  now: Date,
  timeZone: string,
): Promise<string[]> {
  const { from, to } = reminderWindow(now);
  // Rango sobre un solo campo: alcanza el índice simple de startAt; el estado se filtra aquí.
  const snapshot = await db
    .collection('bookings')
    .where('startAt', '>', Timestamp.fromDate(from))
    .where('startAt', '<=', Timestamp.fromDate(to))
    .get();

  const reminded: string[] = [];
  for (const doc of snapshot.docs) {
    if (!needsReminder(stateOf(doc.data()), now)) continue;
    if (!(await claim(db, doc.id, now))) continue;

    const uid: unknown = doc.get('uid');
    const resourceName: unknown = doc.get('resourceName');
    if (typeof uid !== 'string' || typeof resourceName !== 'string') continue;
    const startAt = (doc.get('startAt') as Timestamp).toDate();
    await notifyUser(db, sender, uid, reminderNotice({ resourceName, startAt }, now, timeZone));
    reminded.push(doc.id);
  }
  return reminded;
}

/**
 * Marca `reminderSentAt` antes de enviar, en una transacción: si dos ejecuciones se cruzan, solo
 * una envía; si el envío falla, el cliente se queda sin aviso, pero nunca recibe dos.
 */
async function claim(db: Firestore, bookingId: string, now: Date): Promise<boolean> {
  const ref = db.collection('bookings').doc(bookingId);
  return db.runTransaction(async (transaction) => {
    const fresh = await transaction.get(ref);
    if (!needsReminder(stateOf(fresh.data() ?? {}), now)) return false;
    transaction.update(ref, { reminderSentAt: FieldValue.serverTimestamp() });
    return true;
  });
}

/** Lo que hace falta de un documento de reserva para las decisiones puras. */
export function stateOf(data: Record<string, unknown>): BookingState {
  const startAt = data.startAt;
  return {
    status: data.status,
    reminderSentAt: data.reminderSentAt,
    cancelReason: data.cancelReason,
    cancelledBy: data.cancelledBy,
    ...(startAt instanceof Timestamp ? { startAt: startAt.toDate() } : {}),
  };
}
