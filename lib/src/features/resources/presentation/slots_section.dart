import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/schedule_labels.dart';
import '../../bookings/application/booking_providers.dart';
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
    final l10n = context.l10n;
    final labels = ScheduleLabels(l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.slotsTitle, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, value) in days.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(labels.dayLabel(value, today)),
                    selected: index == _selected,
                    onSelected: (_) => setState(() => _selected = index),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (slots.isEmpty)
          Text(l10n.slotsClosedDay)
        else
          taken.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.slotsLoading,
              ),
            ),
            error: (_, __) => Text(l10n.slotsError),
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
                              labels.dayLabel(day, today),
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
    final l10n = context.l10n;
    final time = _timeOf(slot);
    final when = l10n.dateAndTime(dayLabel, time);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bookDialogTitle),
        content: Text('${widget.resource.name}\n$when'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.back),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.bookButton),
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
      AsyncError(:final error) => l10n.bookingError(error),
      _ => l10n.bookedMessage(when),
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
    final l10n = context.l10n;
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
      label: l10n.slotSemantics(time, l10n.slotStatusLabel(view.status)),
      button: onBook != null,
      onTap: onBook,
      excludeSemantics: true,
      child: onBook != null
          ? ActionChip(
              avatar: avatar,
              label: Text(time),
              backgroundColor: background,
              labelStyle: labelStyle,
              tooltip: l10n.bookAtTooltip(time),
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
