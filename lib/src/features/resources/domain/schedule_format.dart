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
