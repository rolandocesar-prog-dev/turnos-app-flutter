import '../../resources/domain/resource.dart';
import '../../resources/domain/schedule_format.dart';

/// Problemas de lo que el administrador escribe en el formulario de recurso (design.md §11). La
/// presentación los traduce (design.md §14).
enum ResourceInputIssue { nameMissing, nameTooLong, descriptionTooLong }

/// Problemas del horario de un día.
enum DayRangesIssue { notARange, invalidTime, endBeforeStart, overlap }

/// Horario de un día mal escrito; [text] es el trozo que falla (para `notARange`).
class DayRangesException implements Exception {
  const DayRangesException(this.issue, [this.text = '']);

  final DayRangesIssue issue;
  final String text;

  @override
  String toString() => 'DayRangesException(${issue.name}, $text)';
}

/// Validación del formulario de recurso: funciones puras, con los mismos límites que las reglas
/// de Firestore. Devuelven el problema, o `null` si el valor es válido.
abstract final class ResourceInput {
  static const maxNameLength = 60;
  static const maxDescriptionLength = 300;

  /// Duraciones de turno que ofrece el formulario, en minutos.
  static const slotMinutesOptions = [15, 30, 45, 60, 90, 120];

  static ResourceInputIssue? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return ResourceInputIssue.nameMissing;
    if (text.length > maxNameLength) return ResourceInputIssue.nameTooLong;
    return null;
  }

  static ResourceInputIssue? description(String? value) =>
      (value?.trim().length ?? 0) > maxDescriptionLength
          ? ResourceInputIssue.descriptionTooLong
          : null;

  /// El problema del horario de un día, o `null` si [parseDayRanges] lo acepta.
  static DayRangesException? dayRanges(String? value) {
    try {
      parseDayRanges(value ?? '');
      return null;
    } on DayRangesException catch (error) {
      return error;
    }
  }
}

final _range = RegExp(r'^(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})$');

/// Lee el horario de un día escrito como «09:00-13:00, 15:00-19:00»; vacío es cerrado. Los
/// intervalos deben estar en orden y sin solaparse. Lanza [DayRangesException].
List<TimeRange> parseDayRanges(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];

  final ranges = <TimeRange>[];
  for (final part in trimmed.split(',')) {
    final match = _range.firstMatch(part.trim());
    if (match == null) {
      throw DayRangesException(DayRangesIssue.notARange, part.trim());
    }
    final [startH, startM, endH, endM] = [
      for (var group = 1; group <= 4; group++) int.parse(match.group(group)!),
    ];
    if (startH > 23 || endH > 23 || startM > 59 || endM > 59) {
      throw const DayRangesException(DayRangesIssue.invalidTime);
    }
    final range = TimeRange(startH * 60 + startM, endH * 60 + endM);
    if (range.endMinutes <= range.startMinutes) {
      throw const DayRangesException(DayRangesIssue.endBeforeStart);
    }
    if (ranges.isNotEmpty && range.startMinutes < ranges.last.endMinutes) {
      throw const DayRangesException(DayRangesIssue.overlap);
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
