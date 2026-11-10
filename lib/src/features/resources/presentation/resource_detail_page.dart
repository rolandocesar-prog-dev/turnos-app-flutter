import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/schedule_labels.dart';
import '../application/resource_providers.dart';
import '../domain/resource.dart';
import 'slots_section.dart';

/// Detalle de un recurso: descripción, duración del turno y horario semanal (RF-02).
class ResourceDetailPage extends ConsumerWidget {
  const ResourceDetailPage({required this.resourceId, super.key});

  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final resource = ref.watch(resourceProvider(resourceId));

    return Scaffold(
      appBar: AppBar(
        title: Text(resource.value?.name ?? l10n.resourceFallbackTitle),
      ),
      body: resource.when(
        loading: () => Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.loading),
        ),
        error: (_, __) => Center(child: Text(l10n.resourceError)),
        data: (value) => value == null || !value.active
            ? Center(child: Text(l10n.resourceUnavailable))
            : _Detail(value),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.resource);

  final Resource resource;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = ScheduleLabels(l10n);
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(resource.description, style: textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text(
          labels.slotDuration(resource.slotMinutes),
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 24),
        SlotsSection(resource: resource),
        const SizedBox(height: 24),
        Text(l10n.scheduleTitle, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final weekday in ScheduleLabels.weekdays)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            // Con texto grande, el día y su horario pasan a ocupar dos líneas.
            child: Wrap(
              spacing: 12,
              children: [
                SizedBox(width: 110, child: Text(labels.weekdayName(weekday))),
                Text(labels.ranges(resource.weeklySchedule[weekday])),
              ],
            ),
          ),
      ],
    );
  }
}
