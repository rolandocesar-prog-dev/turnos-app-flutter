import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/admin/domain/resource_input.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';

void main() {
  group('parseDayRanges (design.md §11)', () {
    test('vacío es cerrado', () {
      expect(parseDayRanges(''), isEmpty);
      expect(parseDayRanges('   '), isEmpty);
    });

    test('lee uno o varios intervalos, con o sin espacios y con guion largo',
        () {
      expect(parseDayRanges('09:00-13:00'), [const TimeRange(540, 780)]);
      expect(
        parseDayRanges(' 9:00 - 13:00 ,15:00–19:30 '),
        [const TimeRange(540, 780), const TimeRange(900, 1170)],
      );
    });

    test('intervalos contiguos se aceptan', () {
      expect(
        parseDayRanges('08:00-12:00, 12:00-14:00'),
        [const TimeRange(480, 720), const TimeRange(720, 840)],
      );
    });

    test('rechaza lo que no es un intervalo', () {
      for (final text in ['9 a 13', '09:00', '09:00-', '09:00-13:00,', 'x']) {
        expect(
          () => parseDayRanges(text),
          throwsFormatException,
          reason: text,
        );
      }
    });

    test('rechaza horas imposibles y un fin que no es posterior', () {
      expect(() => parseDayRanges('25:00-26:00'), throwsFormatException);
      expect(() => parseDayRanges('13:00-09:00'), throwsFormatException);
      expect(() => parseDayRanges('09:00-09:00'), throwsFormatException);
    });

    test('rechaza intervalos desordenados o solapados', () {
      expect(
        () => parseDayRanges('15:00-19:00, 09:00-13:00'),
        throwsFormatException,
      );
      expect(
        () => parseDayRanges('09:00-13:00, 12:00-14:00'),
        throwsFormatException,
      );
    });

    test('formatDayRanges escribe lo que parseDayRanges lee', () {
      const ranges = [TimeRange(540, 780), TimeRange(900, 1140)];
      expect(formatDayRanges(ranges), '09:00-13:00, 15:00-19:00');
      expect(parseDayRanges(formatDayRanges(ranges)), ranges);
      expect(formatDayRanges(const []), '');
    });
  });

  group('ResourceInput', () {
    test('el nombre es obligatorio y tiene un máximo', () {
      expect(ResourceInput.name(''), 'Escribe un nombre.');
      expect(ResourceInput.name('   '), 'Escribe un nombre.');
      expect(ResourceInput.name('Cancha'), isNull);
      expect(ResourceInput.name('x' * 60), isNull);
      expect(ResourceInput.name('x' * 61), isNotNull);
    });

    test('la descripción es opcional y tiene un máximo', () {
      expect(ResourceInput.description(''), isNull);
      expect(ResourceInput.description('x' * 300), isNull);
      expect(ResourceInput.description('x' * 301), isNotNull);
    });

    test('el horario de un día muestra el mensaje del error', () {
      expect(ResourceInput.dayRanges('09:00-13:00'), isNull);
      expect(ResourceInput.dayRanges(''), isNull);
      expect(
        ResourceInput.dayRanges('09:00-13:00, 12:00-14:00'),
        'Los intervalos deben ir en orden y sin solaparse.',
      );
    });
  });
}
