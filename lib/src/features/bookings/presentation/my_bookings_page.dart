import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../resources/application/resource_providers.dart';
import '../../resources/domain/schedule_format.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: bookings.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Cargando tus reservas',
          ),
        ),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No se pudieron cargar tus reservas. Revisa tu conexión.',
              textAlign: TextAlign.center,
            ),
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Próximas', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (upcoming.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No tienes reservas próximas.'),
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
          Text('Anteriores', style: textTheme.titleMedium),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar esta reserva?'),
        content: Text('${booking.resourceName}\n${_when(booking, now)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(bookingControllerProvider.notifier).cancel(booking);
    if (!context.mounted) return;
    final message = switch (ref.read(bookingControllerProvider)) {
      AsyncError(error: final BookingFailure failure) => failure.message,
      AsyncError() => BookingFailureReason.unknown.message,
      _ => 'Reserva cancelada. El horario quedó libre.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// «mié 11 nov, 09:00–10:00».
String _when(Booking booking, DateTime now) =>
    '${ScheduleFormat.dateLabel(booking.startAt, now)}, '
    '${ScheduleFormat.clock(booking.startAt)}–${ScheduleFormat.clock(booking.endAt)}';

class _BookingCard extends StatelessWidget {
  const _BookingCard(this.booking, {required this.now, this.onCancel});

  final Booking booking;
  final DateTime now;

  /// Si no es `null`, la reserva se puede cancelar.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final upcoming = booking.isUpcoming(now);
    final note = switch (booking.status) {
      BookingStatus.cancelled => booking.cancellationLabel,
      BookingStatus.active when !upcoming => 'Ya pasó',
      BookingStatus.active when !canCancel(booking, now) =>
        BookingFailureReason.tooLateToCancel.message,
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
          [_when(booking, now), if (note != null) note].join('\n'),
        ),
        isThreeLine: note != null,
        trailing: onCancel == null
            ? null
            : TextButton(onPressed: onCancel, child: const Text('Cancelar')),
      ),
    );
  }
}
