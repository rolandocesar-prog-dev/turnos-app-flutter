// Límite de reservas contra los emuladores de Functions y Firestore (design.md §12).
// Se corre con `npm run test:functions` en la raíz, que levanta los emuladores.
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { afterAll, beforeEach, describe, expect, test } from 'vitest';

import { LIMIT_CANCEL_REASON } from '../../src/limit.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Estas pruebas necesitan los emuladores: npm run test:functions');
}

const app = initializeApp({ projectId: 'demo-turnos' }, 'pruebas');
const db = getFirestore(app);
afterAll(() => deleteApp(app));

const HOUR = 60 * 60 * 1000;
let run = 0;

beforeEach(() => {
  run += 1;
});

/** Crea una reserva activa futura con su franja, como lo haría la app. */
async function book(uid: string, n: number, createdAt: Date) {
  const id = `r${run}-${uid}-${n}`;
  const slotId = `2030-01-0${n}T10:00`;
  const resourceId = `cancha-${run}`;
  const batch = db.batch();
  batch.set(db.doc(`bookings/${id}`), {
    resourceId,
    resourceName: 'Cancha',
    slotId,
    uid,
    startAt: Timestamp.fromMillis(Date.now() + (24 + n) * HOUR),
    endAt: Timestamp.fromMillis(Date.now() + (25 + n) * HOUR),
    status: 'active',
    createdAt: Timestamp.fromDate(createdAt),
  });
  batch.set(db.doc(`resources/${resourceId}/slots/${slotId}`), { bookingId: id, uid });
  await batch.commit();
  return { id, slotPath: `resources/${resourceId}/slots/${slotId}` };
}

/** Espera a que [check] se cumpla: el disparador corre aparte y tarda un poco. */
async function eventually(check: () => Promise<boolean>, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await check()) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error('La condición no se cumplió a tiempo');
}

const status = async (id: string) => (await db.doc(`bookings/${id}`).get()).get('status');

describe('bookingLimit', () => {
  test('la cuarta reserva activa se cancela y su franja queda libre', async () => {
    const uid = `ana-${run}`;
    const base = Date.now();
    const first = [];
    for (const n of [1, 2, 3]) first.push(await book(uid, n, new Date(base + n)));
    const fourth = await book(uid, 4, new Date(base + 4));

    await eventually(async () => (await status(fourth.id)) === 'cancelled');
    const cancelled = (await db.doc(`bookings/${fourth.id}`).get()).data();
    expect(cancelled?.cancelledBy).toBe('system');
    expect(cancelled?.cancelReason).toBe(LIMIT_CANCEL_REASON);
    expect((await db.doc(fourth.slotPath).get()).exists).toBe(false);

    // Las tres primeras siguen activas, con sus franjas.
    for (const booking of first) {
      expect(await status(booking.id)).toBe('active');
      expect((await db.doc(booking.slotPath).get()).exists).toBe(true);
    }
  });

  test('dos reservas simultáneas sobre el límite: se conserva la más antigua', async () => {
    const uid = `luis-${run}`;
    const base = Date.now();
    await book(uid, 1, new Date(base + 1));
    await book(uid, 2, new Date(base + 2));
    const [older, newer] = await Promise.all([
      book(uid, 3, new Date(base + 3)),
      book(uid, 4, new Date(base + 4)),
    ]);

    await eventually(async () => (await status(newer.id)) === 'cancelled');
    // Le da tiempo al otro disparador: no debe cancelar la más antigua.
    await new Promise((resolve) => setTimeout(resolve, 2000));
    expect(await status(older.id)).toBe('active');
  });

  test('las canceladas y las de otros clientes no cuentan', async () => {
    const uid = `eva-${run}`;
    const base = Date.now();
    const old = await book(uid, 1, new Date(base + 1));
    await db.doc(`bookings/${old.id}`).update({ status: 'cancelled' });
    await book(`otro-${run}`, 2, new Date(base + 2));
    await book(uid, 3, new Date(base + 3));
    await book(uid, 4, new Date(base + 4));
    const third = await book(uid, 5, new Date(base + 5));

    await new Promise((resolve) => setTimeout(resolve, 3000));
    expect(await status(third.id)).toBe('active');
  });
});
