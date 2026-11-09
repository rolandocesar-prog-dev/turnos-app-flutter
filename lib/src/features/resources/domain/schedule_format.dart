import 'resource.dart';

/// Textos del horario para la interfaz (sin depender de Flutter).
abstract final class ScheduleFormat {
  static const weekdayNames = {
    DateTime.monday: 'Lunes',
    DateTime.tuesday: 'Martes',
    DateTime.wednesday: 'Miércoles',
    DateTime.thursday: 'Jueves',
    DateTime.friday: 'Viernes',
    DateTime.saturday: 'Sábado',
    DateTime.sunday: 'Domingo',
  };

  static const _shortWeekdays = {
    DateTime.monday: 'lun',
    DateTime.tuesday: 'mar',
    DateTime.wednesday: 'mié',
    DateTime.thursday: 'jue',
    DateTime.friday: 'vie',
    DateTime.saturday: 'sáb',
    DateTime.sunday: 'dom',
  };

  /// «Hoy», «Mañana» o «mié 11» para el selector de días.
  static String dayLabel(DateTime day, DateTime today) {
    final days = DateTime(day.year, day.month, day.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return switch (days) {
      0 => 'Hoy',
      1 => 'Mañana',
      _ => '${_shortWeekdays[day.weekday]} ${day.day}',
    };
  }

  static const _shortMonths = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sept',
    'oct',
    'nov',
    'dic',
  ];

  /// «Hoy», «Mañana» o «mié 11 nov», para fechas que pueden estar lejos (Mis reservas).
  static String dateLabel(DateTime day, DateTime today) {
    final label = dayLabel(day, today);
    return label.contains(' ')
        ? '$label ${_shortMonths[day.month - 1]}'
        : label;
  }

  /// Hora de [moment] como «HH:mm».
  static String clock(DateTime moment) =>
      time(moment.hour * 60 + moment.minute);

  /// Minutos desde la medianoche como «HH:mm».
  static String time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  /// «08:00–13:00, 15:00–19:00» o «Cerrado».
  static String ranges(List<TimeRange>? ranges) =>
      ranges == null || ranges.isEmpty
          ? 'Cerrado'
          : ranges
              .map((r) => '${time(r.startMinutes)}–${time(r.endMinutes)}')
              .join(', ');

  /// «Turnos de 30 min» o «Turnos de 1 h 30 min».
  static String slotDuration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    final text = switch ((hours, rest)) {
      (0, _) => '$rest min',
      (_, 0) => '$hours h',
      _ => '$hours h $rest min',
    };
    return 'Turnos de $text';
  }
}
