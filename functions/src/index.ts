// Cloud Functions de la app de turnos (design.md §12).
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/firestore';
import { setGlobalOptions } from 'firebase-functions/options';

import { enforceBookingLimit } from './enforce-limit.js';

initializeApp();

// Los disparadores de Firestore deben estar en la región de la base (design.md §6).
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 5 });

/** Límite de 3 reservas activas, también en el servidor (RF-03). */
export const bookingLimit = onDocumentCreated('bookings/{bookingId}', async (event) => {
  const uid = event.data?.get('uid');
  if (typeof uid !== 'string') return;

  const cancelled = await enforceBookingLimit(getFirestore(), uid, new Date());
  if (cancelled.length > 0) {
    logger.info('Reservas canceladas por superar el límite', { uid, cancelled });
  }
});
