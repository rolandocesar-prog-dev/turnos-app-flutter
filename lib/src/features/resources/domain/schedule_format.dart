/// Horas como texto «HH:mm», sin palabras: las etiquetas de días y meses salen de las traducciones
/// (`ScheduleLabels`, design.md §14).
abstract final class ScheduleFormat {
  /// Hora de [moment] como «HH:mm».
  static String clock(DateTime moment) =>
      time(moment.hour * 60 + moment.minute);

  /// Minutos desde la medianoche como «HH:mm».
  static String time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}
