import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/schedule_labels.dart';
import '../../notifications/presentation/push_card.dart';
import '../../resources/application/resource_providers.dart';
import '../application/booking_providers.dart';
import '../domain/booking.dart';
import '../domain/booking_failure.dart';

/// Mis reservas: las próximas, con su botón de cancelar, y las anteriores (RF-04, design.md §10).
class MyBookingsPage extends ConsumerWidget {
  const MyBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    final now = ref.watch(clockProvider)();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myBookingsTitle)),
      body: bookings.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            semanticsLabel: l10n.myBookingsLoading,
          ),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.myBookingsError, textAlign: TextAlign.center),
          ),
        ),
        data: (items) => _BookingList(items, now),
      ),
    );
  }
}

class _BookingList extends ConsumerWidget {
  const _BookingList(this.bookings, this.now);

  final List<Booking> bookings;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = [
      for (final b in bookings)
        if (b.isUpcoming(now)) b,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final history = [
      for (final b in bookings)
        if (!b.isUpcoming(now)) b,
    ]..sort((a, b) => b.startAt.compareTo(a.startAt));
    final busy = ref.watch(bookingControllerProvider).isLoading;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PushCard(),
        const SizedBox(height: 8),
        Text(l10n.upcomingTitle, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.noUpcoming),
          ),
        for (final booking in upcoming)
          _BookingCard(
            booking,
            now: now,
            onCancel: canCancel(booking, now) && !busy
                ? () => _cancel(context, ref, booking)
                : null,
          ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(l10n.historyTitle, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final booking in history) _BookingCard(booking, now: now),
        ],
      ],
    );
  }

  /// Pide confirmación, cancela y avisa el resultado (RF-04).
  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Booking booking,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelDialogTitle),
        content:
            Text('${booking.resourceName}\n${_when(context, booking, now)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.back),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.cancelBookingButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(bookingControllerProvider.notifier).cancel(booking);
    if (!context.mounted) return;
    final message = switch (ref.read(bookingControllerProvider)) {
      AsyncError(:final error) => l10n.bookingError(error),
      _ => l10n.cancelledMessage,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// «mié 11 nov, 09:00–10:00».
String _when(BuildContext context, Booking booking, DateTime now) =>
    ScheduleLabels.of(context)
        .dateAndRange(booking.startAt, booking.endAt, now);

class _BookingCard extends StatelessWidget {
  const _BookingCard(this.booking, {required this.now, this.onCancel});

  final Booking booking;
  final DateTime now;

  /// Si no es `null`, la reserva se puede cancelar.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final upcoming = booking.isUpcoming(now);
    final note = switch (booking.status) {
      BookingStatus.cancelled => l10n.cancellation(booking),
      BookingStatus.active when !upcoming => l10n.statusPast,
      BookingStatus.active when !canCancel(booking, now) =>
        l10n.bookingFailure(BookingFailureReason.tooLateToCancel),
      BookingStatus.active => null,
    };

    return Card(
      child: ListTile(
        leading: Icon(
          switch (booking.status) {
            BookingStatus.cancelled => Icons.event_busy,
            BookingStatus.active when upcoming => Icons.event_available,
            BookingStatus.active => Icons.history,
          },
        ),
        title: Text(booking.resourceName),
        subtitle: Text(
          [_when(context, booking, now), if (note != null) note].join('\n'),
        ),
        isThreeLine: note != null,
        trailing: onCancel == null
            ? null
            : TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
      ),
    );
  }
}
