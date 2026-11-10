// Cloud Functions de la app de turnos (design.md §12 y §13).
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/firestore';
import { setGlobalOptions } from 'firebase-functions/options';
import { defineString } from 'firebase-functions/params';
import { onSchedule } from 'firebase-functions/scheduler';

import { notifyBusinessCancellation } from './cancellation.js';
import { enforceBookingLimit } from './enforce-limit.js';
import { DEFAULT_TIME_ZONE } from './notices.js';
import { FcmSender, OutboxSender, type PushSender } from './push.js';
import { sendReminders } from './reminders.js';

initializeApp();

// Los disparadores de Firestore deben estar en la región de la base (design.md §6).
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 5 });

/** Zona del negocio para escribir las horas de los avisos (el servidor corre en UTC). */
const businessTimeZone = defineString('BUSINESS_TIME_ZONE', { default: DEFAULT_TIME_ZONE });

/** En el emulador no hay FCM: los avisos van a `devOutbox` (design.md §13 «Envío»). */
function sender(): PushSender {
  return process.env.FUNCTIONS_EMULATOR === 'true'
    ? new OutboxSender(getFirestore())
    : new FcmSender(getMessaging());
}

/** Límite de 3 reservas activas, también en el servidor (RF-03). */
export const bookingLimit = onDocumentCreated('bookings/{bookingId}', async (event) => {
  const uid = event.data?.get('uid');
  if (typeof uid !== 'string') return;

  const cancelled = await enforceBookingLimit(getFirestore(), uid, new Date());
  if (cancelled.length > 0) {
    logger.info('Reservas canceladas por superar el límite', { uid, cancelled });
  }
});

/** Recordatorio 1 hora antes del turno (RF-05). */
export const reminders = onSchedule(
  { schedule: 'every 5 minutes', timeZone: DEFAULT_TIME_ZONE },
  async () => {
    const reminded = await sendReminders(
      getFirestore(),
      sender(),
      new Date(),
      businessTimeZone.value(),
    );
    if (reminded.length > 0) logger.info('Recordatorios enviados', { reminded });
  },
);

/** Aviso al cliente cuando el negocio cancela su reserva (RF-05). */
export const bookingCancelledNotice = onDocumentUpdated('bookings/{bookingId}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  const sent = await notifyBusinessCancellation(
    getFirestore(),
    sender(),
    before,
    after,
    new Date(),
    businessTimeZone.value(),
  );
  if (sent > 0) logger.info('Aviso de cancelación enviado', { booking: event.params.bookingId });
});
