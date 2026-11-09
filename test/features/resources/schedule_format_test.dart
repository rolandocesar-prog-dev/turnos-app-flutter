import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';
import 'package:turnos_app/src/features/resources/domain/schedule_format.dart';

void main() {
  test('horas con dos dígitos', () {
    expect(ScheduleFormat.time(0), '00:00');
    expect(ScheduleFormat.time(9 * 60 + 5), '09:05');
    expect(ScheduleFormat.time(23 * 60 + 30), '23:30');
  });

  test('intervalos del día, o «Cerrado»', () {
    expect(
      ScheduleFormat.ranges(const [TimeRange(540, 780), TimeRange(900, 1140)]),
      '09:00–13:00, 15:00–19:00',
    );
    expect(ScheduleFormat.ranges(null), 'Cerrado');
    expect(ScheduleFormat.ranges(const []), 'Cerrado');
  });

  test('fecha de una reserva: hoy, mañana o con el mes', () {
    final today = DateTime(2026, 11, 9, 10);
    expect(ScheduleFormat.dateLabel(DateTime(2026, 11, 9, 18), today), 'Hoy');
    expect(
      ScheduleFormat.dateLabel(DateTime(2026, 11, 10, 8), today),
      'Mañana',
    );
    expect(
      ScheduleFormat.dateLabel(DateTime(2026, 12, 2, 8), today),
      'mié 2 dic',
    );
    expect(
      ScheduleFormat.dateLabel(DateTime(2026, 11, 2, 8), today),
      'lun 2 nov',
    );
    expect(ScheduleFormat.clock(DateTime(2026, 11, 9, 7, 5)), '07:05');
  });

  test('duración del turno', () {
    expect(ScheduleFormat.slotDuration(30), 'Turnos de 30 min');
    expect(ScheduleFormat.slotDuration(60), 'Turnos de 1 h');
    expect(ScheduleFormat.slotDuration(90), 'Turnos de 1 h 30 min');
  });
}
