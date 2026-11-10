import { describe, expect, test } from 'vitest';

import { MAX_ACTIVE_BOOKINGS, bookingsOverLimit } from '../../src/limit.js';

const at = (minute: number) => new Date(Date.UTC(2026, 10, 10, 12, minute));

describe('bookingsOverLimit (design.md §12)', () => {
  test('con 3 o menos no sobra ninguna', () => {
    expect(MAX_ACTIVE_BOOKINGS).toBe(3);
    expect(bookingsOverLimit([])).toEqual([]);
    expect(
      bookingsOverLimit([
        { id: 'a', createdAt: at(1) },
        { id: 'b', createdAt: at(2) },
        { id: 'c', createdAt: at(3) },
      ]),
    ).toEqual([]);
  });

  test('sobran las más recientes, sin importar el orden de llegada', () => {
    const bookings = [
      { id: 'cuarta', createdAt: at(4) },
      { id: 'primera', createdAt: at(1) },
      { id: 'quinta', createdAt: at(5) },
      { id: 'segunda', createdAt: at(2) },
      { id: 'tercera', createdAt: at(3) },
    ];
    expect(bookingsOverLimit(bookings)).toEqual(['cuarta', 'quinta']);
    expect(bookingsOverLimit([...bookings].reverse())).toEqual(['cuarta', 'quinta']);
  });

  test('si dos se crearon en el mismo instante, decide el id', () => {
    const bookings = [
      { id: 'a', createdAt: at(1) },
      { id: 'b', createdAt: at(2) },
      { id: 'z', createdAt: at(3) },
      { id: 'm', createdAt: at(3) },
    ];
    expect(bookingsOverLimit(bookings)).toEqual(['z']);
  });

  test('no modifica la lista recibida', () => {
    const bookings = [
      { id: 'b', createdAt: at(2) },
      { id: 'a', createdAt: at(1) },
    ];
    bookingsOverLimit(bookings, 1);
    expect(bookings.map((b) => b.id)).toEqual(['b', 'a']);
  });
});
