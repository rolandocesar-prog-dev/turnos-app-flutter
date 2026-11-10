import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bookings/domain/booking.dart';
import '../../bookings/domain/booking_failure.dart';
import '../../resources/application/resource_providers.dart';
import '../../resources/domain/schedule_format.dart';
import '../application/admin_providers.dart';

/// Reservas del día para el administrador, con cancelación con motivo (RF-06, design.md §11).
class AdminBookingsPage extends ConsumerStatefulWidget {
  const AdminBookingsPage({super.key});

  @override
  ConsumerState<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends ConsumerState<AdminBookingsPage> {
  /// Día elegido, a medianoche; empieza en hoy.
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _day = DateTime(now.year, now.month, now.day);
  }

  void _move(int days) => setState(
        () => _day = DateTime(_day.year, _day.month, _day.day + days),
      );

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final bookings = ref.watch(dayBookingsProvider(_day));
    final label = ScheduleFormat.dateLabel(_day, now);

    return Scaffold(
      appBar: AppBar(title: const Text('Reservas del día')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Día anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _move(-1),
                ),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Día siguiente',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _move(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: bookings.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Cargando reservas',
                ),
              ),
              error: (_, __) => const _Message(
                'No se pudieron cargar las reservas. Revisa tu conexión.',
              ),
              data: (items) => items.isEmpty
                  ? _Message('No hay reservas para $label.')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final booking in items)
                          _AdminBookingCard(booking, now: now),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminBookingCard extends ConsumerWidget {
  const _AdminBookingCard(this.booking, {required this.now});

  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(clientEmailProvider(booking.uid));
    final busy = ref.watch(adminBookingControllerProvider).isLoading;
    final cancellable = canAdminCancel(booking, now);
    final client = switch (email) {
      AsyncData(value: final String value) => value,
      AsyncLoading() => 'Cargando cliente…',
      _ => 'Cliente sin datos',
    };
    final status = switch (booking.status) {
      BookingStatus.cancelled => switch (booking.cancelReason) {
          final String reason => 'Cancelada por el negocio: $reason',
          null => 'Cancelada por el cliente',
        },
      BookingStatus.active when !cancellable => 'Ya empezó',
      BookingStatus.active => 'Activa',
    };

    return Card(
      child: ListTile(
        leading: Icon(
          booking.status == BookingStatus.cancelled
              ? Icons.event_busy
              : Icons.event_available,
        ),
        title: Text(
          '${ScheduleFormat.clock(booking.startAt)}–'
          '${ScheduleFormat.clock(booking.endAt)} · ${booking.resourceName}',
        ),
        subtitle: Text('$client\n$status'),
        isThreeLine: true,
        trailing: cancellable
            ? TextButton(
                onPressed: busy ? null : () => _cancel(context, ref),
                child: const Text('Cancelar'),
              )
            : null,
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancelDialog(booking),
    );
    if (reason == null || !context.mounted) return;

    await ref
        .read(adminBookingControllerProvider.notifier)
        .cancel(booking, reason);
    if (!context.mounted) return;
    final message = switch (ref.read(adminBookingControllerProvider)) {
      AsyncError(error: final BookingFailure failure) => failure.message,
      AsyncError() => BookingFailureReason.unknown.message,
      _ => 'Reserva cancelada. El horario quedó libre.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Pide el motivo; devuelve el texto o `null` si se vuelve sin cancelar.
class _CancelDialog extends StatefulWidget {
  const _CancelDialog(this.booking);

  final Booking booking;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return AlertDialog(
      title: const Text('¿Cancelar esta reserva?'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${booking.resourceName}, ${ScheduleFormat.clock(booking.startAt)}',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              autofocus: true,
              maxLength: cancelReasonMaxLength,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                helperText: 'El cliente lo verá en «Mis reservas».',
              ),
              validator: cancelReasonError,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reason.text.trim());
            }
          },
          child: const Text('Cancelar reserva'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
