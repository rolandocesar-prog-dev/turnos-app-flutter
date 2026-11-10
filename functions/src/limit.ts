// Límite de reservas activas en el servidor (RF-03, design.md §12). Lógica pura, sin Firebase.

/** Como en la app (`maxActiveBookings`, design.md §10). */
export const MAX_ACTIVE_BOOKINGS = 3;

/** Lo que ve el cliente en «Mis reservas» cuando el servidor cancela una reserva de más. */
export const LIMIT_CANCEL_REASON =
  'Superaste el límite de 3 reservas activas; esta reserva no se tomó.';

export interface ActiveBooking {
  id: string;
  createdAt: Date;
}

/**
 * Ids de las reservas que sobran: todas las que quedan después de las [max] más antiguas, por
 * `createdAt` y por id si empatan. Como el orden no depende de qué disparador corre primero, dos
 * reservas simultáneas del mismo cliente terminan siempre igual.
 */
export function bookingsOverLimit(
  active: readonly ActiveBooking[],
  max: number = MAX_ACTIVE_BOOKINGS,
): string[] {
  return [...active]
    .sort(
      (a, b) =>
        a.createdAt.getTime() - b.createdAt.getTime() ||
        (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
    )
    .slice(max)
    .map((booking) => booking.id);
}
