import 'package:flutter/widgets.dart';

import '../../features/resources/domain/resource.dart';
import '../../features/resources/domain/schedule_format.dart';
import 'l10n.dart';

/// Fechas, horarios y duraciones con palabras, traducidos (design.md §14).
class ScheduleLabels {
  const ScheduleLabels(this._l10n);

  factory ScheduleLabels.of(BuildContext context) =>
      ScheduleLabels(context.l10n);

  final AppLocalizations _l10n;

  /// Días de la semana en orden, con la numeración de `DateTime.weekday` (1 = lunes).
  static const weekdays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  static const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _monthKeys = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  /// «Lunes».
  String weekdayName(int weekday) =>
      _l10n.weekdayName(_weekdayKeys[weekday - 1]);

  String _weekdayShort(int weekday) =>
      _l10n.weekdayShort(_weekdayKeys[weekday - 1]);

  String _monthShort(int month) => _l10n.monthShort(_monthKeys[month - 1]);

  /// «Hoy», «Mañana» o «mié 11» para el selector de días.
  String dayLabel(DateTime day, DateTime today) =>
      switch (_daysFrom(today, day)) {
        0 => _l10n.today,
        1 => _l10n.tomorrow,
        _ => _l10n.dayShort(_weekdayShort(day.weekday), '${day.day}'),
      };

  /// «Hoy», «Mañana» o «mié 11 nov», para fechas que pueden estar lejos (Mis reservas).
  String dateLabel(DateTime day, DateTime today) =>
      switch (_daysFrom(today, day)) {
        0 => _l10n.today,
        1 => _l10n.tomorrow,
        _ => _l10n.dateShort(
            _weekdayShort(day.weekday),
            '${day.day}',
            _monthShort(day.month),
          ),
      };

  /// «vie 25 dic 2026», para fechas sin relación con hoy (días bloqueados).
  String longDate(DateTime day) => _l10n.dateLong(
        _weekdayShort(day.weekday),
        '${day.day}',
        _monthShort(day.month),
        '${day.year}',
      );

  /// «Mañana, 09:00–10:00».
  String dateAndRange(DateTime start, DateTime end, DateTime today) =>
      _l10n.dateAndTime(dateLabel(start, today), clockRange(start, end));

  /// «09:00–10:00».
  String clockRange(DateTime start, DateTime end) =>
      _l10n.timeRange(ScheduleFormat.clock(start), ScheduleFormat.clock(end));

  /// «08:00–13:00, 15:00–19:00» o «Cerrado».
  String ranges(List<TimeRange>? ranges) => ranges == null || ranges.isEmpty
      ? _l10n.closed
      : ranges
          .map(
            (r) => _l10n.timeRange(
              ScheduleFormat.time(r.startMinutes),
              ScheduleFormat.time(r.endMinutes),
            ),
          )
          .join(', ');

  /// «Turnos de 30 min» o «Turnos de 1 h 30 min».
  String slotDuration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final text = switch ((hours, rest)) {
      (0, _) => _l10n.durationMinutes('$rest'),
      (_, 0) => _l10n.durationHours('$hours'),
      _ => _l10n.durationHoursMinutes('$hours', '$rest'),
    };
    return _l10n.slotDuration(text);
  }

  static int _daysFrom(DateTime today, DateTime day) =>
      DateTime(day.year, day.month, day.day)
          .difference(DateTime(today.year, today.month, today.day))
          .inDays;
}
