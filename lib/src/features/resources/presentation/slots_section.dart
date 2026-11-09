import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/application/booking_providers.dart';
import '../../bookings/domain/booking_failure.dart';
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
    final busy = ref.watch(bookingControllerProvider).isLoading;
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
                  _SlotChip(
                    view,
                    onBook: view.status == SlotStatus.available && !busy
                        ? () => _book(
                              view.slot,
                              ScheduleFormat.dayLabel(day, today),
                            )
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Pide confirmación, reserva y avisa el resultado (RF-03, design.md §10).
  Future<void> _book(Slot slot, String dayLabel) async {
    final time = _timeOf(slot);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Reservar este turno?'),
        content: Text('${widget.resource.name}\n$dayLabel, $time'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reservar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref
        .read(bookingControllerProvider.notifier)
        .book(widget.resource, slot);
    if (!mounted) return;
    final message = switch (ref.read(bookingControllerProvider)) {
      AsyncError(error: final BookingFailure failure) => failure.message,
      AsyncError() => BookingFailureReason.unknown.message,
      _ => 'Turno reservado: $dayLabel, $time.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _timeOf(Slot slot) =>
    ScheduleFormat.time(slot.start.hour * 60 + slot.start.minute);

class _SlotChip extends StatelessWidget {
  const _SlotChip(this.view, {this.onBook});

  final SlotView view;

  /// Si no es `null`, la franja se puede reservar.
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = _timeOf(view.slot);
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

    final avatar = Icon(icon, size: 18, color: foreground);
    final labelStyle = TextStyle(
      color: foreground,
      decoration:
          view.status == SlotStatus.taken ? TextDecoration.lineThrough : null,
    );

    return Semantics(
      // Nodo propio: un lector de pantalla anuncia cada franja por separado con su estado y, si
      // se puede reservar, como botón.
      container: true,
      label: '$time, ${view.status.label}',
      button: onBook != null,
      onTap: onBook,
      excludeSemantics: true,
      child: onBook != null
          ? ActionChip(
              avatar: avatar,
              label: Text(time),
              backgroundColor: background,
              labelStyle: labelStyle,
              tooltip: 'Reservar a las $time',
              onPressed: onBook,
            )
          : Chip(
              avatar: avatar,
              label: Text(time),
              backgroundColor: background,
              labelStyle: labelStyle,
            ),
    );
  }
}
