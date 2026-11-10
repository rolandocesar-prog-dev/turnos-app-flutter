// Recordatorios y avisos de cancelación (RF-05, design.md §13 «Envío»). Lógica pura, sin Firebase.

/** Zona horaria del negocio por defecto: las horas de los turnos son las locales (design.md §9). */
export const DEFAULT_TIME_ZONE = 'America/La_Paz';

/** Se recuerda el turno dentro de la hora anterior a su inicio. */
export const REMINDER_LEAD_MS = 60 * 60 * 1000;

export interface Notice {
  title: string;
  body: string;
}

export interface BookingForNotice {
  resourceName: string;
  startAt: Date;
}

export interface BookingState {
  status?: unknown;
  startAt?: Date;
  reminderSentAt?: unknown;
  cancelReason?: unknown;
  cancelledBy?: unknown;
}

/** Rango de inicio de los turnos a recordar en la ejecución de [now]: toda la hora siguiente. */
export function reminderWindow(now: Date): { from: Date; to: Date } {
  return { from: now, to: new Date(now.getTime() + REMINDER_LEAD_MS) };
}

/** Activa, sin empezar, dentro de la hora siguiente y sin recordatorio enviado. */
export function needsReminder(booking: BookingState, now: Date): boolean {
  const { from, to } = reminderWindow(now);
  return (
    booking.status === 'active' &&
    booking.reminderSentAt === undefined &&
    booking.startAt !== undefined &&
    booking.startAt > from &&
    booking.startAt <= to
  );
}

/** La canceló el negocio: pasó de activa a cancelada con motivo y sin `cancelledBy` (§11). */
export function isBusinessCancellation(before: BookingState, after: BookingState): boolean {
  return (
    before.status === 'active' &&
    after.status === 'cancelled' &&
    typeof after.cancelReason === 'string' &&
    after.cancelledBy === undefined
  );
}

export function reminderNotice(
  booking: BookingForNotice,
  now: Date,
  timeZone: string = DEFAULT_TIME_ZONE,
): Notice {
  return {
    title: 'Tu turno es en 1 hora',
    body: `${booking.resourceName}, ${when(booking.startAt, now, timeZone)}.`,
  };
}

export function cancellationNotice(
  booking: BookingForNotice,
  reason: string,
  now: Date,
  timeZone: string = DEFAULT_TIME_ZONE,
): Notice {
  return {
    title: 'Tu reserva fue cancelada',
    body: `${booking.resourceName}, ${when(booking.startAt, now, timeZone)}. Motivo: ${reason}`,
  };
}

/** Errores de FCM que indican un id que ya no sirve y conviene quitar del perfil. */
export function isStaleTokenError(code: string | undefined): boolean {
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token'
  );
}

/** «hoy a las 18:00», «mañana a las 09:30» o «mar 10 nov a las 18:00», en [timeZone]. */
export function when(start: Date, now: Date, timeZone: string): string {
  const day = calendarDay(start, timeZone);
  const today = calendarDay(now, timeZone);
  const diff = Math.round((day.utc - today.utc) / (24 * 60 * 60 * 1000));
  const label =
    diff === 0
      ? 'hoy'
      : diff === 1
        ? 'mañana'
        : `${day.weekday} ${day.day} ${day.month}`;
  return `${label} a las ${day.time}`;
}

const MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
const WEEKDAYS = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];

/** Fecha y hora de [date] vistas en [timeZone], con los mismos nombres cortos que la app. */
function calendarDay(date: Date, timeZone: string) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone,
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    })
      .formatToParts(date)
      .map((part) => [part.type, part.value]),
  );
  const year = Number(parts.year);
  const month = Number(parts.month);
  const dayOfMonth = Number(parts.day);
  const utc = Date.UTC(year, month - 1, dayOfMonth);
  return {
    utc,
    day: dayOfMonth,
    month: MONTHS[month - 1] ?? '',
    weekday: WEEKDAYS[new Date(utc).getUTCDay()] ?? '',
    time: `${parts.hour}:${parts.minute}`,
  };
}
