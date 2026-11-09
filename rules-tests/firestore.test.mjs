// Pruebas de las reglas de Firestore (RNF-01, design.md §4). Se ejecutan con el emulador:
// npm run test:rules
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const ANA = { uid: 'ana', email: 'ana@ejemplo.com' };
const LUIS = { uid: 'luis', email: 'luis@ejemplo.com' };
const ADMIN = { uid: 'admin', email: 'admin@ejemplo.com' };

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-turnos',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Datos previos, escritos sin reglas: el admin y un recurso.
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users', ADMIN.uid), { email: ADMIN.email, role: 'admin' });
    await setDoc(doc(db, 'resources', 'cancha-1'), { name: 'Cancha 1', active: true });
  });
});

const as = (user) => env.authenticatedContext(user.uid, { email: user.email }).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();
const profile = (user, extra = {}) => ({
  displayName: 'Ana',
  email: user.email,
  role: 'client',
  createdAt: serverTimestamp(),
  ...extra,
});

describe('users/{uid}', () => {
  test('cada uno crea su propio perfil como cliente', async () => {
    await assertSucceeds(setDoc(doc(as(ANA), 'users', ANA.uid), profile(ANA)));
  });

  test('nadie se crea como admin', async () => {
    await assertFails(setDoc(doc(as(ANA), 'users', ANA.uid), profile(ANA, { role: 'admin' })));
  });

  test('el correo del perfil debe ser el de la sesión', async () => {
    const ajeno = profile(ANA, { email: LUIS.email });
    await assertFails(setDoc(doc(as(ANA), 'users', ANA.uid), ajeno));
  });

  test('no se aceptan campos fuera del modelo', async () => {
    const extra = profile(ANA, { saldo: 1000 });
    await assertFails(setDoc(doc(as(ANA), 'users', ANA.uid), extra));
  });

  test('nadie crea ni lee el perfil de otro', async () => {
    await assertFails(setDoc(doc(as(LUIS), 'users', ANA.uid), profile(ANA)));
    await assertSucceeds(setDoc(doc(as(ANA), 'users', ANA.uid), profile(ANA)));
    await assertFails(getDoc(doc(as(LUIS), 'users', ANA.uid)));
    await assertSucceeds(getDoc(doc(as(ANA), 'users', ANA.uid)));
  });

  test('sin sesión no se lee ni se escribe', async () => {
    await assertFails(getDoc(doc(anonymous(), 'users', ANA.uid)));
    await assertFails(setDoc(doc(anonymous(), 'users', ANA.uid), profile(ANA)));
  });

  test('se puede cambiar el nombre, pero no el rol ni el correo', async () => {
    const ref = doc(as(ANA), 'users', ANA.uid);
    await assertSucceeds(setDoc(ref, profile(ANA)));
    await assertSucceeds(updateDoc(ref, { displayName: 'Ana P.' }));
    await assertFails(updateDoc(ref, { role: 'admin' }));
    await assertFails(updateDoc(ref, { email: 'otro@ejemplo.com' }));
  });

  test('el perfil no se borra desde la app', async () => {
    const ref = doc(as(ANA), 'users', ANA.uid);
    await assertSucceeds(setDoc(ref, profile(ANA)));
    await assertFails(deleteDoc(ref));
  });
});

describe('resources/{id}', () => {
  test('cualquier usuario con sesión lee el catálogo', async () => {
    const snapshot = await assertSucceeds(getDoc(doc(as(ANA), 'resources', 'cancha-1')));
    assert.equal(snapshot.data().name, 'Cancha 1');
  });

  test('sin sesión no se lee el catálogo', async () => {
    await assertFails(getDoc(doc(anonymous(), 'resources', 'cancha-1')));
  });

  test('solo un admin crea o edita recursos', async () => {
    await assertFails(setDoc(doc(as(ANA), 'resources', 'nuevo'), { name: 'X', active: true }));
    await assertFails(updateDoc(doc(as(ANA), 'resources', 'cancha-1'), { active: false }));
    await assertSucceeds(setDoc(doc(as(ADMIN), 'resources', 'nuevo'), { name: 'X', active: true }));
    await assertSucceeds(updateDoc(doc(as(ADMIN), 'resources', 'cancha-1'), { active: false }));
  });
});

describe('resources/{id}/slots/{slotId}', () => {
  const slot = (db) => doc(db, 'resources', 'cancha-1', 'slots', '2026-11-10T18:00');

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(slot(context.firestore()), { bookingId: 'b1', uid: LUIS.uid });
    });
  });

  test('cualquier usuario con sesión ve qué franjas están ocupadas', async () => {
    await assertSucceeds(getDoc(slot(as(ANA))));
  });

  test('sin sesión no se ven', async () => {
    await assertFails(getDoc(slot(anonymous())));
  });

  test('una franja suelta, sin su reserva, no se crea ni se borra', async () => {
    const libre = doc(as(ANA), 'resources', 'cancha-1', 'slots', '2026-11-10T19:00');
    await assertFails(setDoc(libre, { bookingId: 'b2', uid: ANA.uid, createdAt: serverTimestamp() }));
    await assertFails(deleteDoc(slot(as(LUIS))));
    await assertFails(deleteDoc(slot(as(ADMIN))));
  });
});

// Reservar y cancelar (RF-03, RF-04, design.md §10): la reserva y su franja van en un mismo lote.
describe('bookings/{id} con su franja', () => {
  const HOUR = 60 * 60 * 1000;
  const SLOT_ID = '2026-12-01T10:00';
  const bookingRef = (db, id = 'bk1') => doc(db, 'bookings', id);
  const slotRef = (db, slotId = SLOT_ID, resourceId = 'cancha-1') =>
    doc(db, 'resources', resourceId, 'slots', slotId);

  const reservar = (user, opciones = {}) => {
    const {
      bookingId = 'bk1',
      slotId = SLOT_ID,
      resourceId = 'cancha-1',
      startAt = new Date(Date.now() + 24 * HOUR),
      booking = {},
      slot = {},
      soloReserva = false,
      soloFranja = false,
    } = opciones;
    const db = as(user);
    const batch = writeBatch(db);
    if (!soloFranja) {
      batch.set(bookingRef(db, bookingId), {
        resourceId,
        resourceName: 'Cancha 1',
        slotId,
        uid: user.uid,
        startAt: Timestamp.fromDate(startAt),
        endAt: Timestamp.fromDate(new Date(startAt.getTime() + HOUR)),
        status: 'active',
        createdAt: serverTimestamp(),
        ...booking,
      });
    }
    if (!soloReserva) {
      batch.set(slotRef(db, slotId, resourceId), {
        bookingId,
        uid: user.uid,
        createdAt: serverTimestamp(),
        ...slot,
      });
    }
    return batch.commit();
  };

  const cancelar = (user, { bookingId = 'bk1', liberar = true, cambios = {} } = {}) => {
    const db = as(user);
    const batch = writeBatch(db);
    batch.update(bookingRef(db, bookingId), {
      status: 'cancelled',
      cancelledAt: serverTimestamp(),
      ...cambios,
    });
    if (liberar) batch.delete(slotRef(db));
    return batch.commit();
  };

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'resources', 'sala'), { name: 'Sala', active: false });
      await setDoc(slotRef(db, '2026-12-01T11:00'), { bookingId: 'otra', uid: LUIS.uid });
    });
  });

  test('se reserva una franja futura y libre', async () => {
    await assertSucceeds(reservar(ANA));
    const franja = await getDoc(slotRef(as(LUIS)));
    assert.equal(franja.data().bookingId, 'bk1');
  });

  test('la reserva o la franja por separado no se aceptan', async () => {
    await assertFails(reservar(ANA, { soloReserva: true }));
    await assertFails(reservar(ANA, { soloFranja: true }));
  });

  test('una franja ocupada no se vuelve a reservar', async () => {
    await assertFails(reservar(ANA, { slotId: '2026-12-01T11:00' }));
    await assertSucceeds(reservar(ANA));
    await assertFails(reservar(LUIS, { bookingId: 'bk2' }));
  });

  test('no se reserva en el pasado ni en un recurso inactivo', async () => {
    await assertFails(reservar(ANA, { startAt: new Date(Date.now() - HOUR) }));
    await assertFails(reservar(ANA, { resourceId: 'sala' }));
    await assertFails(reservar(ANA, { resourceId: 'no-existe' }));
  });

  test('la reserva es de quien tiene la sesión', async () => {
    await assertFails(reservar(ANA, { booking: { uid: LUIS.uid } }));
    await assertFails(reservar(ANA, { slot: { uid: LUIS.uid } }));
    await assertFails(reservar(ANA, { booking: { status: 'cancelled' } }));
  });

  test('la franja y la reserva deben apuntarse entre sí', async () => {
    await assertFails(reservar(ANA, { booking: { slotId: '2026-12-01T12:00' } }));
    await assertFails(reservar(ANA, { slot: { bookingId: 'otra' } }));
  });

  test('no se aceptan campos fuera del modelo', async () => {
    await assertFails(reservar(ANA, { booking: { precio: 0 } }));
    await assertFails(reservar(ANA, { slot: { nota: 'x' } }));
  });

  test('cada cliente lee solo sus reservas', async () => {
    await assertSucceeds(reservar(ANA));
    await assertSucceeds(getDoc(bookingRef(as(ANA))));
    await assertFails(getDoc(bookingRef(as(LUIS))));
    await assertFails(getDoc(bookingRef(anonymous())));
    const bookings = collection(as(ANA), 'bookings');
    await assertSucceeds(getDocs(query(bookings, where('uid', '==', ANA.uid))));
    await assertFails(getDocs(bookings));
  });

  test('se cancela con más de 2 horas de anticipación y la franja queda libre', async () => {
    await assertSucceeds(reservar(ANA));
    await assertSucceeds(cancelar(ANA));
    const franja = await getDoc(slotRef(as(LUIS)));
    assert.equal(franja.exists(), false);
    await assertSucceeds(reservar(LUIS, { bookingId: 'bk2' }));
  });

  test('a menos de 2 horas ya no se cancela', async () => {
    await assertSucceeds(reservar(ANA, { startAt: new Date(Date.now() + HOUR) }));
    await assertFails(cancelar(ANA));
  });

  test('cancelar exige liberar la franja, y la franja solo se libera cancelando', async () => {
    await assertSucceeds(reservar(ANA));
    await assertFails(cancelar(ANA, { liberar: false }));
    await assertFails(deleteDoc(slotRef(as(ANA))));
  });

  test('nadie cancela la reserva de otro', async () => {
    await assertSucceeds(reservar(ANA));
    await assertFails(cancelar(LUIS));
    await assertFails(cancelar(ADMIN));
  });

  test('al cancelar solo cambian el estado y la fecha de cancelación', async () => {
    await assertSucceeds(reservar(ANA));
    const otraHora = Timestamp.fromDate(new Date(Date.now() + 48 * HOUR));
    await assertFails(cancelar(ANA, { cambios: { startAt: otraHora } }));
  });

  test('una reserva cancelada no se reactiva ni se borra', async () => {
    await assertSucceeds(reservar(ANA));
    await assertSucceeds(cancelar(ANA));
    await assertFails(updateDoc(bookingRef(as(ANA)), { status: 'active' }));
    await assertFails(deleteDoc(bookingRef(as(ANA))));
  });
});

describe('cualquier otra colección', () => {
  test('está cerrada', async () => {
    await assertFails(getDoc(doc(as(ADMIN), 'pagos', 'p1')));
    await assertFails(setDoc(doc(as(ANA), 'pagos', 'p1'), { uid: ANA.uid }));
  });
});
