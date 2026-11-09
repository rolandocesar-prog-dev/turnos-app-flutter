import '../domain/resource.dart';

/// Claves de `weeklySchedule` en Firestore y su número de `DateTime.weekday`.
const weekdayKeys = {
  'mon': DateTime.monday,
  'tue': DateTime.tuesday,
  'wed': DateTime.wednesday,
  'thu': DateTime.thursday,
  'fri': DateTime.friday,
  'sat': DateTime.saturday,
  'sun': DateTime.sunday,
};

/// Convierte `resources/{id}` en un [Resource]. Es estricto: un documento mal formado lanza
/// `FormatException` con el campo que falla, en lugar de mostrar datos inventados.
Resource resourceFromFirestore(String id, Map<String, dynamic> data) {
  T field<T>(String name) {
    final value = data[name];
    if (value is! T) {
      throw FormatException('resources/$id: «$name» falta o no es $T');
    }
    return value;
  }

  final slotMinutes = field<int>('slotMinutes');
  if (slotMinutes <= 0) {
    throw FormatException('resources/$id: slotMinutes debe ser positivo');
  }

  final schedule = <int, List<TimeRange>>{};
  for (final MapEntry(:key, :value)
      in field<Map<String, dynamic>>('weeklySchedule').entries) {
    final weekday = weekdayKeys[key];
    if (weekday == null) {
      throw FormatException('resources/$id: día desconocido «$key»');
    }
    if (value is! List) {
      throw FormatException(
        'resources/$id: el horario de «$key» no es una lista',
      );
    }
    schedule[weekday] = [
      for (final range in value)
        if (range case {'start': final String start, 'end': final String end})
          TimeRange.parse(start, end)
        else
          throw FormatException('resources/$id: intervalo inválido en «$key»'),
    ];
  }

  final blocked = data['blockedDates'] ?? const <dynamic>[];
  if (blocked is! List) {
    throw FormatException('resources/$id: blockedDates no es una lista');
  }

  return Resource(
    id: id,
    name: field<String>('name'),
    description: data['description'] as String? ?? '',
    photoUrl: data['photoUrl'] as String?,
    slotMinutes: slotMinutes,
    active: data['active'] == true,
    weeklySchedule: schedule,
    blockedDates: {for (final date in blocked) date.toString()},
  );
}
