/// Intervalo de atención dentro de un día, en minutos desde la medianoche (p. ej. 08:00 = 480).
class TimeRange {
  const TimeRange(this.startMinutes, this.endMinutes);

  /// Lee las horas «HH:mm» de inicio y fin: `TimeRange.parse('08:00', '22:00')`.
  factory TimeRange.parse(String start, String end) {
    final startMinutes = _minutes(start);
    final endMinutes = _minutes(end);
    if (startMinutes >= endMinutes) {
      throw FormatException(
        'El intervalo $start–$end debe terminar después de empezar',
      );
    }
    return TimeRange(startMinutes, endMinutes);
  }

  final int startMinutes;
  final int endMinutes;

  static int _minutes(String value) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
    if (match == null) {
      throw FormatException('Hora inválida: «$value» (se espera HH:mm)');
    }
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  @override
  bool operator ==(Object other) =>
      other is TimeRange &&
      other.startMinutes == startMinutes &&
      other.endMinutes == endMinutes;

  @override
  int get hashCode => Object.hash(startMinutes, endMinutes);
}

/// Recurso reservable (cancha, consultorio…), reflejo de `resources/{id}` (design.md §3 y §9).
class Resource {
  const Resource({
    required this.id,
    required this.name,
    required this.description,
    required this.slotMinutes,
    required this.active,
    required this.weeklySchedule,
    this.blockedDates = const {},
    this.photoUrl,
  });

  final String id;
  final String name;
  final String description;
  final String? photoUrl;

  /// Duración de cada turno.
  final int slotMinutes;
  final bool active;

  /// Horario por día de la semana, con la numeración de `DateTime.weekday` (1 = lunes).
  final Map<int, List<TimeRange>> weeklySchedule;

  /// Días sin atención, como «yyyy-MM-dd».
  final Set<String> blockedDates;
}
