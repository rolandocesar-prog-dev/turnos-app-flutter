import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';
import 'package:turnos_app/src/features/resources/domain/slot_calculator.dart';

Resource resource({
  int slotMinutes = 30,
  Map<int, List<TimeRange>> schedule = const {},
  Set<String> blocked = const {},
}) =>
    Resource(
      id: 'r',
      name: 'Recurso',
      description: '',
      slotMinutes: slotMinutes,
      active: true,
      weeklySchedule: schedule,
      blockedDates: blocked,
    );

TimeRange range(String start, String end) => TimeRange.parse(start, end);

List<String> times(List<Slot> slots) => [
      for (final s in slots)
        '${s.start.hour.toString().padLeft(2, '0')}:${s.start.minute.toString().padLeft(2, '0')}',
    ];

void main() {
  // 9 de noviembre de 2026 es lunes.
  final monday = DateTime(2026, 11, 9);
  setUpAll(() => expect(monday.weekday, DateTime.monday));

  test('corta cada intervalo en turnos de la duración del recurso', () {
    final consultorio = resource(
      schedule: {
        DateTime.monday: [range('09:00', '13:00'), range('15:00', '19:00')],
      },
    );

    final slots = slotsFor(consultorio, monday);

    expect(slots, hasLength(16));
    expect(times(slots).first, '09:00');
    expect(times(slots).sublist(7, 9), ['12:30', '15:00']);
    expect(slots.last.end, DateTime(2026, 11, 9, 19));
  });

  test('un turno que no entra completo al final se descarta', () {
    final cancha = resource(
      slotMinutes: 60,
      schedule: {
        DateTime.monday: [range('08:00', '10:45')],
      },
    );

    expect(times(slotsFor(cancha, monday)), ['08:00', '09:00']);
  });

  test('cada franja dura lo que dice el recurso', () {
    final cancha = resource(
      slotMinutes: 90,
      schedule: {
        DateTime.monday: [range('18:00', '21:00')],
      },
    );

    final slots = slotsFor(cancha, monday);

    expect(slots, hasLength(2));
    expect(
      slots.first.end.difference(slots.first.start),
      const Duration(minutes: 90),
    );
    expect(slots.last.start, DateTime(2026, 11, 9, 19, 30));
  });

  test('el id es determinista: yyyy-MM-ddTHH:mm', () {
    final r = resource(
      schedule: {
        DateTime.monday: [range('09:00', '10:00')],
      },
    );

    expect(
      slotsFor(r, monday).map((s) => s.id),
      ['2026-11-09T09:00', '2026-11-09T09:30'],
    );
    expect(
      slotsFor(r, DateTime(2026, 11, 9, 17, 45)),
      slotsFor(r, monday),
    ); // la hora no importa
  });

  test('un día bloqueado o sin horario no tiene franjas', () {
    final r = resource(
      schedule: {
        DateTime.monday: [range('09:00', '13:00')],
      },
      blocked: {'2026-11-09'},
    );

    expect(slotsFor(r, monday), isEmpty);
    expect(slotsFor(r, DateTime(2026, 11, 10)), isEmpty); // martes cerrado
  });

  test('ordena los intervalos y no repite franjas si se solapan', () {
    final r = resource(
      slotMinutes: 60,
      schedule: {
        DateTime.monday: [range('11:00', '13:00'), range('09:00', '12:00')],
      },
    );

    expect(times(slotsFor(r, monday)), ['09:00', '10:00', '11:00', '12:00']);
  });

  test('dateKey y slotId rellenan con ceros', () {
    final start = DateTime(2027, 1, 5, 8, 5);
    expect(dateKey(start), '2027-01-05');
    expect(slotId(start), '2027-01-05T08:05');
  });
}
