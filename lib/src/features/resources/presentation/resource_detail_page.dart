import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/resource_providers.dart';
import '../domain/resource.dart';
import '../domain/schedule_format.dart';

/// Detalle de un recurso: descripción, duración del turno y horario semanal (RF-02).
class ResourceDetailPage extends ConsumerWidget {
  const ResourceDetailPage({required this.resourceId, super.key});

  final String resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resource = ref.watch(resourceProvider(resourceId));

    return Scaffold(
      appBar: AppBar(title: Text(resource.value?.name ?? 'Recurso')),
      body: resource.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
        ),
        error: (_, __) =>
            const Center(child: Text('No se pudo cargar este lugar.')),
        data: (value) => value == null || !value.active
            ? const Center(child: Text('Este lugar ya no está disponible.'))
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
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(resource.description, style: textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text(
          ScheduleFormat.slotDuration(resource.slotMinutes),
          style: textTheme.labelLarge,
        ),
        const SizedBox(height: 24),
        Text('Horario', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final MapEntry(key: weekday, value: name)
            in ScheduleFormat.weekdayNames.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 110, child: Text(name)),
                Expanded(
                  child: Text(
                    ScheduleFormat.ranges(resource.weeklySchedule[weekday]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
