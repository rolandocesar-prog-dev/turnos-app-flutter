import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/core/l10n/l10n.dart';
import 'package:turnos_app/src/features/admin/domain/resource_input.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';

Matcher throwsIssue(DayRangesIssue issue) => throwsA(
      isA<DayRangesException>().having((e) => e.issue, 'issue', issue),
    );

void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));

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
          throwsIssue(DayRangesIssue.notARange),
          reason: text,
        );
      }
    });

    test('rechaza horas imposibles y un fin que no es posterior', () {
      expect(
        () => parseDayRanges('25:00-26:00'),
        throwsIssue(DayRangesIssue.invalidTime),
      );
      expect(
        () => parseDayRanges('09:60-10:00'),
        throwsIssue(DayRangesIssue.invalidTime),
      );
      expect(
        () => parseDayRanges('13:00-09:00'),
        throwsIssue(DayRangesIssue.endBeforeStart),
      );
      expect(
        () => parseDayRanges('09:00-09:00'),
        throwsIssue(DayRangesIssue.endBeforeStart),
      );
    });

    test('rechaza intervalos desordenados o solapados', () {
      expect(
        () => parseDayRanges('15:00-19:00, 09:00-13:00'),
        throwsIssue(DayRangesIssue.overlap),
      );
      expect(
        () => parseDayRanges('09:00-13:00, 12:00-14:00'),
        throwsIssue(DayRangesIssue.overlap),
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
      expect(ResourceInput.name(''), ResourceInputIssue.nameMissing);
      expect(ResourceInput.name('   '), ResourceInputIssue.nameMissing);
      expect(ResourceInput.name('Cancha'), isNull);
      expect(ResourceInput.name('x' * 60), isNull);
      expect(ResourceInput.name('x' * 61), ResourceInputIssue.nameTooLong);
    });

    test('la descripción es opcional y tiene un máximo', () {
      expect(ResourceInput.description(''), isNull);
      expect(ResourceInput.description('x' * 300), isNull);
      expect(
        ResourceInput.description('x' * 301),
        ResourceInputIssue.descriptionTooLong,
      );
    });

    test('los problemas se traducen para el formulario', () {
      expect(
        l10n.resourceInputIssue(ResourceInputIssue.nameMissing),
        'Escribe un nombre.',
      );
      expect(
        l10n.resourceInputIssue(ResourceInputIssue.nameTooLong),
        'Usa como máximo 60 caracteres.',
      );
      expect(l10n.resourceInputIssue(null), isNull);
      expect(
        l10n.dayRangesIssue(
            ResourceInput.dayRanges('09:00-13:00, 12:00-14:00'),),
        'Los intervalos deben ir en orden y sin solaparse.',
      );
      expect(
        l10n.dayRangesIssue(ResourceInput.dayRanges('de 9 a 13')),
        '«de 9 a 13» no es un intervalo; escribe por ejemplo 09:00-13:00.',
      );
      expect(l10n.dayRangesIssue(ResourceInput.dayRanges('')), isNull);
    });
  });
}
