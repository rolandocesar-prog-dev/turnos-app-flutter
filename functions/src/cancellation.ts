import { Timestamp, type Firestore } from 'firebase-admin/firestore';

import { cancellationNotice, isBusinessCancellation } from './notices.js';
import { notifyUser, type PushSender } from './push.js';
import { stateOf } from './reminders.js';

/**
 * Avisa al cliente cuando el negocio cancela su reserva (RF-05, design.md §13 «Envío»). Devuelve
 * a cuántos dispositivos se envió; 0 si el cambio no es una cancelación del negocio.
 */
export async function notifyBusinessCancellation(
  db: Firestore,
  sender: PushSender,
  before: Record<string, unknown>,
  after: Record<string, unknown>,
  now: Date,
  timeZone: string,
): Promise<number> {
  if (!isBusinessCancellation(stateOf(before), stateOf(after))) return 0;
  const { uid, resourceName, startAt, cancelReason } = after;
  if (
    typeof uid !== 'string' ||
    typeof resourceName !== 'string' ||
    typeof cancelReason !== 'string' ||
    !(startAt instanceof Timestamp)
  ) {
    return 0;
  }
  return notifyUser(
    db,
    sender,
    uid,
    cancellationNotice({ resourceName, startAt: startAt.toDate() }, cancelReason, now, timeZone),
  );
}
