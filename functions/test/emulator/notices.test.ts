// Recordatorios y avisos de cancelación contra los emuladores (design.md §13 «Envío»).
// Se corre con `npm run test:functions` en la raíz, que levanta los emuladores.
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { afterAll, describe, expect, test } from 'vitest';

import { OutboxSender, STALE_FID_PREFIX } from '../../src/push.js';
import { sendReminders } from '../../src/reminders.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Estas pruebas necesitan los emuladores: npm run test:functions');
}

const app = initializeApp({ projectId: 'demo-turnos' }, 'pruebas-avisos');
const db = getFirestore(app);
afterAll(() => deleteApp(app));

const MINUTE = 60 * 1000;
const LA_PAZ = 'America/La_Paz';
let seq = 0;
const unique = (name: string) => `${name}-${Date.now()}-${++seq}`;

async function user(fids: string[]) {
  const uid = unique('cliente');
  await db.doc(`users/${uid}`).set({ email: `${uid}@ejemplo.com`, role: 'client', fcmTokens: fids });
  return uid;
}

async function booking(uid: string, startAt: Date, extra: Record<string, unknown> = {}) {
  const id = unique('reserva');
  await db.doc(`bookings/${id}`).set({
    resourceId: 'cancha',
    resourceName: 'Cancha de fútbol 5',
    slotId: `slot-${id}`,
    uid,
    startAt: Timestamp.fromDate(startAt),
    endAt: Timestamp.fromDate(new Date(startAt.getTime() + 60 * MINUTE)),
    status: 'active',
    createdAt: Timestamp.now(),
    ...extra,
  });
  return id;
}

async function outboxFor(fid: string) {
  const snapshot = await db.collection('devOutbox').where('fids', 'array-contains', fid).get();
  return snapshot.docs.map((doc) => doc.data());
}

async function eventually(check: () => Promise<boolean>, timeoutMs = 15000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (await check()) return;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error('La condición no se cumplió a tiempo');
}

describe('sendReminders', () => {
  test('recuerda solo los turnos activos de la hora siguiente, una sola vez', async () => {
    const fid = unique('fid');
    const stale = `${STALE_FID_PREFIX}${unique('fid')}`;
    const uid = await user([fid, stale]);
    const now = new Date();
    const soon = await booking(uid, new Date(now.getTime() + 30 * MINUTE));
    await booking(uid, new Date(now.getTime() + 120 * MINUTE));
    await booking(uid, new Date(now.getTime() + 40 * MINUTE), { status: 'cancelled' });
    await booking(uid, new Date(now.getTime() + 50 * MINUTE), {
      reminderSentAt: Timestamp.now(),
    });

    const sender = new OutboxSender(db);
    const reminded = await sendReminders(db, sender, now, LA_PAZ);

    expect(reminded).toContain(soon);
    const mine = (await outboxFor(fid)).filter((n) => n.title === 'Tu turno es en 1 hora');
    expect(mine).toHaveLength(1);
    expect(mine[0]?.body).toMatch(/^Cancha de fútbol 5, (hoy|mañana) a las \d\d:\d\d\.$/);
    expect((await db.doc(`bookings/${soon}`).get()).get('reminderSentAt')).toBeInstanceOf(
      Timestamp,
    );
    // El id vencido se quita del perfil.
    expect((await db.doc(`users/${uid}`).get()).get('fcmTokens')).toEqual([fid]);

    // Una segunda ejecución no lo repite.
    expect(await sendReminders(db, sender, new Date(), LA_PAZ)).not.toContain(soon);
    expect((await outboxFor(fid)).filter((n) => n.title === 'Tu turno es en 1 hora')).toHaveLength(
      1,
    );
  });

  test('dos ejecuciones simultáneas envían un solo recordatorio', async () => {
    const fid = unique('fid');
    const uid = await user([fid]);
    const now = new Date();
    const id = await booking(uid, new Date(now.getTime() + 20 * MINUTE));

    const sender = new OutboxSender(db);
    const [first, second] = await Promise.all([
      sendReminders(db, sender, now, LA_PAZ),
      sendReminders(db, sender, now, LA_PAZ),
    ]);

    expect([...first, ...second].filter((b) => b === id)).toHaveLength(1);
    expect(await outboxFor(fid)).toHaveLength(1);
  });

  test('sin dispositivos registrados no envía nada, pero marca el recordatorio', async () => {
    const uid = await user([]);
    const id = await booking(uid, new Date(Date.now() + 10 * MINUTE));

    await sendReminders(db, new OutboxSender(db), new Date(), LA_PAZ);

    expect((await db.doc(`bookings/${id}`).get()).get('reminderSentAt')).toBeInstanceOf(Timestamp);
  });
});

describe('bookingCancelledNotice (disparador)', () => {
  test('avisa cuando el negocio cancela, con el motivo', async () => {
    const fid = unique('fid');
    const uid = await user([fid]);
    const id = await booking(uid, new Date(Date.now() + 26 * 60 * MINUTE));

    await db.doc(`bookings/${id}`).update({
      status: 'cancelled',
      cancelledAt: Timestamp.now(),
      cancelReason: 'Corte de luz',
    });

    await eventually(async () => (await outboxFor(fid)).length > 0);
    const [notice] = await outboxFor(fid);
    expect(notice?.title).toBe('Tu reserva fue cancelada');
    expect(notice?.body).toMatch(/^Cancha de fútbol 5, .+ a las \d\d:\d\d\. Motivo: Corte de luz$/);
  });

  test('no avisa cuando cancela el cliente', async () => {
    const fid = unique('fid');
    const uid = await user([fid]);
    const id = await booking(uid, new Date(Date.now() + 26 * 60 * MINUTE));

    await db.doc(`bookings/${id}`).update({ status: 'cancelled', cancelledAt: Timestamp.now() });

    await new Promise((resolve) => setTimeout(resolve, 3000));
    expect(await outboxFor(fid)).toHaveLength(0);
  });
});
