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
import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

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

  test('todavía nadie crea ni borra franjas (reservar llega en M3)', async () => {
    const libre = doc(as(ANA), 'resources', 'cancha-1', 'slots', '2026-11-10T19:00');
    await assertFails(setDoc(libre, { bookingId: 'b2', uid: ANA.uid }));
    await assertFails(deleteDoc(slot(as(LUIS))));
    await assertFails(deleteDoc(slot(as(ADMIN))));
  });
});

describe('cualquier otra colección', () => {
  test('está cerrada', async () => {
    await assertFails(getDoc(doc(as(ADMIN), 'bookings', 'b1')));
    await assertFails(setDoc(doc(as(ANA), 'bookings', 'b1'), { uid: ANA.uid }));
  });
});
