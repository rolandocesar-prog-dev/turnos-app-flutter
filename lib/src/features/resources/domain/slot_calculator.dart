import 'resource.dart';

/// Una franja reservable de un recurso (design.md §3 y §9).
class Slot {
  const Slot({required this.id, required this.start, required this.end});

  /// Id determinista `yyyy-MM-ddTHH:mm`: la misma franja tiene siempre el mismo id, y así una
  /// reserva duplicada choca en Firestore (RF-03).
  final String id;
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is Slot &&
      other.id == id &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(id, start, end);

  @override
  String toString() => 'Slot($id)';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// Fecha como `yyyy-MM-dd` (formato de `blockedDates`).
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

/// Id de la franja que empieza en [start]: `yyyy-MM-ddTHH:mm`.
String slotId(DateTime start) =>
    '${dateKey(start)}T${_two(start.hour)}:${_two(start.minute)}';

/// Franjas de [resource] en el día de [date], en orden (RF-02). Corta cada intervalo del horario
/// semanal en turnos de `slotMinutes`; un turno que no entra completo al final se descarta. Un
/// día bloqueado o sin horario no tiene franjas. Las horas son las locales del negocio.
List<Slot> slotsFor(Resource resource, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  if (resource.blockedDates.contains(dateKey(day))) return const [];

  final length = resource.slotMinutes;
  final byId = <String, Slot>{};
  for (final range
      in resource.weeklySchedule[day.weekday] ?? const <TimeRange>[]) {
    for (var minute = range.startMinutes;
        minute + length <= range.endMinutes;
        minute += length) {
      final start = DateTime(day.year, day.month, day.day, 0, minute);
      final slot = Slot(
        id: slotId(start),
        start: start,
        end: start.add(Duration(minutes: length)),
      );
      // Si dos intervalos se solapan, la misma franja no se repite.
      byId[slot.id] = slot;
    }
  }
  return byId.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}
