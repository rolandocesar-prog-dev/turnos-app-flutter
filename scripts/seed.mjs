// Carga recursos de ejemplo en el emulador de Firestore en marcha (design.md §4, «Datos de ejemplo»).
// Uso: npm run emulators (en otra terminal) y luego npm run seed.
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';

const week = (ranges) =>
  Object.fromEntries(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'].map((d) => [d, ranges]));

const resources = {
  'cancha-futbol-5': {
    name: 'Cancha de fútbol 5',
    description: 'Cancha techada de césped sintético, con iluminación.',
    slotMinutes: 60,
    active: true,
    weeklySchedule: week([{ start: '08:00', end: '23:00' }]),
    blockedDates: ['2026-12-25', '2027-01-01'],
  },
  'consultorio-dental': {
    name: 'Consultorio dental',
    description: 'Consulta general y limpieza dental.',
    slotMinutes: 30,
    active: true,
    weeklySchedule: {
      mon: [{ start: '09:00', end: '13:00' }, { start: '15:00', end: '19:00' }],
      tue: [{ start: '09:00', end: '13:00' }, { start: '15:00', end: '19:00' }],
      wed: [{ start: '09:00', end: '13:00' }, { start: '15:00', end: '19:00' }],
      thu: [{ start: '09:00', end: '13:00' }, { start: '15:00', end: '19:00' }],
      fri: [{ start: '09:00', end: '13:00' }, { start: '15:00', end: '19:00' }],
      sat: [{ start: '09:00', end: '12:00' }],
    },
    blockedDates: [],
  },
  'sala-de-ensayo': {
    name: 'Sala de ensayo',
    description: 'En remodelación: no aparece en el catálogo (active: false).',
    slotMinutes: 120,
    active: false,
    weeklySchedule: week([{ start: '10:00', end: '22:00' }]),
    blockedDates: [],
  },
};

const env = await initializeTestEnvironment({
  projectId: 'demo-turnos',
  firestore: { host: '127.0.0.1', port: 8080 },
});
await env.withSecurityRulesDisabled(async (context) => {
  const db = context.firestore();
  for (const [id, data] of Object.entries(resources)) {
    await setDoc(doc(db, 'resources', id), data);
  }
});
await env.cleanup();
console.log(`Cargados ${Object.keys(resources).length} recursos en demo-turnos.`);
