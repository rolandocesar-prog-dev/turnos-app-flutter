import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/core/l10n/l10n.dart';
import 'package:turnos_app/src/core/l10n/schedule_labels.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';
import 'package:turnos_app/src/features/resources/domain/schedule_format.dart';

void main() {
  final labels = ScheduleLabels(lookupAppLocalizations(const Locale('es')));

  test('horas con dos dígitos', () {
    expect(ScheduleFormat.time(0), '00:00');
    expect(ScheduleFormat.time(9 * 60 + 5), '09:05');
    expect(ScheduleFormat.time(23 * 60 + 30), '23:30');
    expect(ScheduleFormat.clock(DateTime(2026, 11, 9, 7, 5)), '07:05');
  });

  test('intervalos del día, o «Cerrado»', () {
    expect(
      labels.ranges(const [TimeRange(540, 780), TimeRange(900, 1140)]),
      '09:00–13:00, 15:00–19:00',
    );
    expect(labels.ranges(null), 'Cerrado');
    expect(labels.ranges(const []), 'Cerrado');
  });

  test('día del selector: hoy, mañana o el día de la semana', () {
    final today = DateTime(2026, 11, 9, 10);
    expect(labels.dayLabel(DateTime(2026, 11, 9), today), 'Hoy');
    expect(labels.dayLabel(DateTime(2026, 11, 10), today), 'Mañana');
    expect(labels.dayLabel(DateTime(2026, 11, 11), today), 'mié 11');
  });

  test('fecha de una reserva: hoy, mañana o con el mes', () {
    final today = DateTime(2026, 11, 9, 10);
    expect(labels.dateLabel(DateTime(2026, 11, 9, 18), today), 'Hoy');
    expect(labels.dateLabel(DateTime(2026, 11, 10, 8), today), 'Mañana');
    expect(labels.dateLabel(DateTime(2026, 12, 2, 8), today), 'mié 2 dic');
    expect(labels.dateLabel(DateTime(2026, 11, 2, 8), today), 'lun 2 nov');
    expect(labels.dateLabel(DateTime(2026, 9, 7, 8), today), 'lun 7 sept');
    expect(
      labels.dateAndRange(
        DateTime(2026, 11, 10, 9),
        DateTime(2026, 11, 10, 10),
        today,
      ),
      'Mañana, 09:00–10:00',
    );
  });

  test('fecha larga y nombres de los días', () {
    expect(labels.longDate(DateTime(2026, 12, 25)), 'vie 25 dic 2026');
    expect(
      [for (final day in ScheduleLabels.weekdays) labels.weekdayName(day)],
      [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ],
    );
  });

  test('duración del turno', () {
    expect(labels.slotDuration(30), 'Turnos de 30 min');
    expect(labels.slotDuration(60), 'Turnos de 1 h');
    expect(labels.slotDuration(90), 'Turnos de 1 h 30 min');
  });
}
