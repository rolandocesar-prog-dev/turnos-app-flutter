import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/features/resources/data/resource_mapper.dart';
import 'package:turnos_app/src/features/resources/domain/resource.dart';

void main() {
  Map<String, dynamic> valid() => {
        'name': 'Consultorio dental',
        'description': 'Consulta general.',
        'slotMinutes': 30,
        'active': true,
        'weeklySchedule': {
          'mon': [
            {'start': '09:00', 'end': '13:00'},
            {'start': '15:00', 'end': '19:00'},
          ],
          'sat': [
            {'start': '09:00', 'end': '12:00'},
          ],
        },
        'blockedDates': ['2026-12-25'],
      };

  test('lee un recurso completo', () {
    final resource = resourceFromFirestore('consultorio', valid());

    expect(resource.id, 'consultorio');
    expect(resource.slotMinutes, 30);
    expect(resource.active, isTrue);
    expect(resource.weeklySchedule[DateTime.monday], const [
      TimeRange(540, 780),
      TimeRange(900, 1140),
    ]);
    expect(
      resource.weeklySchedule[DateTime.saturday],
      const [TimeRange(540, 720)],
    );
    expect(resource.weeklySchedule[DateTime.sunday], isNull);
    expect(resource.blockedDates, {'2026-12-25'});
    expect(resource.photoUrl, isNull);
  });

  test('sin blockedDates ni descripción usa valores vacíos', () {
    final data = valid()
      ..remove('blockedDates')
      ..remove('description');

    final resource = resourceFromFirestore('x', data);

    expect(resource.blockedDates, isEmpty);
    expect(resource.description, isEmpty);
  });

  group('un documento mal formado falla con un mensaje claro', () {
    final cases = <String, void Function(Map<String, dynamic>)>{
      'sin nombre': (d) => d.remove('name'),
      'duración que no es número': (d) => d['slotMinutes'] = '30',
      'duración cero': (d) => d['slotMinutes'] = 0,
      'día desconocido': (d) => d['weeklySchedule'] = {
            'lunes': <dynamic>[],
          },
      'hora inválida': (d) => d['weeklySchedule'] = {
            'mon': [
              {'start': '9:00', 'end': '13:00'},
            ],
          },
      'intervalo invertido': (d) => d['weeklySchedule'] = {
            'mon': [
              {'start': '13:00', 'end': '09:00'},
            ],
          },
      'intervalo sin fin': (d) => d['weeklySchedule'] = {
            'mon': [
              {'start': '09:00'},
            ],
          },
    };

    for (final MapEntry(key: name, value: breakIt) in cases.entries) {
      test(name, () {
        final data = valid();
        breakIt(data);
        expect(
          () => resourceFromFirestore('roto', data),
          throwsA(isA<FormatException>()),
        );
      });
    }
  });
}
