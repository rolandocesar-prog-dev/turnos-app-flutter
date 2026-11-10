import { describe, expect, test } from 'vitest';

import {
  cancellationNotice,
  isBusinessCancellation,
  isStaleTokenError,
  needsReminder,
  reminderNotice,
  when,
} from '../../src/notices.js';

// La Paz es UTC-4 todo el año: 22:00 UTC = 18:00 en La Paz.
const LA_PAZ = 'America/La_Paz';
const utc = (day: number, hour: number, minute = 0) =>
  new Date(Date.UTC(2026, 10, day, hour, minute));

describe('needsReminder (design.md §13)', () => {
  const now = utc(10, 21);
  const active = (startAt: Date, extra = {}) => ({ status: 'active', startAt, ...extra });

  test('dentro de la hora siguiente, activa y sin recordatorio', () => {
    expect(needsReminder(active(utc(10, 21, 30)), now)).toBe(true);
    expect(needsReminder(active(utc(10, 22)), now)).toBe(true);
  });

  test('fuera de la hora siguiente, no', () => {
    expect(needsReminder(active(utc(10, 22, 1)), now)).toBe(false);
    expect(needsReminder(active(utc(10, 21)), now)).toBe(false);
    expect(needsReminder(active(utc(10, 20)), now)).toBe(false);
  });

  test('cancelada o ya recordada, no', () => {
    expect(needsReminder({ status: 'cancelled', startAt: utc(10, 21, 30) }, now)).toBe(false);
    expect(needsReminder(active(utc(10, 21, 30), { reminderSentAt: utc(10, 20) }), now)).toBe(
      false,
    );
  });
});

describe('isBusinessCancellation', () => {
  const before = { status: 'active' };

  test('solo la cancelación del negocio, con motivo', () => {
    expect(isBusinessCancellation(before, { status: 'cancelled', cancelReason: 'Lluvia' })).toBe(
      true,
    );
  });

  test('ni la del cliente, ni la automática, ni otros cambios', () => {
    expect(isBusinessCancellation(before, { status: 'cancelled' })).toBe(false);
    expect(
      isBusinessCancellation(before, {
        status: 'cancelled',
        cancelReason: 'Límite',
        cancelledBy: 'system',
      }),
    ).toBe(false);
    expect(isBusinessCancellation(before, { status: 'active', cancelReason: 'x' })).toBe(false);
    expect(
      isBusinessCancellation({ status: 'cancelled' }, { status: 'cancelled', cancelReason: 'x' }),
    ).toBe(false);
  });
});

describe('textos en la hora del negocio', () => {
  test('hoy, mañana o la fecha, en La Paz y no en UTC', () => {
    const now = utc(10, 20); // 16:00 del martes 10 en La Paz
    expect(when(utc(10, 22), now, LA_PAZ)).toBe('hoy a las 18:00');
    // 02:30 UTC del 11 todavía es el 10 en La Paz.
    expect(when(utc(11, 2, 30), now, LA_PAZ)).toBe('hoy a las 22:30');
    expect(when(utc(11, 13), now, LA_PAZ)).toBe('mañana a las 09:00');
    expect(when(utc(17, 22), now, LA_PAZ)).toBe('mar 17 nov a las 18:00');
  });

  test('cerca de medianoche, «hoy» es el día del negocio', () => {
    const now = utc(11, 3, 30); // 23:30 del 10 en La Paz
    expect(when(utc(11, 4, 15), now, LA_PAZ)).toBe('mañana a las 00:15');
  });

  test('recordatorio y aviso de cancelación', () => {
    const booking = { resourceName: 'Cancha de fútbol 5', startAt: utc(10, 22) };
    expect(reminderNotice(booking, utc(10, 21), LA_PAZ)).toEqual({
      title: 'Tu turno es en 1 hora',
      body: 'Cancha de fútbol 5, hoy a las 18:00.',
    });
    expect(cancellationNotice(booking, 'Lluvia', utc(9, 15), LA_PAZ)).toEqual({
      title: 'Tu reserva fue cancelada',
      body: 'Cancha de fútbol 5, mañana a las 18:00. Motivo: Lluvia',
    });
  });

  test('por defecto usa la zona de La Paz', () => {
    const booking = { resourceName: 'Sala', startAt: utc(10, 22) };
    expect(reminderNotice(booking, utc(10, 21)).body).toBe('Sala, hoy a las 18:00.');
  });
});

describe('isStaleTokenError', () => {
  test('quita los ids que FCM ya no reconoce', () => {
    expect(isStaleTokenError('messaging/registration-token-not-registered')).toBe(true);
    expect(isStaleTokenError('messaging/invalid-registration-token')).toBe(true);
    expect(isStaleTokenError('messaging/internal-error')).toBe(false);
    expect(isStaleTokenError(undefined)).toBe(false);
  });
});
