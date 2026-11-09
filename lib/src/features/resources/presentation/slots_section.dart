import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/resource_providers.dart';
import '../domain/resource.dart';
import '../domain/schedule_format.dart';
import '../domain/slot_calculator.dart';
import '../domain/slot_status.dart';

/// Franjas de un recurso por fecha, con su estado en tiempo real (RF-02, design.md §9).
class SlotsSection extends ConsumerStatefulWidget {
  const SlotsSection({required this.resource, super.key});

  final Resource resource;

  static const daysAhead = 7;

  @override
  ConsumerState<SlotsSection> createState() => _SlotsSectionState();
}

class _SlotsSectionState extends ConsumerState<SlotsSection> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 0; i < SlotsSection.daysAhead; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    final day = days[_selected];
    final slots = slotsFor(widget.resource, day);
    final taken = ref.watch(
      takenSlotsProvider(
        (resourceId: widget.resource.id, dateKey: dateKey(day)),
      ),
    );
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Turnos', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, value) in days.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(ScheduleFormat.dayLabel(value, today)),
                    selected: index == _selected,
                    onSelected: (_) => setState(() => _selected = index),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (slots.isEmpty)
          const Text('Cerrado este día.')
        else
          taken.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando los turnos',
              ),
            ),
            error: (_, __) =>
                const Text('No se pudo cargar la disponibilidad.'),
            data: (takenIds) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final view in slotStatuses(slots, takenIds, now))
                  _SlotChip(view),
              ],
            ),
          ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip(this.view);

  final SlotView view;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time =
        ScheduleFormat.time(view.slot.start.hour * 60 + view.slot.start.minute);
    final (icon, background, foreground) = switch (view.status) {
      SlotStatus.available => (
          Icons.event_available,
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
      SlotStatus.taken => (
          Icons.block,
          colors.errorContainer,
          colors.onErrorContainer,
        ),
      SlotStatus.past => (
          Icons.history,
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
        ),
    };

    return Semantics(
      // Nodo propio: un lector de pantalla anuncia cada franja por separado con su estado.
      container: true,
      label: '$time, ${view.status.label}',
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, size: 18, color: foreground),
        label: Text(time),
        backgroundColor: background,
        labelStyle: TextStyle(
          color: foreground,
          decoration: view.status == SlotStatus.taken
              ? TextDecoration.lineThrough
              : null,
        ),
      ),
    );
  }
}
