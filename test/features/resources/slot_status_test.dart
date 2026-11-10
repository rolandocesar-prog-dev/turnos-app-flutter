import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnos_app/src/core/l10n/l10n.dart';
import 'package:turnos_app/src/core/l10n/schedule_labels.dart';
import 'package:turnos_app/src/features/resources/domain/slot_calculator.dart';
import 'package:turnos_app/src/features/resources/domain/slot_status.dart';

Slot slotAt(int hour, [int minute = 0]) {
  final start = DateTime(2026, 11, 9, hour, minute);
  return Slot(
    id: slotId(start),
    start: start,
    end: start.add(const Duration(minutes: 30)),
  );
}

void main() {
  final now = DateTime(2026, 11, 9, 10, 10);
  final slots = [slotAt(9, 30), slotAt(10), slotAt(10, 30), slotAt(11)];

  test('pasada si ya empezó, ocupada si tiene documento, y si no disponible',
      () {
    final views = slotStatuses(slots, {'2026-11-09T11:00'}, now);

    expect(views.map((v) => v.status), [
      SlotStatus.past, // 09:30
      SlotStatus.past, // 10:00 ya empezó
      SlotStatus.available, // 10:30
      SlotStatus.taken, // 11:00
    ]);
  });

  test('una franja que empieza justo ahora ya no está disponible', () {
    final views =
        slotStatuses([slotAt(10, 30)], {}, DateTime(2026, 11, 9, 10, 30));
    expect(views.single.status, SlotStatus.past);
  });

  test('«pasada» gana sobre «ocupada»', () {
    final views = slotStatuses([slotAt(9, 30)], {'2026-11-09T09:30'}, now);
    expect(views.single.status, SlotStatus.past);
  });

  test('etiquetas de los días del selector', () {
    final labels = ScheduleLabels(lookupAppLocalizations(const Locale('es')));
    final today = DateTime(2026, 11, 9, 22);
    expect(labels.dayLabel(DateTime(2026, 11, 9), today), 'Hoy');
    expect(labels.dayLabel(DateTime(2026, 11, 10), today), 'Mañana');
    expect(labels.dayLabel(DateTime(2026, 11, 11), today), 'mié 11');
    expect(labels.dayLabel(DateTime(2026, 11, 15), today), 'dom 15');
  });
}
