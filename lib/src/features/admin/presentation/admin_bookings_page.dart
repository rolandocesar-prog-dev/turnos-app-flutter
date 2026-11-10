import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/schedule_labels.dart';
import '../../bookings/domain/booking.dart';
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
    final l10n = context.l10n;
    final label = ScheduleLabels(l10n).dateLabel(_day, now);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dayBookingsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.previousDay,
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
                  tooltip: l10n.nextDay,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _move(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: bookings.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  semanticsLabel: l10n.dayBookingsLoading,
                ),
              ),
              error: (_, __) => _Message(l10n.dayBookingsError),
              data: (items) => items.isEmpty
                  ? _Message(l10n.noDayBookings(label))
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
    final l10n = context.l10n;
    final client = switch (email) {
      AsyncData(value: final String value) => value,
      AsyncLoading() => l10n.clientLoading,
      _ => l10n.clientUnknown,
    };
    final status = switch (booking.status) {
      BookingStatus.cancelled => booking.cancelledBy == CancelledBy.client
          ? l10n.statusCancelledByClient
          : l10n.cancellation(booking),
      BookingStatus.active when !cancellable => l10n.statusStarted,
      BookingStatus.active => l10n.statusActive,
    };

    return Card(
      child: ListTile(
        leading: Icon(
          booking.status == BookingStatus.cancelled
              ? Icons.event_busy
              : Icons.event_available,
        ),
        title: Text(
          l10n.adminBookingTitle(
            ScheduleLabels(l10n).clockRange(booking.startAt, booking.endAt),
            booking.resourceName,
          ),
        ),
        subtitle: Text('$client\n$status'),
        isThreeLine: true,
        trailing: cancellable
            ? TextButton(
                onPressed: busy ? null : () => _cancel(context, ref),
                child: Text(l10n.cancel),
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
    final l10n = context.l10n;
    final message = switch (ref.read(adminBookingControllerProvider)) {
      AsyncError(:final error) => l10n.bookingError(error),
      _ => l10n.cancelledMessage,
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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.cancelDialogTitle),
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
              decoration: InputDecoration(
                labelText: l10n.reasonLabel,
                helperText: l10n.reasonHelp,
              ),
              validator: (value) =>
                  l10n.cancelReasonIssue(cancelReasonIssue(value)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.back),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_reason.text.trim());
            }
          },
          child: Text(l10n.cancelBookingButton),
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
