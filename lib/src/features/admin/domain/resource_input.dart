import '../../resources/domain/resource.dart';
import '../../resources/domain/schedule_format.dart';

/// Validación de lo que el administrador escribe en el formulario de recurso (design.md §11).
/// Funciones puras: devuelven el mensaje de error, o `null` si el valor es válido, con los mismos
/// límites que las reglas de Firestore.
abstract final class ResourceInput {
  static const maxNameLength = 60;
  static const maxDescriptionLength = 300;

  /// Duraciones de turno que ofrece el formulario, en minutos.
  static const slotMinutesOptions = [15, 30, 45, 60, 90, 120];

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Escribe un nombre.';
    if (text.length > maxNameLength) {
      return 'Usa como máximo $maxNameLength caracteres.';
    }
    return null;
  }

  static String? description(String? value) {
    if ((value?.trim().length ?? 0) > maxDescriptionLength) {
      return 'Usa como máximo $maxDescriptionLength caracteres.';
    }
    return null;
  }

  /// Mensaje de error del horario de un día, o `null` si [parseDayRanges] lo acepta.
  static String? dayRanges(String? value) {
    try {
      parseDayRanges(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
}

final _range = RegExp(r'^([0-2]?\d:[0-5]\d)\s*[-–]\s*([0-2]?\d:[0-5]\d)$');

/// Lee el horario de un día escrito como «09:00-13:00, 15:00-19:00»; vacío es cerrado. Los
/// intervalos deben estar en orden y sin solaparse. Lanza `FormatException` con un mensaje para
/// mostrar en el campo.
List<TimeRange> parseDayRanges(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final ranges = <TimeRange>[];
  for (final part in trimmed.split(',')) {
    final match = _range.firstMatch(part.trim());
    if (match == null) {
      throw FormatException(
        '«${part.trim()}» no es un intervalo; escribe por ejemplo 09:00-13:00.',
      );
    }
    // TimeRange.parse rechaza horas imposibles y un fin que no es posterior al inicio.
    final range = TimeRange.parse(_pad(match.group(1)!), _pad(match.group(2)!));
    if (ranges.isNotEmpty && range.startMinutes < ranges.last.endMinutes) {
      throw const FormatException(
        'Los intervalos deben ir en orden y sin solaparse.',
      );
    }
    ranges.add(range);
  }
  return ranges;
}

/// Texto editable de [ranges], en el formato que lee [parseDayRanges].
String formatDayRanges(List<TimeRange> ranges) => ranges
    .map(
      (r) =>
          '${ScheduleFormat.time(r.startMinutes)}-${ScheduleFormat.time(r.endMinutes)}',
    )
    .join(', ');

/// «9:00» → «09:00». Una hora como «25:00» sigue siendo inválida y la rechaza [TimeRange.parse].
String _pad(String time) => time.length == 4 ? '0$time' : time;
