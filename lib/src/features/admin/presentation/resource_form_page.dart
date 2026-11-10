import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/session_redirect.dart';
import '../../resources/application/resource_providers.dart';
import '../../resources/domain/resource.dart';
import '../../resources/domain/schedule_format.dart';
import '../../resources/domain/slot_calculator.dart';
import '../application/admin_providers.dart';
import '../domain/resource_input.dart';

/// Crear o editar un recurso (RF-06, design.md §11). Sin [resourceId], crea uno nuevo.
class ResourceFormPage extends ConsumerWidget {
  const ResourceFormPage({super.key, this.resourceId});

  final String? resourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = resourceId;
    return Scaffold(
      appBar: AppBar(
        title: Text(id == null ? 'Nuevo recurso' : 'Editar recurso'),
      ),
      body: id == null
          ? const _ResourceForm(initial: null)
          : ref.watch(resourceProvider(id)).when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Cargando recurso',
                  ),
                ),
                error: (_, __) => const _Message(
                  'No se pudo cargar el recurso. Revisa tu conexión.',
                ),
                data: (resource) => resource == null
                    ? const _Message('Ese recurso no existe.')
                    : _ResourceForm(initial: resource),
              ),
    );
  }
}

class _ResourceForm extends ConsumerStatefulWidget {
  const _ResourceForm({required this.initial});

  /// Recurso a editar; `null` para uno nuevo. Solo se lee al abrir el formulario: un cambio
  /// posterior en Firestore no pisa lo que se está escribiendo.
  final Resource? initial;

  @override
  ConsumerState<_ResourceForm> createState() => _ResourceFormState();
}

class _ResourceFormState extends ConsumerState<_ResourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final Map<int, TextEditingController> _schedule;
  late int _slotMinutes;
  late bool _active;
  late Set<String> _blockedDates;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name);
    _description = TextEditingController(text: initial?.description);
    _schedule = {
      for (final weekday in ScheduleFormat.weekdayNames.keys)
        weekday: TextEditingController(
          text: formatDayRanges(initial?.weeklySchedule[weekday] ?? const []),
        ),
    };
    _slotMinutes = initial?.slotMinutes ?? 60;
    _active = initial?.active ?? true;
    _blockedDates = {...?initial?.blockedDates};
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final controller in _schedule.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// La duración guardada aparece aunque no sea una de las opciones habituales.
  List<int> get _durations => {
        ...ResourceInput.slotMinutesOptions,
        _slotMinutes,
      }.toList()
        ..sort();

  Future<void> _addBlockedDate() async {
    final today = ref.read(clockProvider)();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2, today.month, today.day),
      helpText: 'Día sin atención',
    );
    if (picked != null) setState(() => _blockedDates.add(dateKey(picked)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final initial = widget.initial;
    final resource = Resource(
      id: initial?.id ?? '',
      name: _name.text.trim(),
      description: _description.text.trim(),
      photoUrl: initial?.photoUrl,
      slotMinutes: _slotMinutes,
      active: _active,
      weeklySchedule: {
        for (final MapEntry(key: weekday, value: controller)
            in _schedule.entries)
          if (parseDayRanges(controller.text) case final ranges
              when ranges.isNotEmpty)
            weekday: ranges,
      },
      blockedDates: _blockedDates,
    );

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final editor = ref.read(resourceEditorProvider);
      if (initial == null) {
        await editor.create(resource);
      } else {
        await editor.update(resource);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Recurso guardado: ${resource.name}.')),
      );
      if (mounted) context.go(AppRoutes.admin);
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el recurso. Revisa tu conexión e inténtalo de nuevo.',
          ),
        ),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final blocked = _blockedDates.toList()..sort();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
            maxLength: ResourceInput.maxNameLength,
            validator: ResourceInput.name,
          ),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Descripción'),
            maxLength: ResourceInput.maxDescriptionLength,
            maxLines: 3,
            validator: ResourceInput.description,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _slotMinutes,
            decoration: const InputDecoration(labelText: 'Duración del turno'),
            items: [
              for (final minutes in _durations)
                DropdownMenuItem(
                  value: minutes,
                  child: Text(ScheduleFormat.slotDuration(minutes)),
                ),
            ],
            onChanged: (value) => setState(() => _slotMinutes = value!),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo'),
            subtitle: Text(
              _active
                  ? 'Aparece en el catálogo.'
                  : 'No aparece en el catálogo; sus reservas se conservan.',
            ),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
          const SizedBox(height: 16),
          Text('Horario semanal', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Por ejemplo 09:00-13:00, 15:00-19:00. Vacío = cerrado.',
            style: textTheme.bodySmall,
          ),
          for (final MapEntry(key: weekday, value: controller)
              in _schedule.entries)
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: ScheduleFormat.weekdayNames[weekday],
                hintText: 'Cerrado',
              ),
              validator: ResourceInput.dayRanges,
            ),
          const SizedBox(height: 24),
          Text('Días bloqueados', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          if (blocked.isEmpty) const Text('Ninguno.'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in blocked)
                InputChip(
                  label: Text(ScheduleFormat.longDate(DateTime.parse(key))),
                  deleteButtonTooltipMessage:
                      'Quitar ${ScheduleFormat.longDate(DateTime.parse(key))}',
                  onDeleted: () => setState(() => _blockedDates.remove(key)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addBlockedDate,
              icon: const Icon(Icons.event_busy),
              label: const Text('Agregar día bloqueado'),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
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
