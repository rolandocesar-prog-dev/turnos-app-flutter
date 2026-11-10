import '../domain/resource.dart';
import '../domain/schedule_format.dart';

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

/// Datos de `resources/{id}` para [resource] (el id no se guarda en el documento). Es el inverso
/// de [resourceFromFirestore]; solo lleva los campos que aceptan las reglas (design.md §11). Los
/// días sin horario no se escriben.
Map<String, Object> resourceToFirestore(Resource resource) {
  const time = ScheduleFormat.time;
  return {
    'name': resource.name,
    'description': resource.description,
    if (resource.photoUrl case final url?) 'photoUrl': url,
    'slotMinutes': resource.slotMinutes,
    'active': resource.active,
    'weeklySchedule': {
      for (final MapEntry(key: name, value: weekday) in weekdayKeys.entries)
        if (resource.weeklySchedule[weekday] case final ranges?
            when ranges.isNotEmpty)
          name: [
            for (final range in ranges)
              {
                'start': time(range.startMinutes),
                'end': time(range.endMinutes),
              },
          ],
    },
    'blockedDates': resource.blockedDates.toList()..sort(),
  };
}

/// Convierte los documentos del catálogo omitiendo los mal formados: uno roto no deja a todos sin
/// catálogo. Cada omitido se informa a [onInvalid] (design.md §9).
List<Resource> resourcesFromFirestore(
  Iterable<(String, Map<String, dynamic>)> docs, {
  required void Function(FormatException error) onInvalid,
}) {
  final resources = <Resource>[];
  for (final (id, data) in docs) {
    try {
      resources.add(resourceFromFirestore(id, data));
    } on FormatException catch (error) {
      onInvalid(error);
    }
  }
  return resources..sort((a, b) => a.name.compareTo(b.name));
}

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
